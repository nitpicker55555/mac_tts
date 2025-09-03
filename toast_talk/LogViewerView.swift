//
//  LogViewerView.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import SwiftUI
import AppKit

struct LogViewerView: View {
    @State private var selectedLog: URL?
    @State private var logContent: String = ""
    @State private var isExporting = false
    
    private var logFiles: [URL] {
        LogManager.shared.getAllLogFiles()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("日志查看器")
                    .font(.headline)
                
                Spacer()
                
                if let currentPath = LogManager.shared.getCurrentLogPath() {
                    Text("当前日志: \(URL(fileURLWithPath: currentPath).lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: openLogFolder) {
                    Image(systemName: "folder")
                }
                .buttonStyle(PlainButtonStyle())
                .help("在 Finder 中打开日志文件夹")
                
                Button(action: { isExporting = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedLog == nil)
                .help("导出选中的日志文件")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 主体内容
            HSplitView {
                // 左侧：日志文件列表
                VStack(alignment: .leading, spacing: 0) {
                    Text("日志文件")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(logFiles, id: \.self) { file in
                                LogFileRow(
                                    file: file,
                                    isSelected: selectedLog == file,
                                    onSelect: {
                                        selectedLog = file
                                        loadLogContent(from: file)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(width: 200)
                
                // 右侧：日志内容
                VStack(alignment: .leading, spacing: 0) {
                    if selectedLog != nil {
                        HStack {
                            Text("日志内容")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("刷新") {
                                if let log = selectedLog {
                                    loadLogContent(from: log)
                                }
                            }
                            .font(.caption)
                            
                            Button("清空视图") {
                                logContent = ""
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        ScrollView {
                            Text(logContent.isEmpty ? "选择一个日志文件查看内容" : logContent)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .textSelection(.enabled)
                        }
                        .background(Color(NSColor.textBackgroundColor))
                    } else {
                        VStack {
                            Spacer()
                            Text("请选择一个日志文件")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.textBackgroundColor))
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $isExporting) {
            if let log = selectedLog {
                ExportLogView(logFile: log)
            }
        }
    }
    
    private func loadLogContent(from file: URL) {
        do {
            logContent = try String(contentsOf: file, encoding: .utf8)
        } catch {
            logContent = "无法读取日志文件: \(error.localizedDescription)"
        }
    }
    
    private func openLogFolder() {
        if let path = LogManager.shared.getCurrentLogPath() {
            let folderURL = URL(fileURLWithPath: path).deletingLastPathComponent()
            NSWorkspace.shared.open(folderURL)
        }
    }
}

struct LogFileRow: View {
    let file: URL
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var fileInfo: (name: String, size: String, date: String) {
        let fileName = file.lastPathComponent
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
        let sizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        
        // 从文件名提取日期
        let dateString = fileName
            .replacingOccurrences(of: "toast_talk_", with: "")
            .replacingOccurrences(of: ".log", with: "")
        
        return (fileName, sizeString, dateString)
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(isSelected ? .white : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileInfo.date)
                        .font(.system(.body))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(fileInfo.size)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExportLogView: View {
    let logFile: URL
    @Environment(\.dismiss) var dismiss
    @State private var showingSavePanel = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("导出日志文件")
                .font(.headline)
            
            Text("文件: \(logFile.lastPathComponent)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                
                Button("导出") {
                    exportLog()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func exportLog() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = logFile.lastPathComponent
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try FileManager.default.copyItem(at: logFile, to: url)
                    dismiss()
                } catch {
                    print("导出失败: \(error)")
                }
            }
        }
    }
}