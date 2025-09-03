//
//  EnvironmentSetupView.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import SwiftUI

struct EnvironmentSetupView: View {
    @State private var condaStatus = "检查中..."
    @State private var isSettingUp = false
    @State private var setupLog = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Python环境设置")
                .font(.headline)
            
            HStack {
                Image(systemName: condaStatus.contains("已找到") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(condaStatus.contains("已找到") ? .green : .orange)
                
                Text(condaStatus)
                    .font(.caption)
            }
            
            if !condaStatus.contains("已找到") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("需要创建conda环境以支持Python绘图功能")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("创建环境") {
                        setupCondaEnvironment()
                    }
                    .disabled(isSettingUp)
                    
                    if isSettingUp {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        ScrollView {
                            Text(setupLog)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 100)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            checkCondaEnvironment()
        }
    }
    
    private func checkCondaEnvironment() {
        if let pythonPath = CondaEnvironmentManager.shared.pythonPath {
            condaStatus = "已找到conda环境: \(pythonPath)"
        } else {
            condaStatus = "未找到conda环境"
        }
    }
    
    private func setupCondaEnvironment() {
        isSettingUp = true
        setupLog = "开始创建环境...\n"
        
        Task {
            let setupScript = NSString(string: "~/Documents/toast_talk/setup_conda_env.sh").expandingTildeInPath
            
            if FileManager.default.fileExists(atPath: setupScript) {
                let process = Process()
                let pipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [setupScript]
                process.standardOutput = pipe
                process.standardError = pipe
                
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                        DispatchQueue.main.async {
                            self.setupLog += output
                        }
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    DispatchQueue.main.async {
                        self.isSettingUp = false
                        self.checkCondaEnvironment()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.setupLog += "\n错误: \(error.localizedDescription)"
                        self.isSettingUp = false
                    }
                }
            } else {
                setupLog += "错误: 找不到安装脚本"
                isSettingUp = false
            }
        }
    }
}