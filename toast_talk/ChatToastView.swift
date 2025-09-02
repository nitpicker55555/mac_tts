//
//  ChatToastView.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI

struct ChatToastView: View {
    @StateObject private var conversation = ConversationManager()
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    
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
                    // 标题
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("AI 对话助手")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        
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
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    
                    // 当前识别的文本
                    if !conversation.transcribedText.isEmpty && conversation.isRecording {
                        Text(conversation.transcribedText)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 控制按钮
                    HStack(spacing: 12) {
                        // 录音按钮
                        Button(action: {
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
                    
                    // 状态指示
                    if conversation.isRecording {
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
                                    .scaleEffect(conversation.isRecording ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: conversation.isRecording)
                                Text("正在监听... (说完后自动停止)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
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
        .frame(width: 400, height: 400)
        .offset(dragOffset)
        .onDrag {
            isDragging = true
            return NSItemProvider()
        }
    }
}

#Preview {
    ChatToastView()
}