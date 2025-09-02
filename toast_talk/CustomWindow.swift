//
//  CustomWindow.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI
import AppKit

class CustomWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: backingStoreType,
            defer: flag
        )
        
        // 设置窗口属性
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        
        // 设置圆角
        self.appearance = NSAppearance(named: .darkAqua)
    }
}

struct CustomWindowView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            if let window = view.window {
                // 设置窗口为自定义样式
                window.styleMask = [.borderless, .fullSizeContentView]
                window.isOpaque = false
                window.backgroundColor = .clear
                window.level = .floating
                window.hasShadow = true
                window.isMovableByWindowBackground = true
                
                // 设置初始位置（屏幕右上角）
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    let windowWidth: CGFloat = 350
                    let windowHeight: CGFloat = 300
                    let padding: CGFloat = 20
                    
                    let xPos = screenFrame.maxX - windowWidth - padding
                    let yPos = screenFrame.maxY - windowHeight - padding
                    
                    window.setFrame(
                        NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
                        display: true
                    )
                }
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// 自定义窗口样式修饰符
struct CustomWindowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(CustomWindowView())
    }
}

extension View {
    func customWindowStyle() -> some View {
        self.modifier(CustomWindowStyle())
    }
}