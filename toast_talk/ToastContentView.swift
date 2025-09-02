//
//  ToastContentView.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI

struct ToastContentView: View {
    @StateObject private var manager = SimpleSpeechManager()
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var windowPosition = CGPoint(x: 100, y: 100)
    
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
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("语音转文字")
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
                    
                    // 文本显示区域
                    ScrollView {
                        Text(manager.text)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .frame(height: 120)
                    
                    // 控制按钮
                    HStack(spacing: 12) {
                        // 录音按钮
                        Button(action: {
                            manager.toggleRecording()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: manager.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 14))
                                Text(manager.isRecording ? "停止" : "开始")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(manager.isRecording ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(manager.isRecording ? Color.white : Color.white.opacity(0.2))
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 清除按钮
                        Button(action: {
                            manager.text = "点击开始录音"
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
                    
                    // 录音状态指示
                    if manager.isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .scaleEffect(manager.isRecording ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: manager.isRecording)
                            Text("正在录音...")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 350, height: 300)
        .offset(dragOffset)
        .onDrag {
            isDragging = true
            return NSItemProvider()
        }
    }
}

#Preview {
    ToastContentView()
}