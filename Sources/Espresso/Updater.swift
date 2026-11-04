import AppKit

/// Checks GitHub Releases (cmxau/espresso) for a newer .zip containing Espresso.app.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()
    @Published var status = ""
    @Published var available: URL?

    let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    private struct Release: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: String; let size: Int }
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

    // MARK: Trust limits. Ad-hoc signing means nothing here is cryptographic authentication; these narrow the attack surface.

    nonisolated private static let bundleID = "com.cmxau.espresso"
    private static let maxJSON = 1 << 20, maxZip = 50 << 20

    /// https only, GitHub hosts only (release downloads redirect to *.githubusercontent.com).
    nonisolated static func allowed(_ url: URL?) -> Bool {
        guard let url, url.scheme == "https", url.user == nil, url.port == nil, let h = url.host?.lowercased() else { return false }
        return h == "github.com" || h.hasSuffix(".githubusercontent.com")
    }

    /// Refuses redirects that leave the allowlist (or downgrade to http).
    private final class RedirectGuard: NSObject, URLSessionTaskDelegate {
        func urlSession(_ s: URLSession, task: URLSessionTask, willPerformHTTPRedirection r: HTTPURLResponse,
                        newRequest req: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(Updater.allowed(req.url) ? req : nil)
        }
    }

    private func fail(_ why: String) -> Error { NSError(domain: "Updater", code: 1, userInfo: [NSLocalizedDescriptionKey: why]) }

    func check() async {
        status = "Checking for updates…"
        do {
            let url = URL(string: "https://api.github.com/repos/cmxau/espresso/releases/latest")!
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200, data.count <= Updater.maxJSON else { throw fail("bad response") }
            let rel = try JSONDecoder().decode(Release.self, from: data)
            let v = rel.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard v.range(of: "^[0-9]+(\\.[0-9]+){0,3}$", options: .regularExpression) != nil else { throw fail("bad tag") }
            guard v.compare(current, options: .numeric) == .orderedDescending,
                  let a = rel.assets.first(where: { $0.name.hasSuffix(".zip") }),
                  let dl = URL(string: a.browser_download_url) else { status = "Espresso is up to date"; available = nil; return }
            guard Updater.allowed(dl), dl.path.hasPrefix("/cmxau/espresso/releases/download/"), a.size <= Updater.maxZip
            else { throw fail("untrusted asset") }
            available = dl
            status = "Version \(v) is available"
            if Prefs.shared.autoInstall { await install() }
        } catch { status = "Couldn't check for updates" }
    }

    func install() async {
        guard let url = available, Updater.allowed(url) else { return }
        status = "Downloading update…"
        do {
            let (tmp, resp) = try await URLSession.shared.download(from: url, delegate: RedirectGuard())
            guard (resp as? HTTPURLResponse)?.statusCode == 200, Updater.allowed(resp.url),
                  ((try? FileManager.default.attributesOfItem(atPath: tmp.path)[.size] as? Int) ?? .max) <= Updater.maxZip
            else { throw fail("bad download") }
            let current = self.current
            let new = try await Task.detached { try Updater.stageAndVerify(tmp, currentVersion: current) }.value
            let dest = Bundle.main.bundlePath
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            // Constant script; paths arrive as $1..$3, never as script text. Old app is moved aside, restored on failure.
            p.arguments = ["-c", """
                while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.3; done
                if /bin/mv "$3" "$3.old"; then
                  if ! /bin/mv "$2" "$3"; then /bin/rm -rf "$3"; /bin/mv "$3.old" "$3"; else /bin/rm -rf "$3.old"; fi
                fi
                exec /usr/bin/open "$3"
                """, "sh", String(getpid()), new.path, dest]
            try p.run()
            NSApp.terminate(nil)
        } catch { status = "Update failed. Please try again." }
    }

    /// Unzips into a fresh 0700 dir and returns the verified Espresso.app inside it, or throws.
    nonisolated private static func stageAndVerify(_ zip: URL, currentVersion: String) throws -> URL {
        let fm = FileManager.default
        func bad(_ m: String) -> Error { NSError(domain: "Updater", code: 2, userInfo: [NSLocalizedDescriptionKey: m]) }
        func run(_ exe: String, _ args: [String]) throws -> (Int32, String) {
            let p = Process(), out = Pipe()
            p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
            p.standardOutput = out; p.standardError = FileHandle.nullDevice
            try p.run()
            let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            p.waitUntilExit()
            return (p.terminationStatus, text)
        }
        let dir = fm.temporaryDirectory.appendingPathComponent("espresso-" + UUID().uuidString)
        try fm.createDirectory(at: dir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let src = dir.appendingPathComponent("u.zip"), out = dir.appendingPathComponent("x")
        try fm.moveItem(at: zip, to: src)
        // Reject absolute / ".." entry names and zip bombs before extracting.
        let (ls, list) = try run("/usr/bin/zipinfo", ["-1", src.path])
        let names = list.split(separator: "\n").map(String.init)
        guard ls == 0, !names.isEmpty, names.count < 5000,
              names.allSatisfy({ !$0.hasPrefix("/") && !$0.split(separator: "/").contains("..") && ($0 == "Espresso.app" || $0.hasPrefix("Espresso.app/")) })
        else { throw bad("unsafe archive") }
        guard try run("/usr/bin/ditto", ["-x", "-k", src.path, out.path]).0 == 0 else { throw bad("unzip failed") }
        // No symlinks anywhere; everything must resolve inside the extraction dir.
        let root = out.resolvingSymlinksInPath().path + "/"
        for case let u as URL in fm.enumerator(at: out, includingPropertiesForKeys: [.isSymbolicLinkKey])! {
            guard (try u.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
                  (u.resolvingSymlinksInPath().path + "/").hasPrefix(root) else { throw bad("symlink in archive") }
        }
        let app = out.appendingPathComponent("Espresso.app")
        guard let info = Bundle(url: app)?.infoDictionary,
              info["CFBundleIdentifier"] as? String == bundleID,
              let v = info["CFBundleShortVersionString"] as? String,
              v.compare(currentVersion, options: .numeric) == .orderedDescending,
              let exe = info["CFBundleExecutable"] as? String, exe == "Espresso",
              fm.isExecutableFile(atPath: app.appendingPathComponent("Contents/MacOS/" + exe).path)
        else { throw bad("wrong bundle") }
        guard try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]).0 == 0 else { throw bad("bad signature") }
        return app
    }
}
