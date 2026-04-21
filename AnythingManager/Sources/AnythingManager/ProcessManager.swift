import Foundation
import Combine

@MainActor
class ProcessManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var logs: [UUID: String] = [:]
    
    private var processes: [UUID: Process] = [:]
    
    init() {
        loadProjects()
        if projects.isEmpty {
            projects = [Project.defaultProject()]
            saveProjects()
        }
    }
    
    func isRunning(projectId: UUID) -> Bool {
        guard let process = processes[projectId] else { return false }
        return process.isRunning
    }
    
    func start(project: Project) {
        guard processes[project.id] == nil || !processes[project.id]!.isRunning else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "cd \(project.path) && \(project.command)"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                Task { @MainActor [weak self] in
                    let current = self?.logs[project.id] ?? ""
                    let trimmed = (current + str).suffix(5000)
                    self?.logs[project.id] = String(trimmed)
                }
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
            objectWillChange.send()
        } catch {
            logs[project.id, default: ""] += "\n启动失败: \(error.localizedDescription)\n"
        }
    }
    
    func stop(projectId: UUID) {
        guard let process = processes[projectId] else { return }
        process.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if process.isRunning {
                kill(process.processIdentifier, 9)
            }
            self?.processes.removeValue(forKey: projectId)
            self?.objectWillChange.send()
        }
    }
    
    func restart(project: Project) {
        stop(projectId: project.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start(project: project)
        }
    }
    
    func killConflictingPortAndStart(project: Project) {
        if let port = project.port {
            PortChecker.killPort(port)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
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
}
