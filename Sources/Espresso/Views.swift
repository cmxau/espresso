import SwiftUI

/// Stand-in for @State: the @State macro needs full Xcode's SwiftUIMacros plugin, absent from CLT-only builds.
final class Box<T>: ObservableObject { @Published var v: T; init(_ v: T) { self.v = v } }

/// Rounded highlight on hover, used by every row.
struct Hoverable<C: View>: View {
    @StateObject private var hover = Box(false)
    let content: (Bool) -> C
    var body: some View {
        content(hover.v)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(hover.v ? 0.1 : 0)))
            .contentShape(Rectangle())
            .onHover { hover.v = $0 }
    }
}

// MARK: - Popover

struct MainView: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var awake = Awake.shared
    @StateObject private var durationOpen = Box(true)
    @StateObject private var settingsOpen = Box(false)
    let openAbout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider
            SectionHeader("Duration", open: durationOpen)
            if durationOpen.v { durations }
            divider
            SectionHeader("Settings", open: settingsOpen)
            if settingsOpen.v { settings }
            divider
            TextRow("About", action: openAbout)
            TextRow("Quit") { NSApp.terminate(nil) }
        }
        .padding(8)
        .frame(width: 300)
    }

    private var divider: some View { Divider().padding(.horizontal, 8).padding(.vertical, 4) }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Espresso").font(.system(size: 15, weight: .bold))
                Group {
                    if let end = awake.endDate { Text("Active until ") + Text(end, style: .time) }
                    else { Text(awake.isActive ? "Active until stopped" : "Not active") }
                }.font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { awake.isActive }, set: { $0 ? awake.start() : awake.stop() }))
                .toggleStyle(.switch).labelsHidden()
        }
        .padding(.horizontal, 8).padding(.bottom, 4)
    }

    private var durations: some View {
        let items: [(String, Duration?)] = [("15", .m15), ("30", .m30), ("45", .m45), ("", nil),
                                            ("01", .h1), ("04", .h4), ("08", .h8), ("", nil), ("∞", .infinite)]
        return HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                if i > 0 { Spacer(minLength: 0) }
                if let d = items[i].1 { chip(items[i].0, d) } else { dot }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }

    private var dot: some View { Circle().fill(Color.primary.opacity(0.35)).frame(width: 3, height: 3) }

    private func chip(_ t: String, _ d: Duration) -> some View {
        let on = awake.isActive && prefs.duration == d.rawValue
        return Button { awake.start(d) } label: {
            Text(t).font(.system(size: 14, weight: .semibold).width(.condensed))
                .foregroundStyle(on ? Color.white : Color.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(on ? Color.accentColor : Color.primary.opacity(0.12)))
        }.buttonStyle(.plain).help(d.label)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 2) {
            SettingRow("power", "Launch at Login", on: prefs.launchAtLogin) { prefs.launchAtLogin.toggle() }
            SettingRow("switch.2", "Activate at Launch", on: prefs.activateAtLaunch) { prefs.activateAtLaunch.toggle() }
            SettingRow("cursorarrow.click", "Activate with Left Click", on: prefs.leftClick) { prefs.leftClick.toggle() }
            HotkeyRow()
            SettingRow("circle.bottomhalf.filled", "Allow Display Sleep", on: prefs.displaySleep) {
                prefs.displaySleep.toggle(); awake.reapply()
            }
            SettingRow("laptopcomputer", "Keep Awake with Lid Closed", on: prefs.lidClosed) {
                prefs.lidClosed.toggle(); awake.reapply()
            }
            SettingRow("bell", "Allow Notifications", on: prefs.notifications) {
                prefs.notifications.toggle(); if prefs.notifications { Awake.requestNotifications() }
            }
            SettingRow("sparkles", "Animate Menu Bar Icon", on: prefs.animateIcon) { prefs.animateIcon.toggle() }
            SettingRow("paintpalette", "Colored Menu Bar Icon", on: prefs.coloredIcon) { prefs.coloredIcon.toggle() }
            if prefs.coloredIcon { swatches }
            SettingRow("bolt", "Activate on Power Connect", on: prefs.activateOnPower) { prefs.activateOnPower.toggle() }
            SettingRow("bolt.slash", "Deactivate on Power Disconnect", on: prefs.deactivateOnUnplug) { prefs.deactivateOnUnplug.toggle() }
            SettingRow("battery.25percent", "Deactivate When Below 20%", on: prefs.deactivateLow) { prefs.deactivateLow.toggle() }
        }
    }

    private var swatches: some View {
        HStack(spacing: 8) {
            ForEach(Swatch.allCases, id: \.self) { s in
                Circle().fill(Color(nsColor: s.color)).frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.primary, lineWidth: prefs.iconColor == s.rawValue ? 2 : 0).padding(-3))
                    .onTapGesture { prefs.iconColor = s.rawValue }
            }
            // Round rainbow button; the (invisible) system ColorPicker on top handles the click.
            Circle().fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center))
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.primary, lineWidth: prefs.iconColor == "custom" ? 2 : 0).padding(-3))
                .overlay(
                    ColorPicker("", selection: Binding(
                        get: { Color(nsColor: NSColor(hex: prefs.customColor)) },
                        set: { prefs.customColor = $0.hex; prefs.iconColor = "custom" }))
                        .labelsHidden().scaleEffect(2).opacity(0.02).clipShape(Circle()))
        }
        .padding(.leading, 44).padding(.vertical, 4)
    }
}

struct SectionHeader: View {
    let title: String
    @ObservedObject var open: Box<Bool>
    init(_ title: String, open: Box<Bool>) { self.title = title; self.open = open }
    var body: some View {
        Hoverable { _ in
            Button { open.v.toggle() } label: {
                HStack {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: open.v ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                }.padding(.horizontal, 10).padding(.vertical, 6).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
    }
}

struct TextRow: View {
    let title: String, action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    var body: some View {
        Hoverable { _ in
            Button(action: action) {
                HStack { Text(title).font(.system(size: 13)); Spacer() }
                    .padding(.horizontal, 10).padding(.vertical, 5).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
    }
}

/// Circle icon + label; the circle turns accent-blue when the option is on.
/// Optional trailing pill is its own button (e.g. to edit the keyboard shortcut).
struct SettingRow: View {
    let icon: String, title: String, on: Bool?, trailing: String?, trailingAction: (() -> Void)?, action: () -> Void
    init(_ icon: String, _ title: String, on: Bool? = nil, trailing: String? = nil,
         trailingAction: (() -> Void)? = nil, action: @escaping () -> Void) {
        self.icon = icon; self.title = title; self.on = on; self.trailing = trailing
        self.trailingAction = trailingAction; self.action = action
    }
    var body: some View {
        Hoverable { _ in
            HStack(spacing: 10) {
                Button(action: action) {
                    HStack(spacing: 10) {
                        Image(systemName: icon).font(.system(size: 13, weight: .medium))
                            .foregroundStyle(on == true ? Color.white : Color.primary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(on == true ? Color.accentColor : Color.primary.opacity(0.12)))
                        Text(title).font(.system(size: 13)).foregroundStyle(Color.primary.opacity(0.8))
                        Spacer()
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                if let trailing {
                    Button { trailingAction?() } label: {
                        Text(trailing).font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.12)))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 6).padding(.vertical, 2)
        }
    }
}

struct HotkeyRow: View {
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var mon = Box<Any?>(nil)
    var body: some View {
        SettingRow("command", "Keyboard Shortcut", on: prefs.hotkeyEnabled,
                   trailing: mon.v == nil ? prefs.hotkeyLabel : "Press keys…",
                   trailingAction: { mon.v == nil ? start() : stop() }) {
            prefs.hotkeyEnabled.toggle(); HotKey.shared.register()
        }
    }
    private func start() {
        mon.v = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 53 || HotKey.shared.set(from: e) { stop() }   // esc cancels
            return nil
        }
    }
    private func stop() {
        if let m = mon.v { NSEvent.removeMonitor(m) }
        mon.v = nil
    }
}

// MARK: - Windows (About / Welcome)

struct CapsuleButton: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label.font(.system(size: 14, weight: .medium)).foregroundStyle(.white).lineLimit(1).fixedSize()
            .padding(.horizontal, 16).frame(height: 34)
            .background(Capsule().fill(LinearGradient(colors: [Color(red: 0.2, green: 0.55, blue: 0.9), Color(red: 0.15, green: 0.4, blue: 0.82)], startPoint: .top, endPoint: .bottom)))
            .opacity(c.isPressed ? 0.8 : 1)
    }
}

struct CupShape: Shape {
    var steam: Bool
    func path(in rect: CGRect) -> Path {
        let s = rect.width / Cup.box.width
        let t = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: s, y: s)
            .translatedBy(x: -Cup.box.minX, y: -Cup.box.minY)
        var p = Path(Cup.body)
        p.addPath(Path(Cup.handle))
        if steam { p.addPath(Path(Cup.steam(nil))) }
        return p.applying(t)
    }
}

struct CupView: View {
    var width: CGFloat, steam = false, color: Color = .primary
    var body: some View {
        let s = width / Cup.box.width
        CupShape(steam: steam)
            .stroke(color, style: StrokeStyle(lineWidth: Cup.lineWidth * s, lineCap: .round, lineJoin: .round))
            .frame(width: width, height: Cup.box.height * s)
    }
}

/// App icon: blue cup on a pale tile.
struct AppIconView: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22).fill(Color(red: 0.94, green: 0.97, blue: 1))
            CupView(width: size * 0.62, steam: true, color: Color(red: 0.29, green: 0.52, blue: 0.9))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.2), radius: size * 0.04, y: size * 0.02)
    }
}

enum GitHubMark {
    static let image: NSImage? = {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>"#
        let i = NSImage(data: Data(svg.utf8))
        i?.isTemplate = true
        return i
    }()
}

struct AboutView: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var updater = Updater.shared
    private let repo = "https://github.com/cmxau/espresso"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 36) {
                AppIconView(size: 140)
                    .background(Circle().fill(Color.accentColor.opacity(0.25)).blur(radius: 50).scaleEffect(1.4))
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Espresso").font(.system(size: 32, weight: .bold))
                        Text("Version \(updater.current)").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Text("Keeps your Mac awake, right from the menu bar.").font(.system(size: 14))
                    HStack(spacing: 8) {
                        Link(destination: URL(string: "\(repo)/issues/new?template=feature_request.md")!) {
                            Label("Request a Feature", systemImage: "lightbulb")
                        }
                        Link(destination: URL(string: "\(repo)/issues/new?template=bug_report.md")!) {
                            Label("Report a Bug", systemImage: "ladybug")
                        }
                    }.buttonStyle(CapsuleButton())
                    updates
                }
            }
            .padding(.horizontal, 36).padding(.top, 40)
            Spacer(minLength: 16)
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Text("Designed and developed by").foregroundStyle(.secondary)
                    Link(destination: URL(string: "https://github.com/cmxau")!) {
                        HStack(spacing: 4) {
                            if let g = GitHubMark.image { Image(nsImage: g).resizable().frame(width: 13, height: 13) }
                            Text("cmxau").fontWeight(.semibold)
                        }
                    }
                }.font(.system(size: 12))
                Text("© 2026 cmxau. All rights reserved.").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 600, height: 440)
    }

    // MARK: Software update card

    private var isAvailable: Bool { updater.available != nil }
    private var isUpToDate: Bool { updater.status == "Espresso is up to date" }

    private var updates: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: isAvailable ? "arrow.down.circle.fill" : isUpToDate ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isAvailable ? Color.accentColor : isUpToDate ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Software Update").font(.system(size: 13, weight: .semibold))
                    Text(updater.status.isEmpty ? "Not checked yet" : updater.status)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(isAvailable ? "Install Update" : "Check Now") {
                    Task { isAvailable ? await updater.install() : await updater.check() }
                }.controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            Divider()
            switchRow("Check for updates automatically", $prefs.autoCheck)
            Divider()
            switchRow("Install updates automatically", $prefs.autoInstall)
        }
        .frame(width: 340)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func switchRow(_ title: String, _ value: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 12))
            Spacer()
            Toggle("", isOn: value).toggleStyle(.switch).controlSize(.mini).labelsHidden()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

struct WelcomeView: View {
    let close: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            AppIconView(size: 120).padding(.top, 24)
            Text("Welcome to Espresso").font(.system(size: 26, weight: .bold))
            Text("Espresso keeps your Mac awake.")
                .font(.system(size: 15)).multilineTextAlignment(.center).frame(width: 320)
            Button("Okay", action: close).buttonStyle(CapsuleButton()).padding(.top, 6)
        }
        .padding(.horizontal, 30).padding(.bottom, 20)
        .frame(width: 420)
    }
}
