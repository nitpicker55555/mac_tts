//
//  ContentViewWithTools.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import SwiftUI
import AVFoundation

struct ContentViewWithTools: View {
    @StateObject private var conversationManager = StreamConversationManagerWithTools()
    @StateObject private var codeExecutor = UniversalCodeExecutor()
    @State private var showingSettings = false
    @State private var showLogViewer = false
    @State private var showMapWindow = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题和设置
            HStack {
                Text("语音对话助手（支持工具）")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 10) {
                    // 地图按钮
                    Button(action: {
                        if conversationManager.currentGeoJSON != nil {
                            showMapWindow = true
                        }
                    }) {
                        Image(systemName: "map")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .help("查看地图路线")
                    .disabled(conversationManager.currentGeoJSON == nil)
                    
                    // 日志按钮
                    Button(action: {
                        showLogViewer = true
                    }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .help("查看日志")
                    
                    // 设置按钮
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .help("设置")
                }
            }
            .padding(.horizontal)
            
            // 录音状态和音频级别
            VStack(spacing: 10) {
                // 音频级别指示器
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(0..<20) { index in
                            Rectangle()
                                .fill(Color.green.opacity(Double(index) < Double(conversationManager.audioLevel * 20) ? 1.0 : 0.3))
                                .frame(width: geometry.size.width / 20 - 2, height: 8)
                        }
                    }
                }
                .frame(height: 8)
                .padding(.horizontal)
                
                // 录音按钮
                Button(action: {
                    conversationManager.toggleRecording()
                }) {
                    HStack {
                        Image(systemName: conversationManager.isRecording ? "mic.fill" : "mic")
                            .font(.title)
                        Text(conversationManager.isRecording ? "停止录音" : "开始录音")
                            .font(.headline)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(conversationManager.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(conversationManager.isProcessing)
                
                // 状态指示
                if conversationManager.isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("AI正在思考...")
                            .foregroundColor(.secondary)
                    }
                }
                
                if conversationManager.isSpeaking {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.blue)
                        Text("正在播放语音...")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 实时转录文本
            if !conversationManager.transcribedText.isEmpty {
                GroupBox("实时转录") {
                    ScrollView {
                        Text(conversationManager.transcribedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 80)
                }
                .padding(.horizontal)
            }
            
            // 对话历史
            GroupBox("对话历史") {
                ScrollView {
                    Text(conversationManager.conversationHistory)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(.horizontal)
            
            // 控制按钮
            HStack(spacing: 20) {
                // 语音播放开关
                Toggle("语音播放", isOn: $conversationManager.enableVoicePlayback)
                    .toggleStyle(.switch)
                
                Spacer()
                
                // 停止语音按钮
                if conversationManager.isSpeaking {
                    Button(action: {
                        conversationManager.stopSpeaking()
                    }) {
                        Label("停止语音", systemImage: "stop.fill")
                    }
                }
                
                // 清除对话按钮
                Button(action: {
                    conversationManager.clearConversation()
                }) {
                    Label("清除对话", systemImage: "trash")
                }
            }
            .padding(.horizontal)
            
            // 错误提示
            if !conversationManager.errorMessage.isEmpty {
                Text(conversationManager.errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .frame(minWidth: 800, minHeight: 600)
        
        // 设置窗口
        .sheet(isPresented: $showingSettings) {
            SettingsViewWithTools(conversationManager: conversationManager)
        }
        
        // 日志窗口
        .sheet(isPresented: $showLogViewer) {
            LogViewerView()
        }
        
        // 地图窗口
        .sheet(isPresented: $showMapWindow) {
            if !conversationManager.allJourneys.isEmpty {
                // 使用增强版地图视图显示多个路线
                EnhancedMapRouteView(journeys: conversationManager.allJourneys)
            } else if let geoJSON = conversationManager.currentGeoJSON {
                // 降级到基础版地图视图
                MapRouteView(
                    geoJSON: geoJSON,
                    routeInfo: conversationManager.currentRouteInfo
                )
            }
        }
        
        // 监听地图显示状态
        .onChange(of: conversationManager.showMapView) { newValue in
            if newValue && conversationManager.currentGeoJSON != nil {
                showMapWindow = true
                conversationManager.showMapView = false
            }
        }
    }
}

// 设置视图（支持工具）
struct SettingsViewWithTools: View {
    @ObservedObject var conversationManager: StreamConversationManagerWithTools
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedVoice: AVSpeechSynthesisVoice?
    @State private var speechRate: Float = 0.5
    @State private var autoExecuteCode = false
    
    var body: some View {
        VStack {
            Text("设置")
                .font(.largeTitle)
                .padding()
            
            Form {
                Section("语音设置") {
                    // 语音选择
                    Picker("选择语音", selection: $selectedVoice) {
                        ForEach(AVSpeechSynthesisVoice.speechVoices(), id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))")
                                .tag(voice as AVSpeechSynthesisVoice?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    // 语速控制
                    HStack {
                        Text("语速:")
                        Slider(value: $speechRate, in: 0.1...1.0)
                        Text(String(format: "%.1fx", speechRate))
                    }
                }
                
                Section("代码执行设置") {
                    Toggle("自动执行代码", isOn: $autoExecuteCode)
                        .help("开启后将自动执行AI生成的代码")
                }
                
                Section("工具设置") {
                    Text("已启用的工具:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Label("交通路线搜索", systemImage: "map")
                            .foregroundColor(.blue)
                        Text("可以搜索两点之间的公共交通路线，并在地图上显示")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
            .padding()
            
            // 按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("确定") {
                    // 应用设置
                    if let voice = selectedVoice {
                        conversationManager.setVoice(voice)
                    }
                    conversationManager.setSpeechRate(speechRate)
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            speechRate = conversationManager.voiceManager.speechRate
        }
    }
}

// 预览
struct ContentViewWithTools_Previews: PreviewProvider {
    static var previews: some View {
        ContentViewWithTools()
    }
}