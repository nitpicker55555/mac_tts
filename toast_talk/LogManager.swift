//
//  LogManager.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import Foundation

class LogManager {
    static let shared = LogManager()
    
    private let dateFormatter: DateFormatter
    private let timestampFormatter: DateFormatter
    private let logDirectory: URL
    private var currentLogFile: URL?
    private let logQueue = DispatchQueue(label: "com.toast_talk.log", qos: .background)
    
    private init() {
        // 设置日期格式
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // 创建日志目录
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                     in: .userDomainMask).first!
        logDirectory = documentsPath.appendingPathComponent("toast_talk_logs")
        
        do {
            try FileManager.default.createDirectory(at: logDirectory, 
                                                  withIntermediateDirectories: true)
            print("日志目录: \(logDirectory.path)")
        } catch {
            print("创建日志目录失败: \(error)")
        }
        
        // 创建当日日志文件
        createDailyLogFile()
    }
    
    private func createDailyLogFile() {
        let fileName = "toast_talk_\(dateFormatter.string(from: Date())).log"
        currentLogFile = logDirectory.appendingPathComponent(fileName)
        
        // 如果文件不存在，创建并写入头部信息
        if !FileManager.default.fileExists(atPath: currentLogFile!.path) {
            let header = """
            ========================================
            Toast Talk 日志文件
            创建时间: \(timestampFormatter.string(from: Date()))
            ========================================
            
            """
            try? header.write(to: currentLogFile!, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - 公共方法
    
    /// 记录一般信息
    func log(_ message: String, category: LogCategory = .general) {
        let logEntry = formatLogEntry(message, level: .info, category: category)
        writeToFile(logEntry)
    }
    
    /// 记录错误
    func logError(_ message: String, category: LogCategory = .general) {
        let logEntry = formatLogEntry(message, level: .error, category: category)
        writeToFile(logEntry)
    }
    
    /// 记录调试信息
    func logDebug(_ message: String, category: LogCategory = .general) {
        let logEntry = formatLogEntry(message, level: .debug, category: category)
        writeToFile(logEntry)
    }
    
    /// 记录会话
    func logConversation(user: String? = nil, assistant: String? = nil) {
        var message = ""
        if let user = user {
            message += "[用户]: \(user)\n"
        }
        if let assistant = assistant {
            message += "[助手]: \(assistant)"
        }
        let logEntry = formatLogEntry(message, level: .info, category: .conversation)
        writeToFile(logEntry)
    }
    
    /// 记录代码执行
    func logCodeExecution(language: String, code: String, result: ExecutionResult) {
        let message = """
        语言: \(language)
        代码:
        ```\(language)
        \(code)
        ```
        输出: \(result.output)
        错误: \(result.error ?? "无")
        退出码: \(result.exitCode)
        耗时: \(String(format: "%.2f", result.duration))秒
        """
        let logEntry = formatLogEntry(message, level: .info, category: .codeExecution)
        writeToFile(logEntry)
    }
    
    /// 记录系统事件
    func logSystem(_ message: String) {
        let logEntry = formatLogEntry(message, level: .info, category: .system)
        writeToFile(logEntry)
    }
    
    // MARK: - 私有方法
    
    private func formatLogEntry(_ message: String, level: LogLevel, category: LogCategory) -> String {
        let timestamp = timestampFormatter.string(from: Date())
        let categoryTag = "[\(category.rawValue)]"
        let levelTag = "[\(level.rawValue)]"
        
        return """
        \(timestamp) \(levelTag) \(categoryTag)
        \(message)
        ----------------------------------------
        
        """
    }
    
    private func writeToFile(_ logEntry: String) {
        logQueue.async { [weak self] in
            guard let self = self,
                  let logFile = self.currentLogFile else { return }
            
            // 检查是否需要创建新的日志文件（日期变更）
            let currentDate = self.dateFormatter.string(from: Date())
            if !logFile.lastPathComponent.contains(currentDate) {
                self.createDailyLogFile()
            }
            
            // 追加写入日志
            do {
                if let fileHandle = FileHandle(forWritingAtPath: logFile.path) {
                    fileHandle.seekToEndOfFile()
                    if let data = logEntry.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                } else {
                    // 文件不存在，创建新文件
                    try logEntry.write(to: logFile, atomically: true, encoding: .utf8)
                }
            } catch {
                print("写入日志失败: \(error)")
            }
        }
    }
    
    // MARK: - 辅助功能
    
    /// 获取所有日志文件
    func getAllLogFiles() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: logDirectory,
                                                                   includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "log" }
                       .sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            print("读取日志文件列表失败: \(error)")
            return []
        }
    }
    
    /// 获取当前日志文件路径
    func getCurrentLogPath() -> String? {
        return currentLogFile?.path
    }
    
    /// 清理旧日志（保留最近N天）
    func cleanOldLogs(keepDays: Int = 7) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date())!
        let cutoffString = dateFormatter.string(from: cutoffDate)
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let files = self.getAllLogFiles()
            for file in files {
                let fileName = file.lastPathComponent
                // 从文件名提取日期
                if let dateRange = fileName.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression),
                   fileName[dateRange] < cutoffString {
                    try? FileManager.default.removeItem(at: file)
                    print("删除旧日志: \(fileName)")
                }
            }
        }
    }
}

// MARK: - 日志级别
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

// MARK: - 日志分类
enum LogCategory: String {
    case general = "通用"
    case conversation = "会话"
    case codeExecution = "代码执行"
    case system = "系统"
    case network = "网络"
}