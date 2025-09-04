//
//  ImprovedStreamConversationManager.swift
//  toast_talk
//
//  改进的流式会话管理器，支持卡片式UI
//

import SwiftUI
import Speech

@MainActor
class ImprovedStreamConversationManager: ObservableObject {
    @Published var transcribedText = ""
    @Published var messages: [ConversationMessage] = []
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage = ""
    @Published var audioLevel: Float = 0.0
    @Published var isSpeaking = false
    @Published var enableVoicePlayback = false
    @Published var showMapView = false
    @Published var currentGeoJSON: GeoJSONFeatureCollection?
    @Published var currentRouteInfo: String = ""
    @Published var allJourneys: [[String: Any]] = []
    
    private let speechManager = AutoSpeechManager()
    private let llmService = ImprovedStreamLLMServiceWithTools()
    let voiceManager = VoiceManager()
    private let codeExecutor = UniversalCodeExecutor()
    
    private var currentStreamingMessageId: UUID?
    private var toolCallMessageIds: [String: UUID] = [:]  // 工具调用ID映射到消息ID
    
    init() {
        print("ImprovedStreamConversationManager初始化完成")
        
        LogManager.shared.logSystem("ImprovedStreamConversationManager 初始化完成")
        
        // 初始化位置服务
        if LocationService.shared.authorizationStatus == .notDetermined {
            LocationService.shared.requestLocationPermission()
        }
        
        // 监听语音更新事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(speechUpdate(_:)),
            name: Notification.Name("SpeechUpdate"),
            object: nil
        )
        
        // 监听语音完成事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(speechCompleted(_:)),
            name: Notification.Name("SpeechCompleted"),
            object: nil
        )
        
        // 观察音频级别和语音状态
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.audioLevel = self.speechManager.audioLevel
                self.isSpeaking = self.voiceManager.isSpeaking
            }
        }
    }
    
    @objc private func speechUpdate(_ notification: Notification) {
        Task { @MainActor in
            if let text = notification.userInfo?["text"] as? String {
                self.transcribedText = text
            }
        }
    }
    
    @objc private func speechCompleted(_ notification: Notification) {
        Task { @MainActor in
            self.isRecording = false
            
            if let text = notification.userInfo?["text"] as? String, !text.isEmpty {
                await processWithStreamLLM()
            }
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        transcribedText = ""
        errorMessage = ""
        
        speechManager.startListening()
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.isRecording = self.speechManager.isRecording
        }
    }
    
    private func stopRecording() {
        speechManager.stopRecording()
        isRecording = false
    }
    
    private func processWithStreamLLM() async {
        print("开始处理LLM请求（支持工具）")
        isProcessing = true
        
        // 添加用户消息
        let userMessage = ConversationMessage(
            type: .userText(transcribedText),
            timestamp: Date()
        )
        messages.append(userMessage)
        
        LogManager.shared.logConversation(user: transcribedText)
        
        // 创建助手消息占位符
        let assistantMessageId = UUID()
        currentStreamingMessageId = assistantMessageId
        
        let assistantMessage = ConversationMessage(
            id: assistantMessageId,
            type: .assistantText(""),
            timestamp: Date()
        )
        messages.append(assistantMessage)
        
        var accumulatedText = ""
        
        // 流式处理AI响应
        await llmService.sendMessageStreamWithTools(
            transcribedText,
            onChunk: { [weak self] chunk in
                guard let self = self else { return }
                
                print("收到chunk: \(chunk)")
                
                Task { @MainActor in
                    accumulatedText += chunk
                    print("累积文本: \(accumulatedText)")
                    
                    // 更新最后一条消息
                    if let index = self.messages.lastIndex(where: { $0.id == assistantMessageId }) {
                        self.messages[index] = ConversationMessage(
                            id: assistantMessageId,
                            type: .assistantText(accumulatedText),
                            timestamp: self.messages[index].timestamp
                        )
                        print("消息已更新，索引: \(index)")
                    } else {
                        print("未找到消息ID: \(assistantMessageId)")
                    }
                }
            },
            onToolCall: { [weak self] toolCall in
                guard let self = self else { return }
                
                Task { @MainActor in
                    // 检查是否已存在此工具调用
                    if self.toolCallMessageIds[toolCall.id] == nil {
                        // 添加工具调用卡片
                        let messageId = UUID()
                        let toolCallMessage = ConversationMessage(
                            id: messageId,
                            type: .toolCall(ToolCallCard(
                                toolName: self.getToolDisplayName(toolCall.function.name),
                                timestamp: Date(),
                                input: self.formatToolInput(toolCall.function.arguments),
                                output: "准备执行...",
                                status: .pending,
                                icon: self.getToolIcon(toolCall.function.name)
                            )),
                            timestamp: Date()
                        )
                        self.messages.append(toolCallMessage)
                        self.toolCallMessageIds[toolCall.id] = messageId
                        print("添加工具调用卡片: \(toolCall.function.name)")
                    }
                }
            },
            onToolExecution: { [weak self] toolCallId, result, success in
                guard let self = self else { return }
                
                Task { @MainActor in
                    // 更新工具调用卡片的状态
                    if let messageId = self.toolCallMessageIds[toolCallId],
                       let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                        
                        var updatedMessage = self.messages[index]
                        if case .toolCall(var toolCard) = updatedMessage.type {
                            // 更新工具卡片状态
                            toolCard = ToolCallCard(
                                toolName: toolCard.toolName,
                                timestamp: toolCard.timestamp,
                                input: toolCard.input,
                                output: success ? self.extractToolResultSummary(result) : result,
                                status: success ? .success : .error,
                                icon: toolCard.icon
                            )
                            
                            self.messages[index] = ConversationMessage(
                                id: messageId,
                                type: .toolCall(toolCard),
                                timestamp: updatedMessage.timestamp
                            )
                            
                            print("更新工具卡片状态: \(toolCard.toolName) - \(success ? "成功" : "失败")")
                            
                            // 如果是路线搜索工具且成功，立即处理结果
                            if success && toolCard.toolName.contains("交通路线") {
                                self.processRouteToolResult(result)
                            }
                        }
                    }
                }
            }
        )
        
        // 工具结果已在执行回调中处理，这里不需要再处理
        // if !llmService.toolResults.isEmpty {
        //     await handleToolResults()
        // }
        
        // 记录AI响应
        LogManager.shared.logConversation(assistant: accumulatedText)
        
        // 执行代码块
        let executionResults = await codeExecutor.processLLMResponse(accumulatedText)
        
        // 添加代码执行卡片
        for result in executionResults {
            let codeMessage = ConversationMessage(
                type: .codeExecution(
                    language: result.language.displayName,
                    code: result.code,
                    output: result.output,
                    status: result.exitCode == 0 ? .success : .error
                ),
                timestamp: Date()
            )
            messages.append(codeMessage)
        }
        
        // 如果有执行结果，进行反馈
        if !executionResults.isEmpty {
            await processExecutionResultsRecursively(executionResults)
        }
        
        isProcessing = false
        currentStreamingMessageId = nil
        
        // 语音播放
        if !accumulatedText.isEmpty && enableVoicePlayback {
            voiceManager.speak(accumulatedText)
        }
        
        // 处理错误
        if !llmService.errorMessage.isEmpty {
            errorMessage = llmService.errorMessage
            
            // 添加系统错误消息
            let errorMsg = ConversationMessage(
                type: .system("错误: \(llmService.errorMessage)"),
                timestamp: Date()
            )
            messages.append(errorMsg)
        }
    }
    
    // 此方法已弃用，工具结果在执行回调中处理
    // private func handleToolResults() async { }
    
    private func processExecutionResultsRecursively(_ results: [ExecutionResult]) async {
        var feedbackMessage = "以下是代码执行结果:\n\n"
        for result in results {
            feedbackMessage += result.formattedResult + "\n\n"
        }
        
        LogManager.shared.log("代码执行结果反馈", category: .codeExecution)
        
        // 添加系统消息显示执行结果
        let systemMessage = ConversationMessage(
            type: .system("代码执行完成"),
            timestamp: Date()
        )
        messages.append(systemMessage)
        
        // 创建新的助手消息
        let assistantMessageId = UUID()
        let assistantMessage = ConversationMessage(
            id: assistantMessageId,
            type: .assistantText(""),
            timestamp: Date()
        )
        messages.append(assistantMessage)
        
        var newAIResponse = ""
        
        await llmService.sendMessageStreamWithTools(
            feedbackMessage,
            onChunk: { [weak self] chunk in
                guard let self = self else { return }
                
                Task { @MainActor in
                    newAIResponse += chunk
                    
                    if let index = self.messages.lastIndex(where: { $0.id == assistantMessageId }) {
                        self.messages[index] = ConversationMessage(
                            id: assistantMessageId,
                            type: .assistantText(newAIResponse),
                            timestamp: self.messages[index].timestamp
                        )
                    }
                }
            }
        )
        
        if !newAIResponse.isEmpty {
            LogManager.shared.logConversation(assistant: newAIResponse)
        }
        
        let newExecutionResults = await codeExecutor.processLLMResponse(newAIResponse)
        
        if !newExecutionResults.isEmpty {
            print("发现新的可执行代码，继续处理...")
            
            // 添加新的代码执行卡片
            for result in newExecutionResults {
                let codeMessage = ConversationMessage(
                    type: .codeExecution(
                        language: result.language.displayName,
                        code: result.code,
                        output: result.output,
                        status: result.exitCode == 0 ? .success : .error
                    ),
                    timestamp: Date()
                )
                messages.append(codeMessage)
            }
            
            await processExecutionResultsRecursively(newExecutionResults)
        }
    }
    
    private func processRouteToolResult(_ result: String) {
        print("立即处理路线工具结果")
        
        // 尝试解析JSON结果
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["journeys"] != nil else {
            print("无法解析路线数据")
            return
        }
        
        // 使用完整的路线数据
        let fullJourneys = TransitRouteTool.lastFullJourneys
        print("获取完整路线数据，共 \(fullJourneys.count) 条路线")
        
        // 保存路线数据
        self.allJourneys = fullJourneys
        
        // 获取第一条路线的数据（用于基础地图视图）
        if let firstJourney = fullJourneys.first,
           let geoJSONDict = firstJourney["geojson"] as? [String: Any],
           let routeInfo = firstJourney["route_info"] as? String {
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: geoJSONDict)
                let geoJSON = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: jsonData)
                
                self.currentGeoJSON = geoJSON
                self.currentRouteInfo = routeInfo
                self.showMapView = true
                
                print("成功加载路线数据，准备显示地图")
            } catch {
                print("解析GeoJSON失败: \(error)")
            }
        }
    }
    
    private func extractToolResultSummary(_ result: String) -> String {
        // 尝试解析JSON结果并提取摘要
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // 对于路线搜索工具
            if let journeys = json["journeys"] as? [[String: Any]] {
                return "找到 \(journeys.count) 条路线"
            }
            
            // 对于其他工具，返回前200个字符
            if result.count > 200 {
                return String(result.prefix(200)) + "..."
            }
        }
        
        // 如果不是JSON或解析失败，返回前200个字符
        if result.count > 200 {
            return String(result.prefix(200)) + "..."
        }
        
        return result
    }
    
    func clearConversation() {
        messages.removeAll()
        transcribedText = ""
        toolCallMessageIds.removeAll()
        llmService.clearHistory()
        speechManager.text = ""
        voiceManager.stopSpeaking()
        showMapView = false
        currentGeoJSON = nil
        currentRouteInfo = ""
        allJourneys = []
    }
    
    // 辅助方法
    private func getToolDisplayName(_ toolName: String) -> String {
        switch toolName {
        case "search_transit_route":
            return "交通路线搜索"
        default:
            return toolName
        }
    }
    
    private func getToolIcon(_ toolName: String) -> String {
        switch toolName {
        case "search_transit_route":
            return "map.fill"
        default:
            return "wrench.and.screwdriver.fill"
        }
    }
    
    private func formatToolInput(_ arguments: String) -> String {
        // 尝试格式化JSON参数
        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var formatted = ""
            for (key, value) in json {
                formatted += "\(key): \(value)\n"
            }
            return formatted.trimmingCharacters(in: .newlines)
        }
        return arguments
    }
    
    // 语音控制
    func setVoice(_ voice: AVSpeechSynthesisVoice) {
        voiceManager.selectedVoice = voice
    }
    
    func setSpeechRate(_ rate: Float) {
        voiceManager.speechRate = rate
    }
    
    func stopSpeaking() {
        voiceManager.stopSpeaking()
    }
}