import Foundation
import Combine

@MainActor
class ProcessManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var logs: [UUID: String] = [:]
    @Published var errors: [UUID: String] = [:]
    @Published var externalRunning: Set<UUID> = []
    @Published var startingProjects: Set<UUID> = []
    @Published var configURL: URL?
    @Published var configMissing: Bool = false
    
    private var processes: [UUID: Process] = [:]
    private var scanTimer: Timer?
    
    init() {
        configURL = Self.resolveConfigURL()
        
        if let url = configURL, FileManager.default.fileExists(atPath: url.path) {
            loadProjects()
        } else if let url = configURL {
            // File does not exist yet — try one-time migration from UserDefaults,
            // then fall back to sample or placeholder.
            if migrateFromUserDefaults(to: url) {
                // migrated
            } else if let sampleURL = Self.resolveSampleConfigURL() {
                do {
                    let data = try Data(contentsOf: sampleURL)
                    try data.write(to: url)
                    loadProjects()
                } catch {
                    projects = [Project.placeholder()]
                    saveProjects()
                }
            } else {
                projects = [Project.placeholder()]
                saveProjects()
            }
        } else {
            configMissing = true
        }
        
        if projects.isEmpty && !configMissing {
            projects = [Project.placeholder()]
            saveProjects()
        }
        
        scanExternalProcesses()
        startPeriodicScan()
    }
    
    /// One-time migration from the old UserDefaults storage to the new file-based config.
    /// Reads the bundled-app plist directly so migration works regardless of how the
    /// binary is launched (swift run vs .app bundle).
    private func migrateFromUserDefaults(to url: URL) -> Bool {
        let plistPath = NSString(string: "~/Library/Preferences/com.user.AnythingManager.plist")
            .expandingTildeInPath
        
        var data: Data?
        
        // 1. Try the bundled-app plist directly
        if let plist = NSDictionary(contentsOfFile: plistPath),
           let raw = plist["anything_manager_projects"] {
            if let d = raw as? Data {
                data = d
            } else if let s = raw as? String {
                data = s.data(using: .utf8)
            }
        }
        
        // 2. Fallback to UserDefaults.standard (for swift-run scenarios)
        if data == nil {
            data = UserDefaults.standard.data(forKey: "anything_manager_projects")
        }
        
        guard let payload = data else { return false }
        
        guard let decoded = try? JSONDecoder().decode([Project].self, from: payload) else {
            // Corrupt data — clean up both locations
            UserDefaults.standard.removeObject(forKey: "anything_manager_projects")
            try? FileManager.default.removeItem(atPath: plistPath)
            return false
        }
        
        do {
            let out = try JSONEncoder().encode(decoded)
            try out.write(to: url)
            projects = decoded
            UserDefaults.standard.removeObject(forKey: "anything_manager_projects")
            try? FileManager.default.removeItem(atPath: plistPath)
            return true
        } catch {
            return false
        }
    }
    
    /// Binds the manager to a user-selected config file and loads it.
    func setConfigURL(_ url: URL) {
        configURL = url
        configMissing = false
        loadProjects()
        if projects.isEmpty {
            if let sampleURL = Self.resolveSampleConfigURL() {
                do {
                    let data = try Data(contentsOf: sampleURL)
                    projects = try JSONDecoder().decode([Project].self, from: data)
                } catch {
                    projects = [Project.placeholder()]
                }
            } else {
                projects = [Project.placeholder()]
            }
            saveProjects()
        }
        objectWillChange.send()
    }
    
    // MARK: - Config resolution
    
    /// Tries to find config.json in multiple locations:
    /// 1. Relative to the source file (dev / swift run)
    /// 2. Inside the app bundle's Resources
    /// 3. Sibling of the .app bundle
    static func resolveConfigURL() -> URL? {
        // 1. Dev mode: relative to this source file (always returns a path even if
        //    the file does not exist yet, so the app can create it).
        let sourceFile = URL(fileURLWithPath: #file)
        let devConfig = sourceFile
            .deletingLastPathComponent() // AnythingManager/
            .deletingLastPathComponent() // Sources/
            .deletingLastPathComponent() // AnythingManager/
            .appendingPathComponent("config.json")
        // If the source repo is present, use it.
        if FileManager.default.fileExists(atPath: devConfig.deletingLastPathComponent().path) {
            return devConfig
        }
        
        // 2. Bundle Resources
        if let resource = Bundle.main.url(forResource: "config", withExtension: "json") {
            return resource
        }
        
        // 3. Sibling of .app bundle
        if Bundle.main.bundlePath.hasSuffix(".app") {
            let sibling = URL(fileURLWithPath: Bundle.main.bundlePath)
                .deletingLastPathComponent()
                .appendingPathComponent("config.json")
            return sibling
        }
        
        return nil
    }
    
    static func resolveSampleConfigURL() -> URL? {
        let sourceFile = URL(fileURLWithPath: #file)
        let devSample = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("config.sample.json")
        if FileManager.default.fileExists(atPath: devSample.path) {
            return devSample
        }
        if let resource = Bundle.main.url(forResource: "config.sample", withExtension: "json") {
            return resource
        }
        if Bundle.main.bundlePath.hasSuffix(".app") {
            let sibling = URL(fileURLWithPath: Bundle.main.bundlePath)
                .deletingLastPathComponent()
                .appendingPathComponent("config.sample.json")
            if FileManager.default.fileExists(atPath: sibling.path) {
                return sibling
            }
        }
        return nil
    }
    
    // MARK: - Periodic scan
    
    private func startPeriodicScan() {
        scanTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scanExternalProcesses()
            }
        }
    }
    
    func scanExternalProcesses() {
        var detected: Set<UUID> = []
        for project in projects {
            guard let port = project.port else { continue }
            if PortChecker.isPortInUse(port) && processes[project.id] == nil {
                detected.insert(project.id)
            }
        }
        if detected != externalRunning {
            externalRunning = detected
        }
    }
    
    func isRunning(projectId: UUID) -> Bool {
        guard let process = processes[projectId] else { return false }
        return process.isRunning
    }
    
    func isActive(projectId: UUID) -> Bool {
        isRunning(projectId: projectId) || externalRunning.contains(projectId)
    }
    
    func start(project: Project) {
        guard processes[project.id] == nil || !processes[project.id]!.isRunning else {
            appendLog(projectId: project.id, text: "[Already running]\n")
            return
        }
        
        let validationErrors = project.validate()
        if !validationErrors.isEmpty {
            let msg = validationErrors.joined(separator: "; ")
            errors[project.id] = msg
            appendLog(projectId: project.id, text: "[Invalid config: \(msg)]\n")
            return
        }
        
        let expandedPath = NSString(string: project.path).expandingTildeInPath
        
        errors.removeValue(forKey: project.id)
        externalRunning.remove(project.id)
        startingProjects.insert(project.id)
        
        if let port = project.port, PortChecker.isPortInUse(port) {
            appendLog(projectId: project.id, text: "[Port \(port) occupied — reclaiming]\n")
            PortChecker.killPort(port)
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let freed = PortChecker.waitForPortRelease(port, timeout: 6.0)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if freed {
                        self.start(project: project)
                    } else {
                        self.startingProjects.remove(project.id)
                        let msg = "Port \(port) still occupied after 6s."
                        self.errors[project.id] = msg
                        self.appendLog(projectId: project.id, text: "[\(msg)]\n")
                    }
                }
            }
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-il", "-c", "cd \(expandedPath) && \(project.command)"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let str = String(data: data, encoding: .utf8), !str.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.appendLog(projectId: project.id, text: str)
            }
        }
        
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.startingProjects.remove(project.id)
                self?.objectWillChange.send()
                if let reason = self?.terminationReason(for: project) {
                    self?.appendLog(projectId: project.id, text: "[Process exited: \(reason)]\n")
                }
            }
        }
        
        do {
            try process.run()
            processes[project.id] = process
            appendLog(projectId: project.id, text: "[Starting…]\n")
            objectWillChange.send()
            watchStartup(project: project)
        } catch {
            startingProjects.remove(project.id)
            let msg = "Start failed: \(error.localizedDescription)"
            errors[project.id] = msg
            appendLog(projectId: project.id, text: "[\(msg)]\n")
        }
    }
    
    private func watchStartup(project: Project) {
        guard let port = project.port else {
            startingProjects.remove(project.id)
            return
        }
        
        let checks: [TimeInterval] = [1.0, 3.0, 6.0, 10.0]
        for delay in checks {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.processes[project.id] != nil else { return }
                if PortChecker.isPortInUse(port) {
                    self.startingProjects.remove(project.id)
                    self.appendLog(projectId: project.id, text: "[Port \(port) is listening]\n")
                } else if delay == checks.last {
                    self.startingProjects.remove(project.id)
                    self.appendLog(projectId: project.id, text: "[Warning: port \(port) not listening after 10s, but process is still running]\n")
                } else {
                    self.appendLog(projectId: project.id, text: "[Waiting for port \(port)...]\n")
                }
            }
        }
    }
    
    private func terminationReason(for project: Project) -> String {
        guard let process = processes[project.id] else { return "unknown" }
        switch process.terminationStatus {
        case 0: return "clean exit"
        case 9: return "killed"
        case 143: return "terminated"
        default: return "exit code \(process.terminationStatus)"
        }
    }
    
    func stop(projectId: UUID) {
        startingProjects.remove(projectId)
        guard let process = processes[projectId] else {
            externalRunning.remove(projectId)
            objectWillChange.send()
            return
        }
        
        appendLog(projectId: projectId, text: "[Stopping…]\n")
        errors.removeValue(forKey: projectId)
        externalRunning.remove(projectId)
        processes.removeValue(forKey: projectId)
        objectWillChange.send()
        
        process.terminate()
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) {
            if process.isRunning {
                kill(process.processIdentifier, 9)
            }
        }
    }
    
    func restart(project: Project) {
        stop(projectId: project.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.start(project: project)
        }
    }
    
    func killConflictingPortAndStart(project: Project) {
        if let port = project.port {
            appendLog(projectId: project.id, text: "[Killing process on port \(port)]\n")
            PortChecker.killPort(port)
        }
        externalRunning.remove(project.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.start(project: project)
        }
    }
    
    // MARK: - Persistence
    
    func saveProjects() {
        guard let url = configURL else { return }
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: url)
        } catch {
            print("[AnythingManager] Failed to save config: \(error)")
        }
    }
    
    private func loadProjects() {
        guard let url = configURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            projects = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            projects = try JSONDecoder().decode([Project].self, from: data)
        } catch {
            print("[AnythingManager] Failed to load config: \(error)")
            projects = []
        }
    }
    
    private func appendLog(projectId: UUID, text: String) {
        let current = logs[projectId] ?? ""
        let combined = current + text
        logs[projectId] = String(combined.suffix(10000))
    }
}
