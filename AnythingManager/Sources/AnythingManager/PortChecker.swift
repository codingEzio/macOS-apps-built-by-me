import Foundation

struct PortChecker {
    /// Checks whether anything is listening on the given port.
    /// Uses lsof with the -sTCP:LISTEN flag to avoid matching outgoing connections.
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
    
    static func killPort(_ port: Int) {
        for pid in pidsUsingPort(port) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/kill")
            task.arguments = ["-9", pid]
            try? task.run()
        }
    }
    
    static func waitForPortRelease(_ port: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isPortInUse(port) { return true }
            usleep(100_000)
        }
        return !isPortInUse(port)
    }
}
