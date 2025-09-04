//
//  ImprovedStreamLLMServiceWithTools.swift
//  toast_talk
//
//  改进的流式LLM服务，修复HTTP 400错误
//

import Foundation

// 改进的聊天消息结构
struct ImprovedChatMessage {
    let role: String
    let content: String
    let toolCalls: [[String: Any]]?
    let toolCallId: String?
    
    init(role: String, content: String, toolCalls: [[String: Any]]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
    
    // 转换为API格式
    func toAPIFormat() -> [String: Any] {
        var message: [String: Any] = [
            "role": role,
            "content": content
        ]
        
        if let toolCalls = toolCalls {
            message["tool_calls"] = toolCalls
        }
        
        if let toolCallId = toolCallId {
            message["tool_call_id"] = toolCallId
        }
        
        return message
    }
}

// 改进的流式LLM服务
class ImprovedStreamLLMServiceWithTools: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var currentResponse = ""
    @Published var toolResults: [[String: Any]] = []
    
    private let config: LLMConfig
    private var messages: [ImprovedChatMessage] = []
    private let toolManager = LLMToolManager.shared
    
    init(config: LLMConfig = .openAI) {
        self.config = config
        
        // 添加系统消息
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
        """
        
        messages.append(ImprovedChatMessage(role: "system", content: systemPrompt))
    }
    
    // 发送消息并流式接收响应
    func sendMessageStreamWithTools(_ content: String, onChunk: @escaping (String) -> Void, onToolCall: ((ToolCall) -> Void)? = nil, onToolExecution: ((String, String, Bool) -> Void)? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            currentResponse = ""
            toolResults = []
        }
        
        // 添加用户消息
        messages.append(ImprovedChatMessage(role: "user", content: content))
        
        do {
            // 获取流式响应
            let (toolCalls, responseText) = try await performStreamRequest(onChunk: onChunk, onToolCall: onToolCall)
            
            // 如果有工具调用，执行它们
            if !toolCalls.isEmpty {
                await executeToolCalls(toolCalls, onChunk: onChunk, onToolCall: onToolCall, onToolExecution: onToolExecution)
            } else if !responseText.isEmpty {
                // 只有文本响应，添加到历史
                messages.append(ImprovedChatMessage(role: "assistant", content: responseText))
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "请求失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // 执行流式请求
    private func performStreamRequest(onChunk: @escaping (String) -> Void, onToolCall: ((ToolCall) -> Void)?) async throws -> ([ToolCall], String) {
        let tools = toolManager.getToolDescriptions()
        
        // 构建消息数组
        let messagesArray = messages.map { $0.toAPIFormat() }
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messagesArray,
            "temperature": 0.7,
            "max_tokens": 1000,
            "stream": true,
            "tools": tools,
            "tool_choice": "auto"
        ]
        
        // 调试：打印请求体
        print("发送请求: \(requestBody)")
        
        guard let url = URL(string: config.endpoint) else {
            throw URLError(.badURL)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = jsonData
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        // 检查响应状态
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            // 尝试读取错误信息
            var errorBody = ""
            for try await line in asyncBytes.lines {
                errorBody += line
            }
            print("错误响应: \(errorBody)")
            throw URLError(.badServerResponse, userInfo: ["statusCode": httpResponse.statusCode, "body": errorBody])
        }
        
        var fullResponse = ""
        var toolCalls: [ToolCall] = []
        var currentToolCall: (id: String, name: String, arguments: String)?
        
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
                   let firstChoice = choices.first {
                    
                    // 处理文本内容
                    if let delta = firstChoice["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        fullResponse += content
                        await MainActor.run {
                            self.currentResponse = fullResponse
                        }
                        onChunk(content)
                    }
                    
                    // 处理工具调用
                    if let delta = firstChoice["delta"] as? [String: Any],
                       let toolCallsData = delta["tool_calls"] as? [[String: Any]] {
                        for toolCallData in toolCallsData {
                            if let id = toolCallData["id"] as? String,
                               let function = toolCallData["function"] as? [String: Any],
                               let name = function["name"] as? String {
                                // 新的工具调用
                                currentToolCall = (id: id, name: name, arguments: "")
                                // 立即通知工具调用开始
                                let tempCall = ToolCall(
                                    id: id,
                                    type: "function",
                                    function: FunctionCall(name: name, arguments: "")
                                )
                                onToolCall?(tempCall)
                            } else if let function = toolCallData["function"] as? [String: Any],
                                      let arguments = function["arguments"] as? String,
                                      currentToolCall != nil {
                                // 累积参数
                                currentToolCall?.arguments += arguments
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
                        onToolCall?(call)
                    }
                }
            }
        }
        
        return (toolCalls, fullResponse)
    }
    
    // 执行工具调用
    private func executeToolCalls(_ toolCalls: [ToolCall], onChunk: @escaping (String) -> Void, onToolCall: ((ToolCall) -> Void)?, onToolExecution: ((String, String, Bool) -> Void)?) async {
        // 先添加包含工具调用的助手消息
        let toolCallsArray = toolCalls.map { call in
            return [
                "id": call.id,
                "type": call.type,
                "function": [
                    "name": call.function.name,
                    "arguments": call.function.arguments
                ]
            ]
        }
        
        messages.append(ImprovedChatMessage(
            role: "assistant",
            content: "",
            toolCalls: toolCallsArray
        ))
        
        // 执行每个工具调用并收集结果
        for toolCall in toolCalls {
            do {
                // 通知工具开始执行
                onToolExecution?(toolCall.id, "执行中...", false)
                
                let toolResponse = try await toolManager.executeToolCall(toolCall)
                
                // 解析工具结果
                if let resultData = toolResponse.content.data(using: .utf8),
                   let result = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] {
                    await MainActor.run {
                        self.toolResults.append(result)
                    }
                }
                
                // 通知工具执行成功
                onToolExecution?(toolCall.id, toolResponse.content, true)
                
                // 添加工具响应消息
                messages.append(ImprovedChatMessage(
                    role: "tool",
                    content: toolResponse.content,
                    toolCallId: toolCall.id
                ))
                
            } catch {
                let errorMessage = "工具执行失败: \(error.localizedDescription)"
                
                // 通知工具执行失败
                onToolExecution?(toolCall.id, errorMessage, false)
                
                messages.append(ImprovedChatMessage(
                    role: "tool",
                    content: errorMessage,
                    toolCallId: toolCall.id
                ))
            }
        }
        
        // 获取LLM对工具结果的响应
        do {
            let (newToolCalls, responseText) = try await performStreamRequest(onChunk: onChunk, onToolCall: onToolCall)
            
            if !responseText.isEmpty {
                messages.append(ImprovedChatMessage(role: "assistant", content: responseText))
            }
            
            // 如果有新的工具调用，递归执行
            if !newToolCalls.isEmpty {
                await executeToolCalls(newToolCalls, onChunk: onChunk, onToolCall: onToolCall, onToolExecution: onToolExecution)
            }
            
        } catch {
            onChunk("\n❌ 处理工具结果时出错: \(error.localizedDescription)\n")
        }
    }
    
    // 清除对话历史
    func clearHistory() {
        // 保留系统消息
        let systemMessage = messages.first
        messages.removeAll()
        if let systemMessage = systemMessage {
            messages.append(systemMessage)
        }
        
        currentResponse = ""
        toolResults = []
        errorMessage = ""
    }
}