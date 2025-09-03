//
//  CodeExecutionView.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import SwiftUI

struct CodeExecutionView: View {
    @ObservedObject var executor: UniversalCodeExecutor
    @State private var showingExecutionHistory = false
    
    var body: some View {
        VStack(spacing: 10) {
            // 执行状态和设置
            HStack {
                HStack {
                    Circle()
                        .fill(executor.isExecuting ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(executor.isExecuting ? "执行中..." : "就绪")
                        .font(.caption)
                }
                
                Spacer()
                
                Toggle("执行前确认", isOn: $executor.requireConfirmation)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .font(.caption)
                
                Button(action: { showingExecutionHistory.toggle() }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("查看执行历史")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // 最近执行结果
            if let lastResult = executor.executionHistory.last {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("最近执行: \(lastResult.language.displayName)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        if lastResult.exitCode == 0 {
                            Label("成功", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("失败", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    if !lastResult.output.isEmpty {
                        Text("输出: \(lastResult.output)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let error = lastResult.error {
                        Text("错误: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            }
        }
        .sheet(isPresented: $showingExecutionHistory) {
            ExecutionHistoryView(history: executor.executionHistory)
        }
    }
}

struct ExecutionHistoryView: View {
    let history: [ExecutionResult]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Text("执行历史")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(history.enumerated().reversed()), id: \.offset) { index, result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(result.language.displayName)")
                                    .font(.headline)
                                Spacer()
                                Text(result.timestamp.formatted())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("代码:")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(result.code)
                                .font(.system(.caption, design: .monospaced))
                                .padding(6)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)
                            
                            if !result.output.isEmpty {
                                Text("输出:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(result.output)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(6)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(4)
                            }
                            
                            if let error = result.error {
                                Text("错误:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            HStack {
                                Label("退出码: \(result.exitCode)", systemImage: result.exitCode == 0 ? "checkmark.circle" : "xmark.circle")
                                    .foregroundColor(result.exitCode == 0 ? .green : .red)
                                Spacer()
                                Text("耗时: \(String(format: "%.2f", result.duration))秒")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
}