//
//  LLMService.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import Foundation

// LLM服务配置
struct LLMConfig {
    let apiKey: String
    let endpoint: String
    let model: String
    
    // 示例配置 - OpenAI GPT-4o
    static let openAI = LLMConfig(
        apiKey: Config.openAIAPIKey,
        endpoint: "https://api.openai.com/v1/chat/completions",
        model: Config.openAIModel
    )
    
    // 示例配置 - 本地LLM（如Ollama）
    static let local = LLMConfig(
        apiKey: "",
        endpoint: "http://localhost:11434/api/chat",
        model: "llama2"
    )
}

// 消息结构
struct ChatMessage: Codable {
    let role: String
    let content: String
}

// LLM服务
class LLMService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let config: LLMConfig
    private var messages: [ChatMessage] = []
    
    init(config: LLMConfig = .openAI) {
        self.config = config
        print("LLM Service initialized with API Key: \(config.apiKey.prefix(10))...")
    }
    
    // 发送消息到LLM
    func sendMessage(_ content: String) async -> String? {
        isLoading = true
        errorMessage = ""
        
        // 添加用户消息
        messages.append(ChatMessage(role: "user", content: content))
        
        // 构建请求
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0.7,
            "max_tokens": 500,
            "stream": false
        ]
        
        guard let url = URL(string: config.endpoint),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            errorMessage = "无效的请求配置"
            isLoading = false
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP响应
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                    print("Error response: \(responseString)")
                }
            }
            
            // 解析响应
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // OpenAI格式
                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // 添加助手消息
                    messages.append(ChatMessage(role: "assistant", content: content))
                    isLoading = false
                    return content
                }
                
                // Ollama格式
                if let message = json["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    messages.append(ChatMessage(role: "assistant", content: content))
                    isLoading = false
                    return content
                }
            }
            
            errorMessage = "无法解析响应"
            isLoading = false
            return nil
            
        } catch {
            errorMessage = "请求失败: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
    
    // 清除对话历史
    func clearHistory() {
        messages.removeAll()
    }
}
