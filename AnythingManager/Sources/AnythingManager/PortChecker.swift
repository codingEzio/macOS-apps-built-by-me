import Foundation

struct PortProcessInfo: Identifiable, Equatable {
    let pid: String
    let name: String
    let ppid: String?
    let parentName: String?
    var id: String { pid }
}

struct PortChecker {
    static func isPortInUse(_ port: Int) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-P", "-i", ":\(port)", "-sTCP:LISTEN"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return !data.isEmpty
        } catch {
            return false
        }
    }
    
    static func pidsUsingPort(_ port: Int) -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-ti", ":\(port)", "-sTCP:LISTEN"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let str = String(data: data, encoding: .utf8) else { return [] }
            return str.components(separatedBy: .newlines).filter { !$0.isEmpty }
        } catch {
            return []
        }
    }
    
    /// Returns process info for everything listening on the port, including parent info.
    static func processesOnPort(_ port: Int) -> [PortProcessInfo] {
        let pids = Set(pidsUsingPort(port))
        return pids.compactMap { pid in
            let name = processName(pid: pid)
            let ppid = parentPid(of: pid)
            let parentName = ppid.map { processName(pid: $0) }
            return PortProcessInfo(pid: pid, name: name, ppid: ppid, parentName: parentName)
        }
    }
    
    private static func processName(pid: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", pid, "-o", "comm="]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        } catch {
            return "unknown"
        }
    }
    
    private static func parentPid(of pid: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", pid, "-o", "ppid="]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let s = str, !s.isEmpty, s != "0", s != "1" else { return nil }
            return s
        } catch {
            return nil
        }
    }
    
    /// Known dev-server process name fragments. We ONLY kill processes whose
    /// names contain one of these — never system services, browsers, shells, etc.
    private static let safeToKillNames: [String] = [
        "node", "next", "bun", "npm", "pnpm", "yarn", "deno",
        "python", "python3", "ruby", "php", "go", "vite",
        "esbuild", "webpack", "rollup", "parcel", "turbo"
    ]
    
    private static func isSafeToKill(processName name: String) -> Bool {
        let lower = name.lowercased()
        // Use the base name (last path component) so /usr/local/bin/node → node.
        // Require exact match or a hyphen prefix (node-sass) to avoid substring
        // false positives like "anodeb" or "monodevelop" matching "node".
        let baseName = lower.split(separator: "/").last.map(String.init) ?? lower
        return safeToKillNames.contains { safe in
            baseName == safe || baseName.hasPrefix("\(safe)-")
        } || lower.hasSuffix("-server")
    }
    
    /// Kills the PIDs that hold the port AND their parent PIDs — but ONLY if
    /// both the listener and the parent look like dev-server processes.
    /// Next.js spawns a child next-server that holds the port; killing only the
    /// child lets the parent respawn it. We kill both so the server dies for real.
    static func killPort(_ port: Int) {
        let pids = Set(pidsUsingPort(port))
        var allPids = Set<String>()
        for pidStr in pids {
            let name = processName(pid: pidStr)
            guard isSafeToKill(processName: name) else {
                print("[AnythingManager] Refusing to kill unknown process '\(name)' (PID \(pidStr)) on port \(port)")
                continue
            }
            allPids.insert(pidStr)
            if let ppid = parentPid(of: pidStr) {
                let parentName = processName(pid: ppid)
                // Only kill parent if it's ALSO a dev process — never kill
                // shells, Terminal, launchd, or system services.
                if isSafeToKill(processName: parentName) {
                    allPids.insert(ppid)
                }
            }
        }
        for pidStr in allPids {
            if let pid = Int32(pidStr) {
                kill(pid, 9)
            }
        }
    }
    
    static func waitForPortRelease(_ port: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isPortInUse(port) { return true }
            usleep(200_000) // 200 ms
        }
        return !isPortInUse(port)
    }
}
