import Foundation

struct PortProcessInfo: Identifiable {
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
    
    /// Kills the PIDs that hold the port AND their parent PIDs.
    /// Next.js spawns a child next-server that holds the port; killing only the child
    /// lets the parent respawn it. We kill both so the server dies for real.
    static func killPort(_ port: Int) {
        let pids = Set(pidsUsingPort(port))
        var allPids = pids
        for pidStr in pids {
            if let ppid = parentPid(of: pidStr) {
                allPids.insert(ppid)
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
