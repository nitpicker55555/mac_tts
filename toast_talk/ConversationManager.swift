//
//  ConversationManager.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI
import Speech
import AVFoundation

@MainActor
class ConversationManager: ObservableObject {
    @Published var transcribedText = ""
    @Published var conversationHistory = ""
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage = ""
    @Published var audioLevel: Float = 0.0
    @Published var isAutoMode = true  // 自动模式开关
    @Published var enableVoicePlayback = false  // 语音播放开关
    
    private let speechManager = AutoSpeechManager()
    private let llmService = LLMService()
    private let synthesizer = AVSpeechSynthesizer()
    private let codeExecutor = UniversalCodeExecutor()
    
    init() {
        print("ConversationManager初始化完成，CodeExecutor已创建")
        
        // 测试日志功能
        print("尝试写入日志...")
        LogManager.shared.logSystem("ConversationManager 初始化完成")
        LogManager.shared.log("测试日志条目 - 时间: \(Date())", category: .system)
        
        if let logPath = LogManager.shared.getCurrentLogPath() {
            print("当前日志路径: \(logPath)")
        } else {
            print("警告: 无法获取日志路径")
        }
        
        // 监听语音完成事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(speechCompleted(_:)),
            name: Notification.Name("SpeechCompleted"),
            object: nil
        )
        
        // 观察音频级别
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.audioLevel = self.speechManager.audioLevel
                if self.speechManager.text != self.transcribedText {
                    self.transcribedText = self.speechManager.text
                }
            }
        }
    }
    
    @objc private func speechCompleted(_ notification: Notification) {
        Task { @MainActor in
            if let text = notification.userInfo?["text"] as? String {
                await processWithLLM()
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
        speechManager.startListening()
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.isRecording = self.speechManager.isRecording
        }
    }
    
    private func stopRecording() {
        speechManager.stopRecording()
        isRecording = false
    }
    
    private func processWithLLM() async {
        isProcessing = true
        
        // 添加用户输入到对话历史
        conversationHistory += "你: \(transcribedText)\n"
        
        // 记录到日志
        LogManager.shared.logConversation(user: transcribedText)
        
        // 发送到LLM
        if let response = await llmService.sendMessage(transcribedText) {
            // 添加AI响应到对话历史
            conversationHistory += "AI: \(response)\n\n"
            
            // 记录到日志
            LogManager.shared.logConversation(assistant: response)
            
            // 执行代码块
            print("准备执行代码块，LLM响应: \(response.prefix(100))...")
            let executionResults = await codeExecutor.processLLMResponse(response)
            print("代码执行结果数量: \(executionResults.count)")
            
            // 如果有执行结果，将结果反馈给LLM
            if !executionResults.isEmpty {
                var feedbackMessage = "以下是代码执行结果:\n\n"
                for result in executionResults {
                    feedbackMessage += result.formattedResult + "\n\n"
                }
                
                // 发送执行结果给LLM进行下一轮对话
                if let followUpResponse = await llmService.sendMessage(feedbackMessage) {
                    conversationHistory += "执行结果:\n" + feedbackMessage + "\n"
                    conversationHistory += "AI: \(followUpResponse)\n\n"
                    
                    // 记录执行结果反馈
                    LogManager.shared.log("代码执行结果反馈", category: .codeExecution)
                    LogManager.shared.logConversation(assistant: followUpResponse)
                    
                    // 递归处理可能的新代码块
                    let newResults = await codeExecutor.processLLMResponse(followUpResponse)
                    if !newResults.isEmpty {
                        await processExecutionResults(newResults)
                    }
                    
                    if enableVoicePlayback {
                        speakResponse(followUpResponse)
                    }
                } else {
                    conversationHistory += "执行结果:\n" + feedbackMessage + "\n\n"
                }
            } else {
                // 语音播放响应
                if enableVoicePlayback {
                    speakResponse(response)
                }
            }
        } else if !llmService.errorMessage.isEmpty {
            errorMessage = llmService.errorMessage
        }
        
        isProcessing = false
    }
    
    private func speakResponse(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
    
    func clearConversation() {
        conversationHistory = ""
        transcribedText = ""
        llmService.clearHistory()
        speechManager.text = ""
        codeExecutor.executionHistory.removeAll()
    }
    
    private func processExecutionResults(_ results: [ExecutionResult]) async {
        var feedbackMessage = "以下是代码执行结果:\n\n"
        for result in results {
            feedbackMessage += result.formattedResult + "\n\n"
        }
        
        // 记录执行结果
        LogManager.shared.log("代码执行结果反馈", category: .codeExecution)
        
        if let response = await llmService.sendMessage(feedbackMessage) {
            conversationHistory += "执行结果:\n" + feedbackMessage + "\n"
            conversationHistory += "AI: \(response)\n\n"
            
            // 记录AI响应
            LogManager.shared.logConversation(assistant: response)
            
            // 检查新响应中是否有可执行代码
            let newResults = await codeExecutor.processLLMResponse(response)
            if !newResults.isEmpty {
                print("发现新的可执行代码，继续处理...")
                await processExecutionResults(newResults)
            }
            
            if enableVoicePlayback {
                speakResponse(response)
            }
        }
    }
    
    func toggleAutoExecution() {
        codeExecutor.requireConfirmation.toggle()
    }
    
    var isAutoExecutionEnabled: Bool {
        !codeExecutor.requireConfirmation
    }
}