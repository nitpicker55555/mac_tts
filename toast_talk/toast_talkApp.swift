//
//  toast_talkApp.swift
//  toast_talk
//
//  Created by puzhen on 02.09.25.
//

import SwiftUI

@main
struct toast_talkApp: App {
    var body: some Scene {
        WindowGroup {
            ImprovedStreamChatToastView()
                .customWindowStyle()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
