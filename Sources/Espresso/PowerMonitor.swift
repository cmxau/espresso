import Foundation
import IOKit.ps

/// Event-driven (run-loop source), no polling.
final class PowerMonitor {
    private let prefs = Prefs.shared
    private let awake = Awake.shared
    private var wasAC = PowerMonitor.read().ac

    init() {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let src = IOPSNotificationCreateRunLoopSource({ ctx in
            Unmanaged<PowerMonitor>.fromOpaque(ctx!).takeUnretainedValue().changed()
        }, ctx).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
    }

    static func read() -> (ac: Bool, pct: Int?) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return (true, nil) }
        let ac = (IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?) == kIOPSACPowerValue
        var pct: Int?
        for ps in list {
            if let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
               let c = d[kIOPSCurrentCapacityKey] as? Int { pct = c }
        }
        return (ac, pct)
    }

    private func changed() {
        let (ac, pct) = Self.read()
        defer { wasAC = ac }
        if ac, !wasAC, prefs.activateOnPower, !awake.isActive { awake.start() }
        else if !ac, wasAC, prefs.deactivateOnUnplug, awake.isActive { awake.stop(reason: "Power disconnected") }
        else if !ac, prefs.deactivateLow, awake.isActive, let pct, pct < 20 { awake.stop(reason: "Battery below 20%") }
    }
}
