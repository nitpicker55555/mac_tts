//
//  StreamLLMService.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import Foundation

// 流式LLM服务
class StreamLLMService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var currentResponse = ""
    
    private let config: LLMConfig
    private var messages: [ChatMessage] = []
    
    init(config: LLMConfig = .openAI) {
        self.config = config
    }
    
    // 发送消息并流式接收响应
    func sendMessageStream(_ content: String, onChunk: @escaping (String) -> Void) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            currentResponse = ""
        }
        
        // 添加用户消息
        messages.append(ChatMessage(role: "user", content: content))
        
        // 构建请求
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0.7,
            "max_tokens": 500,
            "stream": true  // 启用流式响应
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
                       let firstChoice = choices.first,
                       let delta = firstChoice["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        
                        fullResponse += content
                        
                        await MainActor.run {
                            self.currentResponse = fullResponse
                            onChunk(content)
                        }
                    }
                }
            }
            
            // 添加完整的助手响应到历史
            if !fullResponse.isEmpty {
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
    
    // 清除对话历史
    func clearHistory() {
        messages.removeAll()
        currentResponse = ""
    }
}