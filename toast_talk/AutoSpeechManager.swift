//
//  AutoSpeechManager.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI
import Speech
import AVFoundation

@MainActor
class AutoSpeechManager: ObservableObject {
    @Published var text = ""
    @Published var isRecording = false
    @Published var isListening = false
    @Published var errorMessage = ""
    
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Config.speechRecognitionLocale))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // 静音检测相关
    private var silenceTimer: Timer?
    private var lastSpeechTime = Date()
    private let silenceThreshold: TimeInterval = Config.silenceThreshold // 静音阈值从配置读取
    private var hasStartedSpeaking = false
    
    // 音频级别检测
    private var audioLevelTimer: Timer?
    @Published var audioLevel: Float = 0.0
    
    func startListening() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard authStatus == .authorized else {
                DispatchQueue.main.async {
                    self?.errorMessage = "需要语音识别权限"
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.startRecording()
            }
        }
    }
    
    private func startRecording() {
        if audioEngine.isRunning {
            stopRecording()
            return
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "语音识别不可用"
            return
        }
        
        do {
            // 重置状态
            text = ""
            hasStartedSpeaking = false
            
            // 创建请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // 启动任务
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    let newText = result.bestTranscription.formattedString
                    
                    DispatchQueue.main.async {
                        // 检测是否有新的语音输入
                        if newText != self.text && !newText.isEmpty {
                            self.text = newText
                            self.lastSpeechTime = Date()
                            self.hasStartedSpeaking = true
                            self.resetSilenceTimer()
                            
                            // 发送实时转写更新
                            NotificationCenter.default.post(
                                name: Notification.Name("SpeechUpdate"),
                                object: nil,
                                userInfo: ["text": newText, "isFinal": result.isFinal]
                            )
                        }
                    }
                }
                
                if error != nil {
                    DispatchQueue.main.async {
                        self.stopRecording()
                    }
                }
            }
            
            // 配置音频
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // 安装音频处理器
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
                
                // 计算音频级别
                self?.calculateAudioLevel(buffer: buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            isListening = true
            
            // 启动静音检测
            startSilenceDetection()
            
        } catch {
            errorMessage = "错误: \(error.localizedDescription)"
        }
    }
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        
        DispatchQueue.main.async {
            self.audioLevel = max(0, avgPower + 50) / 50 // 归一化到0-1
        }
    }
    
    private func startSilenceDetection() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 如果已经开始说话且静音超过阈值，则停止录音
            if self.hasStartedSpeaking {
                let silenceDuration = Date().timeIntervalSince(self.lastSpeechTime)
                if silenceDuration > self.silenceThreshold {
                    self.stopAndProcess()
                }
            }
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    private func stopAndProcess() {
        guard hasStartedSpeaking && !text.isEmpty else {
            stopRecording()
            return
        }
        
        isListening = false
        stopRecording()
        
        // 触发完成回调
        NotificationCenter.default.post(
            name: Notification.Name("SpeechCompleted"),
            object: nil,
            userInfo: ["text": text]
        )
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        silenceTimer?.invalidate()
        audioLevelTimer?.invalidate()
        
        isRecording = false
        isListening = false
        audioLevel = 0
    }
}