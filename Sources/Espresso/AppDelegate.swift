import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panel = PanelController()
    private let prefs = Prefs.shared
    private let awake = Awake.shared
    private var bag = Set<AnyCancellable>()
    private var anim: Timer?
    private var phase: CGFloat = 0
    private var power: PowerMonitor?

    func applicationDidFinishLaunching(_ n: Notification) {
        item.button?.target = self
        item.button?.action = #selector(click)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        Publishers.Merge(prefs.objectWillChange, awake.objectWillChange)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.refresh() }.store(in: &bag)

        HotKey.shared.handler = { Awake.shared.toggle() }
        HotKey.shared.register()
        power = PowerMonitor()
        if prefs.activateAtLaunch { awake.start() }
        refresh()
        if prefs.showWelcome { Windows.welcome(); prefs.showWelcome = false }   // first launch only
        Task { @MainActor in Updater.shared.schedule() }
    }

    func applicationWillTerminate(_ n: Notification) { awake.stop() }   // also restores lid-closed mode

    @objc private func click() {
        let right = NSApp.currentEvent?.type == .rightMouseUp
        if prefs.leftClick && !right { awake.toggle() } else { togglePopover() }
    }

    private func togglePopover() {
        guard let b = item.button else { return }
        panel.toggle(from: b) { Windows.about() }
    }

    /// Redraws the icon; the 2 fps animation timer only runs while active + animate is on.
    private func refresh() {
        let steam: CGFloat? = awake.isActive ? phase : nil
        item.button?.image = Icon.image(steam: steam, color: awake.isActive ? prefs.tint : nil)
        if awake.isActive && prefs.animateIcon {
            if anim == nil {
                anim = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    guard let self else { return }; self.phase = self.phase >= 5.2 ? 0 : self.phase + 1.05; self.refresh()
                }
                anim?.tolerance = 0.2
            }
        } else { anim?.invalidate(); anim = nil; phase = 0 }
    }
}
