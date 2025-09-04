//
//  ToolCallCardView.swift
//  toast_talk
//
//  工具调用和代码执行结果的卡片视图组件
//

import SwiftUI

// 工具调用数据模型
struct ToolCallCard: Identifiable {
    let id = UUID()
    let toolName: String
    let timestamp: Date
    let input: String
    let output: String
    let status: Status
    let icon: String
    
    enum Status {
        case pending
        case running
        case success
        case error
    }
}

// 单个工具调用卡片视图
struct ToolCallCardView: View {
    let toolCall: ToolCallCard
    @State private var isExpanded = false
    @State private var showContent = false
    
    var statusColor: Color {
        switch toolCall.status {
        case .pending:
            return .gray
        case .running:
            return .orange
        case .success:
            return .green
        case .error:
            return .red
        }
    }
    
    var statusIcon: String {
        switch toolCall.status {
        case .pending:
            return "clock.fill"
        case .running:
            return "arrow.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部（可点击区域）
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                    if isExpanded {
                        // 延迟显示内容，创建展开动画效果
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                showContent = true
                            }
                        }
                    } else {
                        showContent = false
                    }
                }
            }) {
                HStack {
                    // 工具图标
                    Image(systemName: toolCall.icon)
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 30, height: 30)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    // 工具名称和时间
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toolCall.toolName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(timeString(from: toolCall.timestamp))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 状态图标
                    HStack(spacing: 4) {
                        if toolCall.status == .running {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: statusIcon)
                                .font(.system(size: 14))
                                .foregroundColor(statusColor)
                        }
                        
                        // 展开/收起图标
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            
            // 展开的内容区域
            if isExpanded && showContent {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // 输入部分
                    if !toolCall.input.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("输入", systemImage: "arrow.right.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                            
                            Text(toolCall.input)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(6)
                                .textSelection(.enabled)
                        }
                    }
                    
                    // 输出部分
                    if !toolCall.output.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("输出", systemImage: "arrow.left.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                            
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(toolCall.output)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .padding(8)
                            .frame(maxHeight: 200)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(12)
                .padding(.top, -12)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// 代码执行卡片视图
struct CodeExecutionCardView: View {
    let language: String
    let code: String
    let output: String
    let timestamp: Date
    let status: ToolCallCard.Status
    @State private var isExpanded = false
    @State private var showContent = false
    
    var languageIcon: String {
        switch language.lowercased() {
        case "python":
            return "terminal.fill"
        case "javascript", "js":
            return "curlybraces"
        case "swift":
            return "swift"
        case "bash", "shell":
            return "terminal"
        default:
            return "doc.text.fill"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .pending:
            return .gray
        case .running:
            return .orange
        case .success:
            return .green
        case .error:
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部（可点击区域）
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                    if isExpanded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                showContent = true
                            }
                        }
                    } else {
                        showContent = false
                    }
                }
            }) {
                HStack {
                    // 语言图标
                    Image(systemName: languageIcon)
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                        .frame(width: 30, height: 30)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    
                    // 标题
                    VStack(alignment: .leading, spacing: 2) {
                        Text("代码执行")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text(language.capitalized)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(timeString(from: timestamp))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 状态和展开图标
                    HStack(spacing: 8) {
                        if status == .running {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            
            // 展开的内容区域
            if isExpanded && showContent {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // 代码部分
                    VStack(alignment: .leading, spacing: 4) {
                        Label("代码", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                        
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(code)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding(8)
                        .frame(maxHeight: 150)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(6)
                    }
                    
                    // 输出部分
                    if !output.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("输出", systemImage: "terminal.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(status == .error ? .red : .green)
                            
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(output)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(status == .error ? .red : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .padding(8)
                            .frame(maxHeight: 150)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(12)
                .padding(.top, -12)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// 预览
struct ToolCallCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ToolCallCardView(
                toolCall: ToolCallCard(
                    toolName: "交通路线搜索",
                    timestamp: Date(),
                    input: "从中关村到天安门的地铁路线",
                    output: "找到3条路线:\n1. 地铁4号线 → 地铁1号线\n2. 地铁10号线 → 地铁1号线\n3. 公交特4路",
                    status: .success,
                    icon: "map.fill"
                )
            )
            
            CodeExecutionCardView(
                language: "Python",
                code: "print('Hello, World!')\nfor i in range(5):\n    print(f'Count: {i}')",
                output: "Hello, World!\nCount: 0\nCount: 1\nCount: 2\nCount: 3\nCount: 4",
                timestamp: Date(),
                status: .success
            )
        }
        .padding()
        .frame(width: 400)
    }
}