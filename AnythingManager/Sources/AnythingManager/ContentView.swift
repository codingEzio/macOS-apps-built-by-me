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
        Group {
            if manager.configMissing {
                ConfigMissingView(manager: manager)
            } else {
                mainView
            }
        }
        .frame(width: 380, height: 440)
    }

    var mainView: some View {
        VStack(spacing: 0) {
            switch screen {
            case .projects:
                projectsScreen
            case .settings:
                SettingsView(manager: manager, onBack: { screen = .projects })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: screen)
    }

    // MARK: - Projects Screen

    var projectsScreen: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("Anything Manager")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // Port banner (external only)
            portStatusBanner
                .padding(.top, 8)

            // Project list
            if manager.projects.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(manager.projects) { project in
                            ProjectRow(
                                project: project,
                                manager: manager,
                                onShowLogs: { logProject = project }
                            )
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 2)
                }
            }

            Spacer(minLength: 4)

            Divider()
                .padding(.horizontal, 12)

            // Bottom bar
            HStack {
                Button("Settings") {
                    screen = .settings
                }
                .font(.system(size: 12))

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .sheet(item: $logProject) { project in
            LogView(manager: manager, project: project)
        }
    }

    @ViewBuilder
    var portStatusBanner: some View {
        let occupiedProjects = manager.projects.compactMap { project -> (Project, [PortProcessInfo])? in
            guard let port = project.port,
                  !manager.isActive(projectId: project.id),
                  !manager.isStarting(projectId: project.id)
            else { return nil }
            let occupants = manager.portOccupancy[port] ?? []
            return occupants.isEmpty ? nil : (project, occupants)
        }

        if !occupiedProjects.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Port occupied by external process")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Spacer()
                }
                ForEach(occupiedProjects, id: \.0.id) { project, _ in
                    Text("\(project.name) :\(project.port ?? 0)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(8)
            .padding(.horizontal, 14)
            .padding(.bottom, 2)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No projects yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Open Settings to add your first one.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

// MARK: - Config Missing

struct ConfigMissingView: View {
    @ObservedObject var manager: ProcessManager
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Config file not found")
                .font(.headline)

            Text("The app looks for config.json next to the app bundle or in the source directory. You can also select one manually.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button("Select config.json…") {
                pickConfigFile()
            }
            .controlSize(.large)

            if let sample = ProcessManager.resolveSampleConfigURL() {
                Button("Use sample config") {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.json]
                    panel.nameFieldStringValue = "config.json"
                    panel.directoryURL = sample.deletingLastPathComponent()
                    if panel.runModal() == .OK, let url = panel.url {
                        do {
                            let data = try Data(contentsOf: sample)
                            try data.write(to: url)
                            manager.setConfigURL(url)
                        } catch {
                            print("[AnythingManager] Failed to copy sample: \(error)")
                        }
                    }
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding()
    }

    private func pickConfigFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        panel.message = "Select a config.json file"
        if panel.runModal() == .OK, let url = panel.url {
            manager.setConfigURL(url)
        }
    }
}

// MARK: - Project Row

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
        VStack(alignment: .leading, spacing: 8) {
            // Title + action buttons
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    statusDot
                    Text(project.name)
                        .font(.system(size: 13, weight: .semibold))
                }

                Spacer()

                if isStarting {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                        Text("Starting")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                } else if isRunning {
                    Button("Restart") {
                        manager.restart(project: project)
                    }
                    .font(.system(size: 11))
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                    Button("Stop") {
                        manager.stop(projectId: project.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                    .keyboardShortcut(".", modifiers: .command)
                } else if isExternal {
                    Button("Take Over") {
                        manager.killConflictingPortAndStart(project: project)
                    }
                    .font(.system(size: 11))
                    .tint(.orange)
                } else {
                    let occupied = project.port.map { (manager.portOccupancy[$0] ?? []).isEmpty == false } ?? false
                    if occupied {
                        Button("Force Start") {
                            manager.killConflictingPortAndStart(project: project)
                        }
                        .font(.system(size: 11))
                        .tint(.orange)
                    } else {
                        Button("Start") {
                            manager.start(project: project)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
            }

            // Status + port + logs
            HStack(spacing: 6) {
                statusBadge

                if let port = project.port {
                    Text(":\(port)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isActive || isStarting {
                    Button(action: onShowLogs) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Show logs")
                }
            }

            // Error
            if let error = manager.errors[project.id] {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Hint text
            if !isActive && !isStarting && !hasLogs {
                Text(project.command)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    @ViewBuilder
    var statusDot: some View {
        Circle()
            .fill(isStarting ? Color.accentColor : isRunning ? Color.green : isExternal ? Color.orange : Color.secondary.opacity(0.4))
            .frame(width: 6, height: 6)
    }

    @ViewBuilder
    var statusBadge: some View {
        if isStarting {
            Text("Starting")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
        } else if isRunning {
            Text("Running")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.green)
        } else if isExternal {
            Text("External")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.orange)
        } else {
            Text("Stopped")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Log View

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
                Button("Clear") {
                    manager.logs.removeValue(forKey: project.id)
                }
                .font(.caption)
                Button("Close") { dismiss() }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("logBottom")
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
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
