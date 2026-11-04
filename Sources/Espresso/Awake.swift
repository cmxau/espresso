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

    private func installSudoers() -> Bool {
        let rule = "\(NSUserName()) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
        let sh = "echo '\(rule)' > /private/tmp/espresso.sudoers && /usr/sbin/visudo -cf /private/tmp/espresso.sudoers && /usr/bin/install -m 440 -o root -g wheel /private/tmp/espresso.sudoers /etc/sudoers.d/espresso; rm -f /private/tmp/espresso.sudoers"
        var err: NSDictionary?
        NSAppleScript(source: "do shell script \"\(sh)\" with administrator privileges")?.executeAndReturnError(&err)
        return err == nil
    }

    private func notify(_ text: String) {
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
