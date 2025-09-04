//
//  ImprovedStreamChatToastView.swift
//  toast_talk
//
//  改进的Toast对话视图，支持卡片式UI显示
//

import SwiftUI

struct ImprovedStreamChatToastView: View {
    @StateObject private var conversation = ImprovedStreamConversationManager()
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var showVoiceSettings = false
    @State private var showMapView = false
    @State private var windowHeight: CGFloat = 520
    @State private var showHeightMenu = false
    
    enum HeightPreset: CGFloat, CaseIterable {
        case compact = 400
        case standard = 520
        case tall = 650
        case fullHeight = 780
        
        var label: String {
            switch self {
            case .compact: return "紧凑"
            case .standard: return "标准"
            case .tall: return "加高"
            case .fullHeight: return "最大"
            }
        }
    }
    
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
                        Text("AI 对话助手")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        
                        // 地图按钮
                        if !conversation.allJourneys.isEmpty || conversation.currentGeoJSON != nil {
                            Button(action: {
                                if !conversation.allJourneys.isEmpty {
                                    RouteMapWindowController.shared.showRouteMap(
                                        journeys: conversation.allJourneys,
                                        initialSelectedIndex: 0
                                    )
                                } else {
                                    showMapView = true
                                }
                            }) {
                                Image(systemName: "map.fill")
                                    .foregroundColor(.blue.opacity(0.8))
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // 高度调整按钮
                        Menu {
                            ForEach(HeightPreset.allCases, id: \.self) { preset in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        windowHeight = preset.rawValue
                                    }
                                }) {
                                    HStack {
                                        Text(preset.label)
                                        if windowHeight == preset.rawValue {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.and.down")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        
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
                    
                    // 改进的对话显示区域
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                if conversation.messages.isEmpty {
                                    // 欢迎界面
                                    VStack(spacing: 16) {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.blue.opacity(0.6))
                                        
                                        Text("点击麦克风开始对话")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                        
                                        // 功能介绍卡片
                                        VStack(alignment: .leading, spacing: 12) {
                                            Label("可用功能", systemImage: "star.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "map")
                                                        .foregroundColor(.blue)
                                                        .frame(width: 20)
                                                    Text("交通路线规划")
                                                        .font(.system(size: 13))
                                                }
                                                
                                                HStack(spacing: 8) {
                                                    Image(systemName: "terminal")
                                                        .foregroundColor(.orange)
                                                        .frame(width: 20)
                                                    Text("代码执行")
                                                        .font(.system(size: 13))
                                                }
                                                
                                                HStack(spacing: 8) {
                                                    Image(systemName: "cpu")
                                                        .foregroundColor(.green)
                                                        .frame(width: 20)
                                                    Text("智能对话")
                                                        .font(.system(size: 13))
                                                }
                                            }
                                            .padding(.leading, 4)
                                        }
                                        .padding(16)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                        .frame(maxWidth: 300)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, 40)
                                } else {
                                    // 消息列表
                                    ForEach(conversation.messages) { message in
                                        ConversationMessageView(message: message)
                                            .id(message.id)
                                    }
                                }
                            }
                            .padding(12)
                        }
                        .frame(height: max(100, windowHeight - 240))
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .onChange(of: conversation.messages.count) { _ in
                            withAnimation(.easeOut(duration: 0.3)) {
                                if let lastMessage = conversation.messages.last {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // 实时转写显示
                    if !conversation.transcribedText.isEmpty && conversation.isRecording {
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                                .scaleEffect(1.2)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: conversation.isRecording)
                            
                            Text(conversation.transcribedText)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // 控制按钮
                    HStack(spacing: 16) {
                        // 录音按钮
                        Button(action: {
                            if conversation.isSpeaking {
                                conversation.stopSpeaking()
                            }
                            conversation.toggleRecording()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(conversation.isRecording || conversation.isProcessing ? Color.red : Color.blue)
                                    .frame(width: 56, height: 56)
                                
                                if conversation.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: conversation.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                            .shadow(color: (conversation.isRecording || conversation.isProcessing) ? .red.opacity(0.3) : .blue.opacity(0.3), radius: 8)
                            .scaleEffect(conversation.isRecording ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3), value: conversation.isRecording)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(conversation.isProcessing)
                        
                        // 辅助按钮组
                        VStack(spacing: 8) {
                            // 停止语音按钮
                            if conversation.isSpeaking {
                                Button(action: {
                                    conversation.stopSpeaking()
                                }) {
                                    Image(systemName: "speaker.slash.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .frame(width: 32, height: 32)
                                        .background(Color.black.opacity(0.1))
                                        .cornerRadius(16)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // 清除按钮
                            Button(action: {
                                conversation.clearConversation()
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.black.opacity(0.1))
                                    .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // 音频级别指示器
                    if conversation.isRecording && !conversation.isProcessing {
                        VStack(spacing: 4) {
                            GeometryReader { geometry in
                                HStack(spacing: 2) {
                                    ForEach(0..<30) { index in
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue, .green],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                                .opacity(Double(index) < Double(conversation.audioLevel * 30) ? 1.0 : 0.2)
                                            )
                                            .frame(
                                                width: (geometry.size.width / 30) - 2,
                                                height: Double(index) < Double(conversation.audioLevel * 30) ? 8 : 4
                                            )
                                            .animation(.easeInOut(duration: 0.1), value: conversation.audioLevel)
                                    }
                                }
                            }
                            .frame(height: 8)
                            .padding(.horizontal, 20)
                        }
                        .transition(.opacity)
                    }
                    
                    // 错误信息
                    if !conversation.errorMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                            
                            Text(conversation.errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
        }
        .frame(width: 480, height: windowHeight)
        .offset(dragOffset)
        .onDrag {
            isDragging = true
            return NSItemProvider()
        }
        .sheet(isPresented: $showVoiceSettings) {
            VoiceSettingsView(voiceManager: conversation.voiceManager)
        }
        .onChange(of: conversation.showMapView) { newValue in
            if newValue {
                if !conversation.allJourneys.isEmpty {
                    RouteMapWindowController.shared.showRouteMap(
                        journeys: conversation.allJourneys,
                        initialSelectedIndex: 0
                    )
                } else if let geoJSON = conversation.currentGeoJSON {
                    showMapView = true
                }
                conversation.showMapView = false
            }
        }
        .sheet(isPresented: $showMapView) {
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
    ImprovedStreamChatToastView()
}