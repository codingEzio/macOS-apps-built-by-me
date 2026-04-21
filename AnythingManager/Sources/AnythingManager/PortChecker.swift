import Foundation

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
    
    /// Kills a PID and all of its descendant processes recursively.
    static func killTree(pid: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "pgrep -P \(pid)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8) {
                for child in str.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
                    if let childPid = Int32(child) {
                        killTree(pid: childPid)
                    }
                }
            }
        } catch {
            // ignore
        }
        kill(pid, 9)
    }
    
    static func killPort(_ port: Int) {
        for pidStr in pidsUsingPort(port) {
            if let pid = Int32(pidStr) {
                killTree(pid: pid)
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
