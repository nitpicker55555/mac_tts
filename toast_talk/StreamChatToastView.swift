//
//  StreamChatToastView.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI

struct StreamChatToastView: View {
    @StateObject private var conversation = StreamConversationManager()
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var showVoiceSettings = false
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            VStack(spacing: 16) {
                // 拖动区域
                HStack {
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 8)
                }
                
                // 内容区域
                VStack(spacing: 12) {
                    // 标题栏
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("AI 对话助手")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        
                        // 语音设置按钮
                        Button(action: {
                            showVoiceSettings.toggle()
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 关闭按钮
                        Button(action: {
                            NSApplication.shared.terminate(nil)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 18))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 对话历史显示区域
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                if conversation.conversationHistory.isEmpty {
                                    Text("点击麦克风开始对话...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 40)
                                } else {
                                    Text(conversation.conversationHistory)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.9))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                        .id("bottom")
                                }
                            }
                            .padding(12)
                        }
                        .frame(height: 200)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .onChange(of: conversation.conversationHistory) { _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    
                    // 实时转写显示
                    if !conversation.transcribedText.isEmpty && conversation.isRecording {
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text(conversation.transcribedText)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                        .transition(.opacity)
                    }
                    
                    // 控制按钮
                    HStack(spacing: 12) {
                        // 录音按钮
                        Button(action: {
                            // 如果AI正在说话，先停止语音
                            if conversation.isSpeaking {
                                conversation.stopSpeaking()
                            }
                            conversation.toggleRecording()
                        }) {
                            HStack(spacing: 6) {
                                if conversation.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.5)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: conversation.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 14))
                                }
                                Text(conversation.isProcessing ? "处理中..." : (conversation.isRecording ? "停止" : "说话"))
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(conversation.isRecording || conversation.isProcessing ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(conversation.isRecording || conversation.isProcessing ? Color.white : Color.white.opacity(0.2))
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(conversation.isProcessing)
                        
                        // 停止语音按钮（只在AI正在说话时显示）
                        if conversation.isSpeaking {
                            Button(action: {
                                conversation.stopSpeaking()
                            }) {
                                Image(systemName: "speaker.slash.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.2), value: conversation.isSpeaking)
                        }
                        
                        // 清除按钮
                        Button(action: {
                            conversation.clearConversation()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 音频级别和状态指示（只在录音时显示，不在处理时显示）
                    if conversation.isRecording && !conversation.isProcessing {
                        VStack(spacing: 8) {
                            // 音频级别指示器
                            GeometryReader { geometry in
                                HStack(spacing: 2) {
                                    ForEach(0..<20) { index in
                                        Rectangle()
                                            .fill(Color.green.opacity(Double(index) < Double(conversation.audioLevel * 20) ? 1.0 : 0.3))
                                            .frame(width: geometry.size.width / 20 - 2, height: 4)
                                    }
                                }
                            }
                            .frame(height: 4)
                            .padding(.horizontal, 40)
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: conversation.isRecording)
                                Text("正在监听... (说完后自动停止)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .transition(.opacity)
                    }
                    
                    // 错误信息
                    if !conversation.errorMessage.isEmpty {
                        Text(conversation.errorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.8))
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 400, height: 450)
        .offset(dragOffset)
        .onDrag {
            isDragging = true
            return NSItemProvider()
        }
        .sheet(isPresented: $showVoiceSettings) {
            VoiceSettingsView(voiceManager: conversation.voiceManager)
        }
    }
}

// 语音设置视图
struct VoiceSettingsView: View {
    @ObservedObject var voiceManager: VoiceManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("语音设置")
                .font(.title2)
                .fontWeight(.bold)
            
            // 语音选择
            VStack(alignment: .leading, spacing: 8) {
                Text("选择语音")
                    .font(.headline)
                
                ForEach(voiceManager.availableVoices, id: \.identifier) { voice in
                    HStack {
                        Text(voiceManager.getVoiceName(voice))
                        Spacer()
                        if voice == voiceManager.selectedVoice {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        voiceManager.selectedVoice = voice
                        // 试听
                        voiceManager.speak("你好，我是\(voiceManager.getVoiceName(voice))")
                    }
                }
            }
            
            // 语速控制
            VStack(alignment: .leading, spacing: 8) {
                Text("语速: \(String(format: "%.1f", voiceManager.speechRate))")
                    .font(.headline)
                Slider(value: $voiceManager.speechRate, in: 0.1...1.0)
            }
            
            // 音量控制
            VStack(alignment: .leading, spacing: 8) {
                Text("音量: \(String(format: "%.1f", voiceManager.speechVolume))")
                    .font(.headline)
                Slider(value: $voiceManager.speechVolume, in: 0.1...1.0)
            }
            
            Button("完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 350, height: 400)
    }
}

#Preview {
    StreamChatToastView()
}