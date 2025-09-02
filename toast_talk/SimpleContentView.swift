//
//  SimpleContentView.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI

struct SimpleContentView: View {
    @StateObject private var manager = SimpleSpeechManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("语音转文字测试")
                .font(.title)
            
            ScrollView {
                Text(manager.text)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding()
            
            Button(action: {
                manager.toggleRecording()
            }) {
                Text(manager.isRecording ? "停止录音" : "开始录音")
                    .padding()
                    .background(manager.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}