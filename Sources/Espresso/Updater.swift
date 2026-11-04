import AppKit

/// Checks GitHub Releases (cmxau/espresso) for a newer .zip containing Espresso.app.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()
    @Published var status = ""
    @Published var available: URL?

    let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    private struct Release: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: String }
        let tag_name: String
        let assets: [Asset]
    }

    /// Check shortly after launch, then once a day (timer is coalesced by the OS via tolerance).
    func schedule() {
        Task { try? await Task.sleep(for: .seconds(10)); await autoCheck() }
        let t = Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { _ in Task { @MainActor in await Updater.shared.autoCheck() } }
        t.tolerance = 3600
    }

    private func autoCheck() async { if Prefs.shared.autoCheck { await check() } }

    func check() async {
        status = "Checking for updates…"
        do {
            let url = URL(string: "https://api.github.com/repos/cmxau/espresso/releases/latest")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let rel = try JSONDecoder().decode(Release.self, from: data)
            let v = rel.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard v.compare(current, options: .numeric) == .orderedDescending,
                  let a = rel.assets.first(where: { $0.name.hasSuffix(".zip") }),
                  let dl = URL(string: a.browser_download_url) else { status = "Espresso is up to date"; available = nil; return }
            available = dl
            status = "Version \(v) is available"
            if Prefs.shared.autoInstall { await install() }
        } catch { status = "Couldn't check for updates" }
    }

    func install() async {
        guard let url = available else { return }
        status = "Downloading update…"
        do {
            let (tmp, _) = try await URLSession.shared.download(from: url)
            let fm = FileManager.default
            let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let zip = dir.appendingPathComponent("u.zip")
            try fm.moveItem(at: tmp, to: zip)
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments = ["-x", "-k", zip.path, dir.path]
            try unzip.run(); unzip.waitUntilExit()
            let new = dir.appendingPathComponent("Espresso.app").path
            guard fm.fileExists(atPath: new) else { throw URLError(.cannotDecodeContentData) }
            let dest = Bundle.main.bundlePath
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            p.arguments = ["-c", "while kill -0 \(getpid()) 2>/dev/null; do sleep 0.3; done; rm -rf '\(dest)'; mv '\(new)' '\(dest)'; open '\(dest)'"]
            try p.run()
            NSApp.terminate(nil)
        } catch { status = "Update failed. Please try again." }
    }
}
