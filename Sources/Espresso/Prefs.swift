import SwiftUI
import ServiceManagement

enum Swatch: String, CaseIterable {
    case blue, pink, red, orange, yellow, green, grey
    var color: NSColor {
        switch self {
        case .blue: .systemBlue
        case .pink: .systemPink
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .grey: .systemGray
        }
    }
}

enum Duration: Int {
    case infinite = 0, m15 = 900, m30 = 1800, m45 = 2700, h1 = 3600, h4 = 14400, h8 = 28800
    var seconds: TimeInterval? { self == .infinite ? nil : TimeInterval(rawValue) }
    var label: String {
        switch self {
        case .infinite: "Infinite"
        case .m15, .m30, .m45: "\(rawValue / 60) minutes"
        case .h1: "1 hour"
        case .h4, .h8: "\(rawValue / 3600) hours"
        }
    }
}

final class Prefs: ObservableObject {
    static let shared = Prefs()

    @AppStorage("duration") var duration = Duration.infinite.rawValue
    @AppStorage("activateAtLaunch") var activateAtLaunch = false
    @AppStorage("leftClick") var leftClick = false
    @AppStorage("hotkeyEnabled") var hotkeyEnabled = false
    @AppStorage("hotkeyKey") var hotkeyKey = 8            // "C"
    @AppStorage("hotkeyMods") var hotkeyMods = 4096 | 2048 | 256   // ctrl+opt+cmd
    @AppStorage("hotkeyLabel") var hotkeyLabel = "⌃⌥⌘C"
    @AppStorage("displaySleep") var displaySleep = false
    @AppStorage("lidClosed") var lidClosed = false
    @AppStorage("notifications") var notifications = false
    @AppStorage("animateIcon") var animateIcon = false
    @AppStorage("coloredIcon") var coloredIcon = false
    @AppStorage("iconColor") var iconColor = "blue"       // swatch name or "custom"
    @AppStorage("customColor") var customColor = "#FF8800"
    @AppStorage("activateOnPower") var activateOnPower = false
    @AppStorage("deactivateOnUnplug") var deactivateOnUnplug = false
    @AppStorage("deactivateLow") var deactivateLow = false
    @AppStorage("autoCheck") var autoCheck = true
    @AppStorage("autoInstall") var autoInstall = false
    @AppStorage("showWelcome") var showWelcome = true

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }

    var tint: NSColor? {
        guard coloredIcon else { return nil }
        return Swatch(rawValue: iconColor)?.color ?? NSColor(hex: customColor)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let v = Int(hex.dropFirst(), radix: 16) ?? 0xFF8800
        self.init(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255,
                  blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}

extension Color {
    var hex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .orange
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}
