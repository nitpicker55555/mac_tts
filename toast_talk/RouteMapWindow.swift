//
//  RouteMapWindow.swift
//  toast_talk
//
//  Created by Assistant on 2025-09-04.
//

import SwiftUI
import AppKit

// MARK: - 路线地图窗口控制器

class RouteMapWindowController {
    static let shared = RouteMapWindowController()
    private var window: NSWindow?
    
    func showRouteMap(journeys: [[String: Any]], initialSelectedIndex: Int = 0) {
        // 如果窗口已经存在，只需显示并聚焦
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // 更新窗口内容
            let contentView = EnhancedMapRouteView(
                journeys: journeys,
                initialSelectedIndex: initialSelectedIndex
            )
            existingWindow.contentView = NSHostingView(rootView: contentView)
            return
        }
        
        // 创建新窗口
        let contentView = EnhancedMapRouteView(
            journeys: journeys,
            initialSelectedIndex: initialSelectedIndex
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "路线规划"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("RouteMapWindow")
        window.isReleasedWhenClosed = false
        
        // 设置最小窗口大小
        window.minSize = NSSize(width: 800, height: 600)
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保存窗口引用
        self.window = window
    }
    
    func closeWindow() {
        window?.close()
        window = nil
    }
}

// MARK: - 便利扩展

extension View {
    func openRouteMapWindow(journeys: [[String: Any]], initialSelectedIndex: Int = 0) {
        RouteMapWindowController.shared.showRouteMap(
            journeys: journeys,
            initialSelectedIndex: initialSelectedIndex
        )
    }
}