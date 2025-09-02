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
    
    private let speechManager = AutoSpeechManager()
    private let llmService = LLMService()
    private let synthesizer = AVSpeechSynthesizer()
    
    init() {
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
        
        // 发送到LLM
        if let response = await llmService.sendMessage(transcribedText) {
            // 添加AI响应到对话历史
            conversationHistory += "AI: \(response)\n\n"
            
            // 语音播放响应（可选）
            speakResponse(response)
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
    }
}