import Foundation
import Combine

@MainActor
class ProcessManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var logs: [UUID: String] = [:]
    @Published var errors: [UUID: String] = [:]
    @Published var externalRunning: Set<UUID> = []
    @Published var startingProjects: Set<UUID> = []
    
    private var processes: [UUID: Process] = [:]
    private var scanTimer: Timer?
    
    /// Path to the JSON config file on disk.
    static var configFileURL: URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = supportDir.appendingPathComponent("AnythingManager", isDirectory: true)
        return appDir.appendingPathComponent("projects.json")
    }
    
    init() {
        loadProjects()
        if projects.isEmpty {
            projects = [Project.defaultProject()]
            saveProjects()
        }
        scanExternalProcesses()
        startPeriodicScan()
    }
    
    /// Re-scan port occupancy every 3 seconds so the UI stays in sync
    /// with dev servers started from the terminal.
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
        // Only publish if changed to avoid needless SwiftUI redraws
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
        
        // If port is occupied, reclaim it
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
        // -i forces interactive mode so .zshrc is fully sourced (fixes PATH for bun)
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
        
        // Check at 1s, 3s, 6s, 10s — some dev servers are very slow on first compile
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
    
    // MARK: - Config file persistence
    
    func saveProjects() {
        let url = Self.configFileURL
        do {
            let data = try JSONEncoder().encode(projects)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        } catch {
            print("[AnythingManager] Failed to save projects: \(error)")
        }
    }
    
    private func loadProjects() {
        let url = Self.configFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Fall back to UserDefaults for backward compatibility
            if let data = UserDefaults.standard.data(forKey: "anything_manager_projects"),
               let decoded = try? JSONDecoder().decode([Project].self, from: data) {
                projects = decoded
                // Migrate to file
                saveProjects()
                UserDefaults.standard.removeObject(forKey: "anything_manager_projects")
            }
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            projects = try JSONDecoder().decode([Project].self, from: data)
        } catch {
            print("[AnythingManager] Failed to load projects: \(error)")
            projects = []
        }
    }
    
    private func appendLog(projectId: UUID, text: String) {
        let current = logs[projectId] ?? ""
        let combined = current + text
        logs[projectId] = String(combined.suffix(10000))
    }
}
