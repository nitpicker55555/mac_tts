//
//  StreamConversationManager.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI
import Speech

@MainActor
class StreamConversationManager: ObservableObject {
    @Published var transcribedText = ""
    @Published var conversationHistory = ""
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage = ""
    @Published var audioLevel: Float = 0.0
    @Published var currentAIResponse = ""
    @Published var isSpeaking = false  // 添加独立的语音播放状态
    
    private let speechManager = AutoSpeechManager()
    private let llmService = StreamLLMService()
    let voiceManager = VoiceManager()  // 改为let以便外部访问
    
    init() {
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
            // 语音识别完成时，确保更新录音状态
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
        // 重置状态
        transcribedText = ""
        currentAIResponse = ""
        errorMessage = ""
        
        // 开始录音
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
        print("开始处理LLM请求")
        isProcessing = true
        
        // 添加用户输入到对话历史
        conversationHistory += "你: \(transcribedText)\n"
        
        // 清空当前AI响应
        currentAIResponse = ""
        conversationHistory += "AI: "
        
        // 流式处理AI响应
        await llmService.sendMessageStream(transcribedText) { [weak self] chunk in
            guard let self = self else { return }
            
            // 追加到当前响应
            self.currentAIResponse += chunk
            self.conversationHistory += chunk
        }
        
        // 完成后添加换行
        conversationHistory += "\n\n"
        
        // AI文本响应完成，立即更新处理状态
        print("LLM响应完成，更新isProcessing = false")
        isProcessing = false
        
        // 语音播放完整响应（在后台进行，不影响按钮状态）
        if !currentAIResponse.isEmpty {
            print("开始播放语音")
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