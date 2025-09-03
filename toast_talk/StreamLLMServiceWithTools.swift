//
//  StreamLLMServiceWithTools.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import Foundation

// 流式LLM服务（支持工具）
class StreamLLMServiceWithTools: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var currentResponse = ""
    @Published var toolResults: [[String: Any]] = []
    
    private let config: LLMConfig
    private var messages: [ChatMessage] = []
    private let toolManager = LLMToolManager.shared
    
    init(config: LLMConfig = .openAI) {
        self.config = config
        
        // Add system message with tool awareness
        let systemPrompt = SystemPrompt.shared + """
        
        
        你可以使用以下工具来帮助用户：
        
        1. search_transit_route: 搜索两点之间的公共交通路线
           - 输入：起点和终点的经纬度坐标
           - 输出：详细的路线信息和GeoJSON格式的地理数据
        
        当用户询问路线规划或交通出行相关问题时，请使用此工具获取实时数据。
        
        位置识别说明：
        - 当用户提到"当前位置"、"我的位置"、"现在的位置"时，使用特殊坐标 -999,-999 表示需要获取设备当前位置
        - 当用户提到"家"或"home"时，使用坐标 48.107662,11.5338275
        - 当用户提到"学校"、"大学"或"university"时，使用坐标 48.1493705,11.5690651
        - 如果用户直接提供了坐标，使用用户提供的坐标
        
        示例：
        - "从当前位置到学校" -> 起点使用(-999,-999)，终点使用(48.1493705,11.5690651)
        - "从家到慕尼黑中央车站" -> 起点使用(48.107662,11.5338275)，终点需要先查找慕尼黑中央车站的坐标
        """
        
        messages.append(ChatMessage(role: "system", content: systemPrompt))
    }
    
    // 发送消息并流式接收响应（支持工具）
    func sendMessageStreamWithTools(_ content: String, onChunk: @escaping (String) -> Void) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            currentResponse = ""
            toolResults = []
        }
        
        // 添加用户消息
        messages.append(ChatMessage(role: "user", content: content))
        
        // 构建请求，包含工具定义
        let tools = toolManager.getToolDescriptions()
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0.7,
            "max_tokens": 1000,
            "stream": true,
            "tools": tools,
            "tool_choice": "auto"
        ]
        
        guard let url = URL(string: config.endpoint),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            await MainActor.run {
                errorMessage = "无效的请求配置"
                isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = jsonData
        
        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            
            // 检查响应状态
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                await MainActor.run {
                    errorMessage = "请求失败: HTTP \(httpResponse.statusCode)"
                    isLoading = false
                }
                return
            }
            
            var fullResponse = ""
            var toolCalls: [ToolCall] = []
            var currentToolCall: (id: String, name: String, arguments: String)?
            
            // 处理流式响应
            for try await line in asyncBytes.lines {
                // SSE格式: data: {...}
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    
                    // 检查是否是结束标记
                    if jsonString == "[DONE]" {
                        break
                    }
                    
                    // 解析JSON
                    if let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first {
                        
                        // 处理文本内容
                        if let delta = firstChoice["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            fullResponse += content
                            await MainActor.run {
                                self.currentResponse = fullResponse
                                onChunk(content)
                            }
                        }
                        
                        // 处理工具调用
                        if let delta = firstChoice["delta"] as? [String: Any],
                           let toolCallsData = delta["tool_calls"] as? [[String: Any]] {
                            for toolCallData in toolCallsData {
                                if let index = toolCallData["index"] as? Int {
                                    if let id = toolCallData["id"] as? String {
                                        // 新的工具调用
                                        if let function = toolCallData["function"] as? [String: Any],
                                           let name = function["name"] as? String {
                                            currentToolCall = (id: id, name: name, arguments: "")
                                        }
                                    } else if let function = toolCallData["function"] as? [String: Any],
                                              let arguments = function["arguments"] as? String,
                                              currentToolCall != nil {
                                        // 累积参数
                                        currentToolCall?.arguments += arguments
                                    }
                                }
                            }
                        }
                        
                        // 检查是否完成了工具调用
                        if let finishReason = firstChoice["finish_reason"] as? String,
                           finishReason == "tool_calls",
                           let toolCall = currentToolCall {
                            let call = ToolCall(
                                id: toolCall.id,
                                type: "function",
                                function: FunctionCall(name: toolCall.name, arguments: toolCall.arguments)
                            )
                            toolCalls.append(call)
                        }
                    }
                }
            }
            
            // 执行工具调用
            if !toolCalls.isEmpty {
                await executeToolCalls(toolCalls, onChunk: onChunk)
            } else if !fullResponse.isEmpty {
                // 添加助手响应到历史
                messages.append(ChatMessage(role: "assistant", content: fullResponse))
            }
            
            await MainActor.run {
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "流式请求失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // 执行工具调用
    private func executeToolCalls(_ toolCalls: [ToolCall], onChunk: @escaping (String) -> Void) async {
        var toolMessages: [[String: Any]] = []
        
        // 首先添加助手的工具调用消息
        var assistantMessage: [String: Any] = ["role": "assistant", "content": ""]
        assistantMessage["tool_calls"] = toolCalls.map { call in
            return [
                "id": call.id,
                "type": call.type,
                "function": [
                    "name": call.function.name,
                    "arguments": call.function.arguments
                ]
            ]
        }
        messages.append(ChatMessage(role: "assistant", content: ""))
        
        // 执行每个工具调用
        for toolCall in toolCalls {
            do {
                onChunk("\n🔧 正在调用工具: \(toolCall.function.name)...\n")
                
                let toolResponse = try await toolManager.executeToolCall(toolCall)
                
                // 解析工具结果
                if let resultData = toolResponse.content.data(using: .utf8),
                   let result = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] {
                    await MainActor.run {
                        self.toolResults.append(result)
                    }
                }
                
                // 添加工具响应消息
                let toolMessage: [String: Any] = [
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "content": toolResponse.content
                ]
                toolMessages.append(toolMessage)
                
            } catch {
                let errorMessage = "工具执行失败: \(error.localizedDescription)"
                let toolMessage: [String: Any] = [
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "content": errorMessage
                ]
                toolMessages.append(toolMessage)
                onChunk("\n❌ \(errorMessage)\n")
            }
        }
        
        // 将工具结果发送回LLM
        if !toolMessages.isEmpty {
            await sendToolResultsToLLM(toolMessages: toolMessages, onChunk: onChunk)
        }
    }
    
    // 将工具结果发送回LLM
    private func sendToolResultsToLLM(toolMessages: [[String: Any]], onChunk: @escaping (String) -> Void) async {
        // 添加工具消息到历史
        for toolMessage in toolMessages {
            if let content = toolMessage["content"] as? String {
                messages.append(ChatMessage(role: "tool", content: content))
            }
        }
        
        // 重新发送请求，包含工具结果
        let tools = toolManager.getToolDescriptions()
        var allMessages: [[String: Any]] = []
        
        // 构建完整的消息历史
        for (index, message) in messages.enumerated() {
            if message.role == "assistant" && index < messages.count - toolMessages.count {
                // 这是包含工具调用的助手消息
                var msg: [String: Any] = ["role": "assistant", "content": message.content]
                if let toolCallsData = try? JSONSerialization.data(withJSONObject: toolMessages),
                   let toolCalls = try? JSONSerialization.jsonObject(with: toolCallsData) {
                    msg["tool_calls"] = toolCalls
                }
                allMessages.append(msg)
            } else {
                allMessages.append(["role": message.role, "content": message.content])
            }
        }
        
        // 添加工具消息
        allMessages.append(contentsOf: toolMessages)
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": allMessages,
            "temperature": 0.7,
            "max_tokens": 1000,
            "stream": true,
            "tools": tools
        ]
        
        guard let url = URL(string: config.endpoint),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = jsonData
        
        do {
            let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)
            
            var fullResponse = ""
            
            // 处理流式响应
            for try await line in asyncBytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    
                    if jsonString == "[DONE]" {
                        break
                    }
                    
                    if let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let delta = firstChoice["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        
                        fullResponse += content
                        await MainActor.run {
                            self.currentResponse += content
                            onChunk(content)
                        }
                    }
                }
            }
            
            // 添加最终响应到历史
            if !fullResponse.isEmpty {
                messages.append(ChatMessage(role: "assistant", content: fullResponse))
            }
            
        } catch {
            onChunk("\n❌ 处理工具结果时出错: \(error.localizedDescription)\n")
        }
    }
    
    // 清除对话历史
    func clearHistory() {
        messages.removeAll()
        currentResponse = ""
        toolResults = []
        
        // 重新添加系统消息
        let systemPrompt = SystemPrompt.shared + """
        
        
        你可以使用以下工具来帮助用户：
        
        1. search_transit_route: 搜索两点之间的公共交通路线
           - 输入：起点和终点的经纬度坐标
           - 输出：详细的路线信息和GeoJSON格式的地理数据
        
        当用户询问路线规划或交通出行相关问题时，请使用此工具获取实时数据。
        """
        
        messages.append(ChatMessage(role: "system", content: systemPrompt))
    }
}