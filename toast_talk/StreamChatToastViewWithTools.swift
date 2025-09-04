//
//  StreamChatToastViewWithTools.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import SwiftUI

struct StreamChatToastViewWithTools: View {
    @StateObject private var conversation = StreamConversationManagerWithTools()
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var showVoiceSettings = false
    @State private var showMapView = false
    
    var body: some View {
        ZStack {
            // 毛玻璃背景
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
            
            VStack(spacing: 16) {
                // 拖动区域
                HStack {
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 40, height: 4)
                        .padding(.top, 8)
                }
                
                // 内容区域
                VStack(spacing: 12) {
                    // 标题栏
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.primary)
                        Text("AI 对话助手（含工具）")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        
                        // 地图按钮（当有路线数据时显示）
                        if !conversation.allJourneys.isEmpty || conversation.currentGeoJSON != nil {
                            Button(action: {
                                if !conversation.allJourneys.isEmpty {
                                    RouteMapWindowController.shared.showRouteMap(
                                        journeys: conversation.allJourneys,
                                        initialSelectedIndex: 0
                                    )
                                } else {
                                    showMapView = true  // 降级方案
                                }
                            }) {
                                Image(systemName: "map.fill")
                                    .foregroundColor(.blue.opacity(0.8))
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.scale.combined(with: .opacity))
                        }
                        
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
                                    VStack(spacing: 12) {
                                        Text("点击麦克风开始对话...")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        // 工具提示
                                        VStack(alignment: .leading, spacing: 6) {
                                            Label("可用工具", systemImage: "wrench.and.screwdriver.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.7))
                                            
                                            HStack {
                                                Image(systemName: "map")
                                                Text("交通路线搜索")
                                                    .font(.system(size: 11))
                                            }
                                            .foregroundColor(.blue.opacity(0.7))
                                            .padding(.leading, 20)
                                        }
                                        .padding(12)
                                        .background(Color.black.opacity(0.05))
                                        .cornerRadius(8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 20)
                                } else {
                                    Text(conversation.conversationHistory)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                        .id("bottom")
                                }
                            }
                            .padding(12)
                        }
                        .frame(height: 200)
                        .background(Color.black.opacity(0.05))
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
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.05))
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
                            .foregroundColor(conversation.isRecording || conversation.isProcessing ? .white : .primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(conversation.isRecording || conversation.isProcessing ? Color.red : Color.black.opacity(0.1))
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
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(Color.black.opacity(0.1))
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
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color.black.opacity(0.1))
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
                                    .foregroundColor(.secondary)
                            }
                        }
                        .transition(.opacity)
                    }
                    
                    // 错误信息
                    if !conversation.errorMessage.isEmpty {
                        Text(conversation.errorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
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
        // 监听地图显示状态
        .onChange(of: conversation.showMapView) { newValue in
            if newValue {
                if !conversation.allJourneys.isEmpty {
                    // 使用独立窗口显示路线地图
                    RouteMapWindowController.shared.showRouteMap(
                        journeys: conversation.allJourneys,
                        initialSelectedIndex: 0
                    )
                } else if let geoJSON = conversation.currentGeoJSON {
                    // 降级使用sheet显示基础地图视图
                    showMapView = true
                }
                conversation.showMapView = false
            }
        }
        .sheet(isPresented: $showMapView) {
            // 仅用于降级方案
            if let geoJSON = conversation.currentGeoJSON {
                MapRouteView(
                    geoJSON: geoJSON,
                    routeInfo: conversation.currentRouteInfo
                )
            }
        }
    }
}

#Preview {
    StreamChatToastViewWithTools()
}