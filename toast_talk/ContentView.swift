//
//  ContentView.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var speechManager = SpeechRecognitionManager()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("实时语音转文字")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ScrollView {
                Text(speechManager.transcribedText.isEmpty ? "点击开始按钮说话..." : speechManager.transcribedText)
                    .font(.system(size: 18))
                    .foregroundColor(speechManager.transcribedText.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .frame(minHeight: 200, maxHeight: 400)
            
            if !speechManager.errorMessage.isEmpty {
                Text(speechManager.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    speechManager.toggleRecording()
                }) {
                    HStack {
                        Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title2)
                        Text(speechManager.isRecording ? "停止" : "开始")
                            .font(.title3)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(speechManager.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    speechManager.clearText()
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("清除")
                            .font(.title3)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(speechManager.transcribedText.isEmpty)
            }
            
            if speechManager.isRecording {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .scaleEffect(speechManager.isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: speechManager.isRecording)
                    Text("正在录音...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
