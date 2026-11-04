import AppKit
import SwiftUI
import Combine

private final class MenuPanel: NSPanel {
    var onResign: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func resignKey() { super.resignKey(); onResign?() }
    override func cancelOperation(_ sender: Any?) { onResign?() }   // Esc
}

/// Borderless, arrow-less panel that drops under the menu bar like the system Wi-Fi / Control Center panels.
final class PanelController {
    private var panel: MenuPanel?
    private var host: NSHostingController<MainView>?
    private var sizeSub: AnyCancellable?
    private var button: NSStatusBarButton?
    private var swallowNextToggle = false

    func toggle(from button: NSStatusBarButton, openAbout: @escaping () -> Void) {
        if panel != nil { close(); return }
        if swallowNextToggle { swallowNextToggle = false; return }   // click that just dismissed us via resignKey
        show(from: button, openAbout: openAbout)
    }

    func close() {
        sizeSub = nil
        panel?.orderOut(nil)
        panel = nil; host = nil
        button?.isHighlighted = false
    }

    private func show(from button: NSStatusBarButton, openAbout: @escaping () -> Void) {
        self.button = button
        let host = NSHostingController(rootView: MainView { [weak self] in self?.close(); openAbout() })
        host.sizingOptions = .preferredContentSize

        let fx = NSVisualEffectView()
        fx.material = .menu
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 14
        fx.layer?.cornerCurve = .continuous
        fx.layer?.masksToBounds = true
        fx.layer?.borderWidth = 0.5
        fx.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        host.view.translatesAutoresizingMaskIntoConstraints = false
        fx.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: fx.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: fx.topAnchor), host.view.bottomAnchor.constraint(equalTo: fx.bottomAnchor)])

        let size = host.view.fittingSize
        let p = MenuPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        p.contentView = fx
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .transient]
        p.onResign = { [weak self] in self?.resigned() }

        // Place just below the status item, centered on it, kept on screen.
        if let win = button.window {
            let r = win.convertToScreen(button.convert(button.bounds, to: nil))
            let vis = (win.screen ?? NSScreen.main)?.visibleFrame ?? .zero
            let x = min(max(r.midX - size.width / 2, vis.minX + 8), vis.maxX - size.width - 8)
            p.setFrameOrigin(NSPoint(x: x, y: r.minY - 6 - size.height))
        }
        self.panel = p; self.host = host
        button.isHighlighted = true
        sizeSub = host.publisher(for: \.preferredContentSize).sink { [weak self] s in self?.resize(s) }
        p.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Keep the top edge fixed while Duration / Settings expand or collapse.
    private func resize(_ s: NSSize) {
        guard let p = panel, s.height > 0, s != p.frame.size else { return }
        var f = p.frame
        f.origin.y = f.maxY - s.height
        f.size = s
        p.setFrame(f, display: true, animate: true)
    }

    private func resigned() {
        // Color panel / hotkey recorder may take key briefly; only close if we're really being dismissed.
        DispatchQueue.main.async { [weak self] in
            guard let self, let p = self.panel, !p.isKeyWindow, !(NSApp.keyWindow is NSColorPanel) else { return }
            if let b = self.button, let w = b.window, w.convertToScreen(b.convert(b.bounds, to: nil)).contains(NSEvent.mouseLocation) {
                self.swallowNextToggle = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.swallowNextToggle = false }
            }
            self.close()
        }
    }
}
