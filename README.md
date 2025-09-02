# Toast Talk - AI 语音对话助手

一个基于 macOS 的实时语音对话应用，使用 OpenAI GPT-4o 和苹果原生语音识别技术。

## 功能特点

- 🎙️ 实时中文语音转文字（流式输出）
- 🤖 OpenAI GPT-4o 智能对话（流式响应）
- 🔊 多种中文语音选择（系统自带）
- 🎨 优雅的 Toast 风格界面
- ⚡ 自动检测说话结束
- 🎵 可调节语速和音量

## 配置说明

1. **创建配置文件**
   在 `toast_talk` 文件夹中创建 `Config.swift`：
   ```swift
   import Foundation

   struct Config {
       // OpenAI API 配置
       static let openAIAPIKey = "你的-API-密钥"
       static let openAIModel = "gpt-4o"
       
       // 其他配置项
       static let speechRecognitionLocale = "zh-CN"
       static let defaultSpeechRate: Float = 0.5
       static let silenceThreshold: TimeInterval = 1.5
   }
   ```

2. **添加到 Xcode 项目**
   - 右键点击 Xcode 中的 `toast_talk` 文件夹
   - 选择 "Add Files to toast_talk..."
   - 选择 `Config.swift` 并添加

3. **确保安全**
   `Config.swift` 已添加到 `.gitignore`，不会被提交到版本控制

## 系统要求

- macOS 13.0+
- Xcode 14.0+
- OpenAI API 密钥

## 使用方法

1. 打开项目并配置 API 密钥
2. 在 Xcode 中运行项目
3. 点击"说话"按钮开始录音
4. 说完后停顿 1.5 秒会自动停止
5. AI 会流式返回回复并语音播放

## 语音设置

点击扬声器图标可以：
- 选择不同的中文语音（婷婷、雨舒、甜甜等）
- 调节语速（0.1-1.0）
- 调节音量（0.1-1.0）

## 隐私权限

应用需要以下权限：
- 麦克风：用于语音输入
- 语音识别：用于语音转文字
- 网络：用于调用 OpenAI API