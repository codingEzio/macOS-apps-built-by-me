import Foundation
import Combine

/// Manages running external projects (e.g. bun dev servers) as child processes.
@MainActor
class ProcessManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var logs: [UUID: String] = [:]
    @Published var errors: [UUID: String] = [:]
    /// Projects whose configured port is occupied but are not tracked by this instance.
    @Published var externalRunning: Set<UUID> = []
    
    private var processes: [UUID: Process] = [:]
    
    init() {
        loadProjects()
        if projects.isEmpty {
            projects = [Project.defaultProject()]
            saveProjects()
        }
        scanExternalProcesses()
    }
    
    /// Checks configured ports to see if a project is already running
    /// from a previous app instance or external launch.
    func scanExternalProcesses() {
        var detected: Set<UUID> = []
        for project in projects {
            guard let port = project.port else { continue }
            if PortChecker.isPortInUse(port) && processes[project.id] == nil {
                detected.insert(project.id)
                appendLog(projectId: project.id, text: "[Detected external process on port \(port)]\n")
            }
        }
        externalRunning = detected
    }
    
    func isRunning(projectId: UUID) -> Bool {
        guard let process = processes[projectId] else { return false }
        return process.isRunning
    }
    
    /// True if the project is either tracked by us or detected externally.
    func isActive(projectId: UUID) -> Bool {
        isRunning(projectId: projectId) || externalRunning.contains(projectId)
    }
    
    func start(project: Project) {
        guard processes[project.id] == nil || !processes[project.id]!.isRunning else {
            appendLog(projectId: project.id, text: "[Already running]\n")
            return
        }
        
        // Clear any stale error / external flag
        errors.removeValue(forKey: project.id)
        externalRunning.remove(project.id)
        
        // If the port is occupied by someone else, take over automatically
        if let port = project.port, PortChecker.isPortInUse(port) {
            appendLog(projectId: project.id, text: "[Port \(port) occupied — taking over]\n")
            PortChecker.killPort(port)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.start(project: project)
            }
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "cd \(project.path) && \(project.command)"]
        
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
                self?.objectWillChange.send()
            }
        }
        
        do {
            try process.run()
            processes[project.id] = process
            appendLog(projectId: project.id, text: "[Started]\n")
            objectWillChange.send()
        } catch {
            let msg = "Start failed: \(error.localizedDescription)"
            errors[project.id] = msg
            appendLog(projectId: project.id, text: "[\(msg)]\n")
        }
    }
    
    func stop(projectId: UUID) {
        guard let process = processes[projectId] else {
            // If it is running externally, just clear the flag
            externalRunning.remove(projectId)
            objectWillChange.send()
            return
        }
        
        appendLog(projectId: projectId, text: "[Stopping…]\n")
        errors.removeValue(forKey: projectId)
        externalRunning.remove(projectId)
        
        // Immediately remove from tracking so UI updates right away
        processes.removeValue(forKey: projectId)
        objectWillChange.send()
        
        // Try graceful terminate first
        process.terminate()
        
        // If it's still there after a moment, force kill on a background queue
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
            if process.isRunning {
                kill(process.processIdentifier, 9)
            }
        }
    }
    
    func restart(project: Project) {
        stop(projectId: project.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.start(project: project)
        }
    }
    
    func killConflictingPortAndStart(project: Project) {
        if let port = project.port {
            appendLog(projectId: project.id, text: "[Killing process on port \(port)]\n")
            PortChecker.killPort(port)
        }
        externalRunning.remove(project.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.start(project: project)
        }
    }
    
    func saveProjects() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: "anything_manager_projects")
        }
    }
    
    private func loadProjects() {
        guard let data = UserDefaults.standard.data(forKey: "anything_manager_projects"),
              let decoded = try? JSONDecoder().decode([Project].self, from: data)
        else { return }
        projects = decoded
    }
    
    private func appendLog(projectId: UUID, text: String) {
        let current = logs[projectId] ?? ""
        let combined = current + text
        // Keep last ~10k chars so memory doesn't grow forever
        logs[projectId] = String(combined.suffix(10000))
    }
}
