//
//  SpeechRecognitionManager.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionManager: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String = ""
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    init() {
        requestPermissions()
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            Task { @MainActor in
                switch authStatus {
                case .authorized:
                    self.setupRecognizer()
                case .denied:
                    self.errorMessage = "请在系统设置中授权语音识别权限"
                case .restricted:
                    self.errorMessage = "语音识别在此设备上不可用"
                case .notDetermined:
                    self.errorMessage = "语音识别权限未确定"
                @unknown default:
                    self.errorMessage = "未知错误"
                }
            }
        }
    }
    
    private func setupRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        audioEngine = AVAudioEngine()
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // 确保有权限和设备
        guard let recognizer = speechRecognizer,
              recognizer.isAvailable,
              let audioEngine = audioEngine else {
            errorMessage = "语音识别不可用"
            return
        }
        
        // 清理之前的任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 创建请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "无法创建请求"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 设置识别任务
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                
                if error != nil {
                    self.stopRecording()
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
        
        // 配置音频
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            errorMessage = ""
        } catch {
            errorMessage = "无法启动录音: \(error.localizedDescription)"
        }
    }
    
    private func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
    
    func clearText() {
        transcribedText = ""
    }
}