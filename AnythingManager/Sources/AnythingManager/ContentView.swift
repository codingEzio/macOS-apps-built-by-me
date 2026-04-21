import SwiftUI

struct ContentView: View {
    @StateObject private var manager = ProcessManager()
    @State private var showingSettings = false
    @State private var showingLogs: Project? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            Divider()
                .padding(.vertical, 10)
            
            if manager.projects.isEmpty {
                Text("No projects yet.\nOpen Settings to add one.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(manager.projects) { project in
                            ProjectCard(
                                project: project,
                                manager: manager,
                                showingLogs: $showingLogs
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(maxHeight: 380)
            }
            
            Divider()
                .padding(.vertical, 10)
            
            HStack {
                Button("Settings…") {
                    showingSettings = true
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(manager: manager)
                }
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .padding(.top, 14)
    }
    
    var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "command.square.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("Anything Manager")
                .font(.system(size: 15, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct ProjectCard: View {
    let project: Project
    @ObservedObject var manager: ProcessManager
    @Binding var showingLogs: Project?
    
    var isRunning: Bool {
        manager.isRunning(projectId: project.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isRunning ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    Text(project.name)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(isRunning ? "Running" : "Stopped")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isRunning ? .green : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isRunning ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                        .cornerRadius(4)
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
                    let portOccupied = project.port.map { PortChecker.isPortInUse($0) } ?? false
                    
                    if portOccupied {
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(project.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(project.command)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let port = project.port {
                        HStack(spacing: 4) {
                            Text(":\(port)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if PortChecker.isPortInUse(port) && !isRunning {
                                Text("occupied")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            
            if isRunning {
                Button("Show Logs") {
                    showingLogs = project
                }
                .font(.caption)
                .sheet(item: $showingLogs) { logProject in
                    LogView(manager: manager, project: logProject)
                }
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
