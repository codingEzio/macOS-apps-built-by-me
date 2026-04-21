import Foundation

struct PortProcessInfo: Identifiable {
    let pid: String
    let name: String
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
        task.arguments = ["-ti", ":\(port)"]
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
    
    /// Returns a list of (pid, process-name) tuples for everything listening on the port.
    static func processesOnPort(_ port: Int) -> [PortProcessInfo] {
        let pids = Set(pidsUsingPort(port)) // deduplicate IPv4/IPv6 duplicates
        return pids.compactMap { pid in
            let name = processName(pid: pid)
            return PortProcessInfo(pid: pid, name: name)
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
    
    /// Kills ONLY the exact PIDs returned by lsof for this port.
    /// No recursive tree walking — we only touch processes that actually hold the port.
    static func killPort(_ port: Int) {
        let uniquePids = Set(pidsUsingPort(port))
        for pidStr in uniquePids {
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
