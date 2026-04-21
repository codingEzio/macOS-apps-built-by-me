import SwiftUI

struct ContentView: View {
    @StateObject private var manager = ProcessManager()
    @State private var screen: Screen = .projects
    @State private var logProject: Project? = nil
    
    enum Screen {
        case projects
        case settings
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider().padding(.vertical, 10)
            
            switch screen {
            case .projects:
                projectsScreen
                    .transition(.opacity)
            case .settings:
                SettingsView(manager: manager, onBack: { withAnimation { screen = .projects } })
                    .transition(.opacity)
            }
        }
        .frame(width: 380, height: 420)
        .animation(.easeInOut(duration: 0.15), value: screen)
    }
    
    var header: some View {
        HStack {
            Image(systemName: "command.square.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("Anything Manager")
                .font(.system(size: 15, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
    
    var projectsScreen: some View {
        VStack(spacing: 0) {
            if manager.projects.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("No projects")
                        .font(.headline)
                    Text("Open Settings to add your first project.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(manager.projects) { project in
                            ProjectRow(
                                project: project,
                                manager: manager,
                                onShowLogs: { logProject = project }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            
            Divider().padding(.vertical, 10)
            
            HStack {
                Button("Settings") {
                    withAnimation { screen = .settings }
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .sheet(item: $logProject) { project in
            LogView(manager: manager, project: project)
        }
    }
}

struct ProjectRow: View {
    let project: Project
    @ObservedObject var manager: ProcessManager
    let onShowLogs: () -> Void
    
    var isRunning: Bool {
        manager.isRunning(projectId: project.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isRunning ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(project.name)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Spacer()
                
                if isRunning {
                    Button("Restart") {
                        manager.restart(project: project)
                    }
                    Button("Stop") {
                        manager.stop(projectId: project.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    let occupied = project.port.map { PortChecker.isPortInUse($0) } ?? false
                    if occupied {
                        Button("Force Start") {
                            manager.killConflictingPortAndStart(project: project)
                        }
                        .tint(.orange)
                    } else {
                        Button("Start") {
                            manager.start(project: project)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            
            HStack(spacing: 6) {
                Text(isRunning ? "Running" : "Stopped")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isRunning ? .green : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isRunning ? Color.green.opacity(0.12) : Color.gray.opacity(0.12))
                    .cornerRadius(4)
                
                if let port = project.port {
                    Text(":\(port)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if PortChecker.isPortInUse(port) && !isRunning {
                        Text("occupied")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
            
            if let error = manager.errors[project.id] {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if isRunning {
                Button("Show Logs") {
                    onShowLogs()
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct LogView: View {
    @ObservedObject var manager: ProcessManager
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(project.name) logs")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }
            
            ScrollView {
                Text(manager.logs[project.id]?.isEmpty == false ? manager.logs[project.id]! : "No logs yet…")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
        }
        .padding()
        .frame(width: 640, height: 420)
    }
}
