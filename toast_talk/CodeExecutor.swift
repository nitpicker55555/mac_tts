//
//  CodeExecutor.swift
//  toast_talk
//
//  Created by Assistant on 02.09.25.
//

import Foundation
import AppKit

// MARK: - 数据模型

enum CodeLanguage: String, CaseIterable {
    case python = "python"
    case bash = "bash"
    case sh = "sh"
    case javascript = "javascript"
    case js = "js"
    
    var displayName: String {
        switch self {
        case .python: return "Python"
        case .bash, .sh: return "Bash"
        case .javascript, .js: return "JavaScript"
        }
    }
    
    var executable: String {
        switch self {
        case .python: 
            // 尝试使用conda环境的Python
            let condaPath = CondaEnvironmentManager.shared.pythonPath
            return condaPath ?? "/usr/bin/python3"
        case .bash, .sh: return "/bin/bash"
        case .javascript, .js: return "/usr/local/bin/node"
        }
    }
}

struct CodeBlock {
    let language: CodeLanguage
    let content: String
    let lineNumber: Int
}

struct ExecutionResult {
    let language: CodeLanguage
    let code: String
    let output: String
    let error: String?
    let exitCode: Int32
    let duration: TimeInterval
    let timestamp: Date
    
    var formattedResult: String {
        var result = "执行结果:\n```\n"
        if !output.isEmpty {
            result += output
        }
        if let error = error, !error.isEmpty {
            if !output.isEmpty {
                result += "\n"
            }
            result += "错误: \(error)"
        }
        result += "\n```"
        result += "\n退出码: \(exitCode), 耗时: \(String(format: "%.2f", duration))秒"
        return result
    }
}

// MARK: - 代码提取器

class CodeExtractor {
    // 支持两种格式：```language 和 ```run_language
    private let codeBlockPattern = #"```(?:run_)?(\w+)\n([\s\S]*?)```"#
    
    func extractAllCodeBlocks(from text: String) -> [CodeBlock] {
        var blocks: [CodeBlock] = []
        let lines = text.split(separator: "\n")
        var currentLine = 0
        
        print("CodeExtractor: 开始提取代码块")
        print("CodeExtractor: 文本长度: \(text.count)")
        
        do {
            let regex = try NSRegularExpression(pattern: codeBlockPattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            print("CodeExtractor: 找到 \(matches.count) 个匹配项")
            
            for match in matches {
                if let languageRange = Range(match.range(at: 1), in: text),
                   let contentRange = Range(match.range(at: 2), in: text) {
                    let languageStr = String(text[languageRange]).lowercased()
                    let content = String(text[contentRange])
                    
                    print("CodeExtractor: 找到语言: \(languageStr)")
                    
                    // 处理语言标识符，支持 python/bash/javascript/js/sh
                    let normalizedLang = languageStr
                        .replacingOccurrences(of: "run_", with: "")
                        .replacingOccurrences(of: "run", with: "")
                    
                    if let language = CodeLanguage(rawValue: normalizedLang) {
                        let lineNumber = text[..<text.index(text.startIndex, offsetBy: match.range.location)]
                            .filter { $0 == "\n" }.count + 1
                        blocks.append(CodeBlock(language: language, content: content, lineNumber: lineNumber))
                        print("CodeExtractor: 添加 \(language.displayName) 代码块")
                    } else {
                        print("CodeExtractor: 未识别的语言: \(languageStr)")
                    }
                }
            }
        } catch {
            print("CodeExtractor: 正则表达式错误: \(error)")
        }
        
        print("CodeExtractor: 总共提取到 \(blocks.count) 个代码块")
        return blocks
    }
}

// MARK: - 安全检查器

struct SafetyCheckResult {
    let isSafe: Bool
    let violations: [String]
}

class SafetyChecker {
    func checkSafety(code: String, language: CodeLanguage) -> SafetyCheckResult {
        // 移除所有安全检查，允许执行任何代码
        return SafetyCheckResult(isSafe: true, violations: [])
    }
}

// MARK: - 执行器协议

protocol CodeExecutor {
    func execute(code: String, timeout: TimeInterval) async -> ExecutionResult
}

// MARK: - 具体执行器实现

class PythonExecutor: CodeExecutor {
    func execute(code: String, timeout: TimeInterval) async -> ExecutionResult {
        // 处理代码，检查最后一行是否是变量名
        var processedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 分析最后一行
        let lines = processedCode.components(separatedBy: .newlines)
        if let lastLine = lines.last?.trimmingCharacters(in: .whitespaces),
           !lastLine.isEmpty,
           !lastLine.contains("="),  // 不是赋值语句
           !lastLine.hasPrefix("#"),  // 不是注释
           !lastLine.hasPrefix("print"),  // 不是print语句
           !lastLine.hasPrefix("return"),  // 不是return语句
           !lastLine.contains("("),  // 不是函数调用（简单判断）
           lastLine.rangeOfCharacter(from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))) != nil {
            // 看起来像是一个变量名，添加print
            processedCode = lines.dropLast().joined(separator: "\n") + "\nprint(\(lastLine))"
        }
        
        // 如果有conda环境，添加导入路径设置
        var finalCode = processedCode
        if CondaEnvironmentManager.shared.pythonPath != nil {
            // 在代码前添加matplotlib配置，避免GUI相关问题
            let setupCode = """
            import matplotlib
            matplotlib.use('Agg')  # 使用非GUI后端
            import warnings
            warnings.filterwarnings('ignore')
            
            """
            finalCode = setupCode + finalCode
        }
        
        return await executeProcess(
            executable: CodeLanguage.python.executable,
            arguments: ["-c", finalCode],
            timeout: timeout,
            language: .python,
            code: code
        )
    }
}

class BashExecutor: CodeExecutor {
    func execute(code: String, timeout: TimeInterval) async -> ExecutionResult {
        await executeProcess(
            executable: CodeLanguage.bash.executable,
            arguments: ["-c", code],
            timeout: timeout,
            language: .bash,
            code: code
        )
    }
}

class JavaScriptExecutor: CodeExecutor {
    func execute(code: String, timeout: TimeInterval) async -> ExecutionResult {
        await executeProcess(
            executable: CodeLanguage.javascript.executable,
            arguments: ["-e", code],
            timeout: timeout,
            language: .javascript,
            code: code
        )
    }
}

// MARK: - 通用进程执行

private func executeProcess(executable: String, arguments: [String], timeout: TimeInterval, language: CodeLanguage, code: String) async -> ExecutionResult {
    let startTime = Date()
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    
    // 使用完整的环境变量，不做限制
    process.environment = ProcessInfo.processInfo.environment
    
    do {
        try process.run()
        
        // 设置超时
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }
        
        process.waitUntilExit()
        timeoutTask.cancel()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return ExecutionResult(
            language: language,
            code: code,
            output: output.trimmingCharacters(in: .whitespacesAndNewlines),
            error: error.isEmpty ? nil : error.trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: process.terminationStatus,
            duration: Date().timeIntervalSince(startTime),
            timestamp: Date()
        )
        
    } catch {
        return ExecutionResult(
            language: language,
            code: code,
            output: "",
            error: "执行失败: \(error.localizedDescription)",
            exitCode: -1,
            duration: Date().timeIntervalSince(startTime),
            timestamp: Date()
        )
    }
}

// MARK: - Conda环境管理器

class CondaEnvironmentManager {
    static let shared = CondaEnvironmentManager()
    
    private let envName = "toast_talk_env"
    private var _pythonPath: String?
    
    var pythonPath: String? {
        if let cached = _pythonPath {
            return cached
        }
        
        // 尝试查找conda环境
        let condaBasePaths = [
            "~/anaconda3",
            "~/miniconda3",
            "~/opt/anaconda3",
            "~/opt/miniconda3",
            "/opt/anaconda3",
            "/opt/miniconda3",
            "/usr/local/anaconda3",
            "/usr/local/miniconda3"
        ]
        
        for basePath in condaBasePaths {
            let expandedPath = NSString(string: basePath).expandingTildeInPath
            let pythonPath = "\(expandedPath)/envs/\(envName)/bin/python"
            
            if FileManager.default.fileExists(atPath: pythonPath) {
                _pythonPath = pythonPath
                print("找到conda Python: \(pythonPath)")
                return pythonPath
            }
        }
        
        // 尝试读取配置文件
        let configPath = NSString(string: "~/Documents/toast_talk/toast_talk_conda_config.txt").expandingTildeInPath
        if let configData = try? String(contentsOfFile: configPath) {
            let lines = configData.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("PYTHON_PATH=") {
                    let path = String(line.dropFirst("PYTHON_PATH=".count))
                    if FileManager.default.fileExists(atPath: path) {
                        _pythonPath = path
                        return path
                    }
                }
            }
        }
        
        return nil
    }
    
    func setupEnvironment() -> String? {
        // 创建setup命令
        let setupScript = """
        #!/bin/bash
        source ~/.bashrc
        conda activate \(envName) 2>/dev/null || source activate \(envName) 2>/dev/null
        echo $CONDA_PREFIX/bin/python
        """
        
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", setupScript]
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                _pythonPath = output
                return output
            }
        } catch {
            print("无法设置conda环境: \(error)")
        }
        
        return nil
    }
}

// MARK: - 统一代码执行器

class UniversalCodeExecutor: ObservableObject {
    @Published var isExecuting = false
    @Published var requireConfirmation = false  // 默认关闭自动执行
    @Published var executionHistory: [ExecutionResult] = []
    
    private let extractor = CodeExtractor()
    private let safetyChecker = SafetyChecker()
    
    private let executors: [CodeLanguage: CodeExecutor] = [
        .python: PythonExecutor(),
        .bash: BashExecutor(),
        .sh: BashExecutor(),
        .javascript: JavaScriptExecutor(),
        .js: JavaScriptExecutor()
    ]
    
    func processLLMResponse(_ response: String) async -> [ExecutionResult] {
        print("UniversalCodeExecutor: 开始处理LLM响应")
        let codeBlocks = extractor.extractAllCodeBlocks(from: response)
        var results: [ExecutionResult] = []
        
        print("UniversalCodeExecutor: 准备执行 \(codeBlocks.count) 个代码块")
        
        for block in codeBlocks {
            print("UniversalCodeExecutor: 执行 \(block.language.displayName) 代码")
            if let result = await executeCodeBlock(block) {
                results.append(result)
                executionHistory.append(result)
                print("UniversalCodeExecutor: 执行完成，退出码: \(result.exitCode)")
                
                // 记录代码执行到日志
                LogManager.shared.logCodeExecution(
                    language: block.language.rawValue,
                    code: block.content,
                    result: result
                )
            }
        }
        
        print("UniversalCodeExecutor: 所有代码执行完成")
        return results
    }
    
    private func executeCodeBlock(_ block: CodeBlock) async -> ExecutionResult? {
        // 获取执行器
        guard let executor = executors[block.language] else {
            return ExecutionResult(
                language: block.language,
                code: block.content,
                output: "",
                error: "不支持的语言: \(block.language.rawValue)",
                exitCode: -1,
                duration: 0,
                timestamp: Date()
            )
        }
        
        // 执行代码
        isExecuting = true
        let result = await executor.execute(code: block.content, timeout: 30)
        isExecuting = false
        
        return result
    }
    
    func shouldRequestConfirmation(for language: CodeLanguage) -> Bool {
        return requireConfirmation
    }
}