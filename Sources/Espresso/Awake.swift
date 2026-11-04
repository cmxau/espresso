import AppKit
import IOKit.pwr_mgt
import UserNotifications

/// Owns the sleep assertions. No polling: one assertion set + one single-shot timer.
final class Awake: ObservableObject {
    static let shared = Awake()
    @Published private(set) var isActive = false
    @Published private(set) var endDate: Date?

    private let prefs = Prefs.shared
    private var ids: [IOPMAssertionID] = []
    private var timer: Timer?
    private var lidOn = false

    func toggle() { isActive ? stop() : start() }

    func start(_ d: Duration? = nil) {
        let d = d ?? Duration(rawValue: prefs.duration) ?? .infinite
        prefs.duration = d.rawValue
        timer?.invalidate()
        endDate = d.seconds.map { Date().addingTimeInterval($0) }
        if let end = endDate {
            timer = Timer.scheduledTimer(withTimeInterval: end.timeIntervalSinceNow, repeats: false) { [weak self] _ in
                self?.stop(reason: "Time's up")
            }
            timer?.tolerance = 1
        }
        isActive = true
        reapply()
    }

    func stop(reason: String? = nil) {
        timer?.invalidate()
        endDate = nil
        isActive = false
        reapply()
        if let reason { notify(reason) }
    }

    /// Re-syncs assertions + lid mode with current state/prefs.
    func reapply() {
        ids.forEach { IOPMAssertionRelease($0) }
        ids = []
        if isActive {
            var types = [kIOPMAssertionTypePreventUserIdleSystemSleep]
            if !prefs.displaySleep { types.append(kIOPMAssertionTypePreventUserIdleDisplaySleep) }
            for t in types {
                var id = IOPMAssertionID(0)
                if IOPMAssertionCreateWithName(t as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                               "Espresso" as CFString, &id) == kIOReturnSuccess { ids.append(id) }
            }
        }
        let wantLid = isActive && prefs.lidClosed
        if wantLid != lidOn {
            if pmset(disableSleep: wantLid) { lidOn = wantLid }
            else if wantLid { prefs.lidClosed = false }   // user declined admin setup
        }
    }

    /// Lid-closed awake needs `pmset disablesleep` (root). The first use asks for the admin password once to
    /// install a narrow sudoers rule (/etc/sudoers.d/espresso) allowing only that command; after that it's silent.
    private func pmset(disableSleep on: Bool) -> Bool {
        sudoPmset(on) || (installSudoers() && sudoPmset(on))
    }

    private func sudoPmset(_ on: Bool) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    /// The sudoers line for `user`, or nil unless it is a plain POSIX login name (keeps newlines, quotes, spaces,
    /// commas and `#`/`%`/`!` prefixes out of the rule and out of the shell script below).
    static func sudoersRule(user: String) -> String? {
        guard user.range(of: "^[A-Za-z_][A-Za-z0-9_.-]{0,31}\\z", options: .regularExpression) != nil else { return nil }
        return "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
    }

    /// Runs as root via one admin prompt. Everything (private mktemp dir, file contents, visudo check, install) happens
    /// inside the root script, so no user-writable file is ever trusted by root and there is nothing to race.
    private func installSudoers() -> Bool {
        guard let rule = Awake.sudoersRule(user: NSUserName()) else { return false }   // validated: safe inside '…'
        let sh = "set -e; T=$(/usr/bin/mktemp -d); trap '/bin/rm -rf \"$T\"' EXIT; "
            + "/usr/bin/printf '%s\\n' '\(rule)' > \"$T/r\"; /usr/sbin/visudo -cf \"$T/r\"; "
            + "/usr/bin/install -m 440 -o root -g wheel \"$T/r\" /etc/sudoers.d/espresso"
        let escaped = sh.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var err: NSDictionary?
        NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?.executeAndReturnError(&err)
        return err == nil
    }

    func notify(_ text: String) {
        guard prefs.notifications else { return }
        let c = UNMutableNotificationContent()
        c.title = "espresso"
        c.body = text
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    static func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
