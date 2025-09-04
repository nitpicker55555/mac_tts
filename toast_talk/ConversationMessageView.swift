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
                    .background(Color.blue.opacity(0.9))
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
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
    @State private var isExpanded = true
    
    // 计算文本行数
    private var lineCount: Int {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var totalLines = 0
        
        // 估算每行的字符数（约40个字符算一行）
        for line in lines {
            if line.isEmpty {
                totalLines += 1
            } else {
                totalLines += max(1, (line.count + 39) / 40)
            }
        }
        
        return totalLines
    }
    
    private var shouldShowToggle: Bool {
        return lineCount > 4
    }
    
    private var displayText: String {
        if !shouldShowToggle || isExpanded {
            return text
        }
        
        // 截取前4行内容
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var resultLines: [String] = []
        var currentLineCount = 0
        
        for line in lines {
            if currentLineCount >= 4 {
                break
            }
            
            if line.isEmpty {
                resultLines.append("")
                currentLineCount += 1
            } else {
                let estimatedLines = max(1, (line.count + 39) / 40)
                if currentLineCount + estimatedLines <= 4 {
                    resultLines.append(String(line))
                    currentLineCount += estimatedLines
                } else {
                    // 截断这一行
                    let remainingLines = 4 - currentLineCount
                    let charsToShow = remainingLines * 40
                    let truncated = String(line.prefix(charsToShow))
                    resultLines.append(truncated + "...")
                    break
                }
            }
        }
        
        return resultLines.joined(separator: "\n")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text(displayText)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                            .textSelection(.enabled)
                        
                        if isStreaming {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.5)
                                .frame(width: 16, height: 16)
                        }
                    }
                    
                    // 展开/折叠按钮
                    if shouldShowToggle {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10))
                                Text(isExpanded ? "收起" : "展开全部")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.green.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 4)
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
                    .foregroundColor(.purple)
                
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            .shadow(color: .purple.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

