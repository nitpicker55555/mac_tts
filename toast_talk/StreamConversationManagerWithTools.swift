//
//  StreamConversationManagerWithTools.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import SwiftUI
import Speech

@MainActor
class StreamConversationManagerWithTools: ObservableObject {
    @Published var transcribedText = ""
    @Published var conversationHistory = ""
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage = ""
    @Published var audioLevel: Float = 0.0
    @Published var currentAIResponse = ""
    @Published var isSpeaking = false
    @Published var enableVoicePlayback = false
    @Published var showMapView = false
    @Published var currentGeoJSON: GeoJSONFeatureCollection?
    @Published var currentRouteInfo: String = ""
    @Published var allJourneys: [[String: Any]] = []
    
    private let speechManager = AutoSpeechManager()
    private let llmService = StreamLLMServiceWithTools()  // 使用支持工具的LLM服务
    let voiceManager = VoiceManager()
    private let codeExecutor = UniversalCodeExecutor()
    
    init() {
        print("StreamConversationManagerWithTools初始化完成")
        
        LogManager.shared.logSystem("StreamConversationManagerWithTools 初始化完成")
        
        // 初始化位置服务（提前请求权限）
        if LocationService.shared.authorizationStatus == .notDetermined {
            LocationService.shared.requestLocationPermission()
        }
        
        // 监听语音更新事件（流式）
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
        currentAIResponse = ""
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
        
        // 添加用户输入到对话历史
        conversationHistory += "你: \(transcribedText)\n"
        
        // 记录用户输入到日志
        LogManager.shared.logConversation(user: transcribedText)
        
        // 清空当前AI响应
        currentAIResponse = ""
        conversationHistory += "AI: "
        
        // 流式处理AI响应（支持工具）
        await llmService.sendMessageStreamWithTools(transcribedText) { [weak self] chunk in
            guard let self = self else { return }
            
            Task { @MainActor in
                // 追加到当前响应
                self.currentAIResponse += chunk
                self.conversationHistory += chunk
            }
        }
        
        // 处理工具结果
        if !llmService.toolResults.isEmpty {
            print("处理工具结果，共 \(llmService.toolResults.count) 个")
            LogManager.shared.log("处理工具结果，共 \(llmService.toolResults.count) 个", category: .tool)
            
            for toolResult in llmService.toolResults {
                if let journeys = toolResult["journeys"] as? [[String: Any]] {
                    print("找到路线数据，共 \(journeys.count) 条路线")
                    LogManager.shared.log("找到路线数据，共 \(journeys.count) 条路线", category: .tool)
                    
                    // 保存所有路线数据用于增强版地图
                    self.allJourneys = journeys
                    
                    // 获取第一条路线的数据（用于基础版地图）
                    if let firstJourney = journeys.first,
                       let geoJSONDict = firstJourney["geojson"] as? [String: Any],
                       let routeInfo = firstJourney["route_info"] as? String {
                        
                        // 转换GeoJSON
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: geoJSONDict)
                            let geoJSON = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: jsonData)
                            
                            // 更新UI
                            self.currentGeoJSON = geoJSON
                            self.currentRouteInfo = routeInfo
                            self.showMapView = true
                            
                            print("成功加载路线数据，准备显示地图")
                        } catch {
                            print("解析GeoJSON失败: \(error)")
                        }
                    }
                }
            }
        }
        
        // 完成后添加换行
        conversationHistory += "\n\n"
        
        // 记录AI响应到日志
        LogManager.shared.logConversation(assistant: currentAIResponse)
        
        // 执行代码块
        let executionResults = await codeExecutor.processLLMResponse(currentAIResponse)
        
        // 如果有执行结果，记录并反馈
        if !executionResults.isEmpty {
            await processExecutionResultsRecursively(executionResults)
        }
        
        // 更新处理状态
        isProcessing = false
        
        // 语音播放完整响应
        if !currentAIResponse.isEmpty && enableVoicePlayback {
            voiceManager.speak(currentAIResponse)
        }
        
        // 处理错误
        if !llmService.errorMessage.isEmpty {
            errorMessage = llmService.errorMessage
        }
    }
    
    func clearConversation() {
        conversationHistory = ""
        transcribedText = ""
        currentAIResponse = ""
        llmService.clearHistory()
        speechManager.text = ""
        voiceManager.stopSpeaking()
        showMapView = false
        currentGeoJSON = nil
        currentRouteInfo = ""
        allJourneys = []
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
    
    // 递归处理执行结果
    private func processExecutionResultsRecursively(_ results: [ExecutionResult]) async {
        var feedbackMessage = "以下是代码执行结果:\n\n"
        for result in results {
            feedbackMessage += result.formattedResult + "\n\n"
        }
        
        LogManager.shared.log("代码执行结果反馈", category: .codeExecution)
        
        conversationHistory += "执行结果:\n" + feedbackMessage + "\n"
        conversationHistory += "AI: "
        
        var newAIResponse = ""
        await llmService.sendMessageStreamWithTools(feedbackMessage) { [weak self] chunk in
            guard let self = self else { return }
            self.conversationHistory += chunk
            newAIResponse += chunk
        }
        
        conversationHistory += "\n\n"
        
        if !newAIResponse.isEmpty {
            LogManager.shared.logConversation(assistant: newAIResponse)
        }
        
        let newExecutionResults = await codeExecutor.processLLMResponse(newAIResponse)
        
        if !newExecutionResults.isEmpty {
            print("发现新的可执行代码，继续处理...")
            await processExecutionResultsRecursively(newExecutionResults)
        }
    }
}