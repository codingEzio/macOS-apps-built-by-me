import SwiftUI

struct ContentView: View {
    @ObservedObject var manager: ProcessManager
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
            Image(systemName: "bolt.circle.fill")
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
                emptyState
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
    
    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No projects yet")
                .font(.headline)
            Text("Open Settings to add your first one.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

struct ProjectRow: View {
    let project: Project
    @ObservedObject var manager: ProcessManager
    let onShowLogs: () -> Void
    
    var isRunning: Bool {
        manager.isRunning(projectId: project.id)
    }
    
    var isExternal: Bool {
        manager.externalRunning.contains(project.id)
    }
    
    var isStarting: Bool {
        manager.startingProjects.contains(project.id)
    }
    
    var isActive: Bool {
        isRunning || isExternal
    }
    
    var hasLogs: Bool {
        manager.logs[project.id]?.isEmpty == false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    statusIndicator
                    Text(project.name)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Spacer()
                
                if isStarting {
                    Button(action: {}) {
                        Label("Starting", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                } else if isRunning {
                    Button("Restart") {
                        manager.restart(project: project)
                    }
                    Button("Stop") {
                        manager.stop(projectId: project.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else if isExternal {
                    Button("Take Over") {
                        manager.killConflictingPortAndStart(project: project)
                    }
                    .tint(.orange)
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
                if isStarting {
                    Label("Starting", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .statusTag(color: .accentColor)
                } else if isRunning {
                    Label("Running", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .statusTag(color: .green)
                } else if isExternal {
                    Label("External", systemImage: "globe")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .statusTag(color: .orange)
                } else {
                    Label("Stopped", systemImage: "stop.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .statusTag(color: .secondary, bgOpacity: 0.12)
                }
                
                if let port = project.port {
                    Text(":\(port)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if PortChecker.isPortInUse(port) && !isActive && !isStarting {
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
            
            if !isActive && !isStarting && !hasLogs {
                Text("Click Start to run \(project.command)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isActive || isStarting {
                Button("Show Logs") {
                    onShowLogs()
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    var statusIndicator: some View {
        if isStarting {
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 12, height: 12)
        } else if isRunning {
            Image(systemName: "bolt.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 12))
        } else if isExternal {
            Image(systemName: "bolt.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 12))
        } else {
            Image(systemName: "bolt.circle")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
        }
    }
}

extension View {
    func statusTag(color: Color, bgOpacity: Double = 0.15) -> some View {
        self
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(bgOpacity))
            .cornerRadius(4)
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
            
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("logBottom")
                }
                .background(Color.black.opacity(0.05))
                .cornerRadius(6)
                .onChange(of: manager.logs[project.id]) { _ in
                    withAnimation {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .frame(width: 640, height: 420)
    }
    
    var logText: String {
        if let text = manager.logs[project.id], !text.isEmpty {
            return text
        }
        return "No logs yet…"
    }
}
