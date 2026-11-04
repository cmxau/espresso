import AppKit
import SwiftUI

/// Standalone About / Welcome windows (kept alive only while open).
enum Windows {
    private static var open: [String: NSWindow] = [:]

    static func about() { show("about", AboutView()) }
    static func welcome() { show("welcome", WelcomeView { open["welcome"]?.close() }) }

    private static func show<V: View>(_ id: String, _ view: V) {
        if let w = open[id] { w.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let host = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: host)
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { _ in open[id] = nil }
        open[id] = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
