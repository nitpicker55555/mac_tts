//
//  ConversationMessageView.swift
//  toast_talk
//
//  对话消息视图组件，支持多种消息类型
//

import SwiftUI

// 消息类型枚举
enum MessageType {
    case userText(String)
    case assistantText(String)
    case toolCall(ToolCallCard)
    case codeExecution(language: String, code: String, output: String, status: ToolCallCard.Status)
    case system(String)
}

// 消息模型
struct ConversationMessage: Identifiable {
    let id: UUID
    let type: MessageType
    let timestamp: Date
    
    init(id: UUID = UUID(), type: MessageType, timestamp: Date) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
    }
}

// 单条消息视图
struct ConversationMessageView: View {
    let message: ConversationMessage
    
    var body: some View {
        switch message.type {
        case .userText(let text):
            UserMessageView(text: text, timestamp: message.timestamp)
            
        case .assistantText(let text):
            AssistantMessageView(text: text, timestamp: message.timestamp)
            
        case .toolCall(let toolCall):
            ToolCallCardView(toolCall: toolCall)
                .padding(.vertical, 4)
            
        case .codeExecution(let language, let code, let output, let status):
            CodeExecutionCardView(
                language: language,
                code: code,
                output: output,
                timestamp: message.timestamp,
                status: status
            )
            .padding(.vertical, 4)
            
        case .system(let text):
            SystemMessageView(text: text, timestamp: message.timestamp)
        }
    }
}

// 用户消息视图
struct UserMessageView: View {
    let text: String
    let timestamp: Date
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer(minLength: 60)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .textSelection(.enabled)
                
                Text(timeString(from: timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "person.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// AI助手消息视图
struct AssistantMessageView: View {
    let text: String
    let timestamp: Date
    @State private var isStreaming = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .cornerRadius(16)
                        .textSelection(.enabled)
                    
                    if isStreaming {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    }
                }
                
                Text(timeString(from: timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 60)
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// 系统消息视图
struct SystemMessageView: View {
    let text: String
    let timestamp: Date
    
    var body: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

