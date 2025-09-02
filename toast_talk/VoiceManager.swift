//
//  VoiceManager.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import Foundation
import AVFoundation

// 语音管理器
class VoiceManager: NSObject, ObservableObject {
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    @Published var isSpeaking = false
    @Published var speechRate: Float = Config.defaultSpeechRate
    @Published var speechVolume: Float = 1.0
    
    private let synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        loadVoices()
        synthesizer.delegate = self
    }
    
    // 加载所有可用的中文语音
    func loadVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            // 筛选中文语音
            voice.language.hasPrefix("zh-")
        }.sorted { $0.name < $1.name }
        
        // 默认选择第一个中文语音
        selectedVoice = availableVoices.first ?? AVSpeechSynthesisVoice(language: "zh-CN")
        
        // 打印所有可用的语音
        print("Available Chinese voices:")
        for voice in availableVoices {
            print("- \(voice.name) (\(voice.language)) - Quality: \(voice.quality == .enhanced ? "Enhanced" : "Default")")
        }
    }
    
    // 获取语音的友好名称
    func getVoiceName(_ voice: AVSpeechSynthesisVoice) -> String {
        let name = voice.name
        let quality = voice.quality == .enhanced ? " (高质量)" : ""
        
        // 简化语音名称
        if name.contains("Ting-Ting") {
            return "婷婷\(quality)"
        } else if name.contains("Yu-shu") {
            return "雨舒\(quality)"
        } else if name.contains("Tian-Tian") {
            return "甜甜\(quality)"
        } else if name.contains("Sin-ji") {
            return "新吉 (粤语)\(quality)"
        } else if name.contains("Mei-Jia") {
            return "美佳 (台湾)\(quality)"
        } else {
            return name + quality
        }
    }
    
    // 播放文本
    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = speechRate
        utterance.volume = speechVolume
        
        synthesizer.speak(utterance)
    }
    
    // 停止播放
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // 暂停播放
    func pauseSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    // 继续播放
    func continueSpeaking() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
}

// AVSpeechSynthesizerDelegate
extension VoiceManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}