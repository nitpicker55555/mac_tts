//
//  SimpleSpeechManager.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI
import Speech

class SimpleSpeechManager: ObservableObject {
    @Published var text = "点击开始录音"
    @Published var isRecording = false
    
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    func toggleRecording() {
        if isRecording {
            stop()
        } else {
            start()
        }
    }
    
    private func start() {
        // 请求权限
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard authStatus == .authorized else {
                DispatchQueue.main.async {
                    self?.text = "需要语音识别权限"
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.startRecording()
            }
        }
    }
    
    private func startRecording() {
        // 重置
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            text = "语音识别不可用"
            return
        }
        
        do {
            // 创建请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // 启动任务
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self?.text = result.bestTranscription.formattedString
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
            try audioEngine.start()
            
            text = "正在录音..."
            isRecording = true
            
        } catch {
            text = "错误: \(error.localizedDescription)"
        }
    }
    
    private func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
    }
}