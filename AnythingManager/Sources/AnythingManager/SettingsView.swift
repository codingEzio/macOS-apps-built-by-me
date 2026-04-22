import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: ProcessManager
    let onBack: () -> Void
    @State private var launchAtLogin = false
    @State private var savedToast = false
    @State private var projectToDelete: Project? = nil
    @State private var showDeleteConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.horizontal, 12)
            settingsScroll
            Divider()
                .padding(.horizontal, 12)
            footer
        }
        .alert("Delete project?", isPresented: $showDeleteConfirm, presenting: projectToDelete) { project in
            Button("Delete", role: .destructive) {
                manager.projects.removeAll { $0.id == project.id }
                manager.saveProjects()
            }
            Button("Cancel", role: .cancel) { }
        } message: { project in
            Text("Are you sure you want to delete '\(project.name)'?")
        }
    }
    
    var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "gear")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("Settings")
                .font(.system(size: 14, weight: .bold))
            Spacer()
            Button("Back") {
                onBack()
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    var settingsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onAppear { launchAtLogin = LaunchAtLogin.isEnabled() }
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLogin.setEnabled(newValue)
                    }
                
                if let error = LaunchAtLogin.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("Projects")
                        .font(.subheadline)
                    Spacer()
                    Button(action: {
                        guard let url = manager.configURL else { return }
                        NSWorkspace.shared.open(url.deletingLastPathComponent())
                    }) {
                        Image(systemName: "folder")
                        Text("Open config folder")
                    }
                    .font(.caption)
                    .controlSize(.small)
                    .disabled(manager.configURL == nil)
                }
                
                if let url = manager.configURL {
                    Text(url.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Text("Edit config.json directly to batch-configure projects.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach($manager.projects) { $project in
                        ProjectEditorCard(
                            project: $project,
                            onDelete: {
                                projectToDelete = project
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    var footer: some View {
        HStack {
            Button("Add Project") {
                manager.projects.append(
                    Project(id: UUID(), name: "new-project", path: "", command: "bun run dev", port: nil)
                )
                manager.saveProjects()
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if savedToast {
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
                Button("Save") {
                    manager.saveProjects()
                    withAnimation { savedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { savedToast = false }
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct ProjectEditorCard: View {
    @Binding var project: Project
    let onDelete: () -> Void
    
    var body: some View {
        let errors = project.validate()
        
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Name", text: $project.name)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", text: portBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
            TextField("Path", text: $project.path)
                .textFieldStyle(.roundedBorder)
            TextField("Command", text: $project.command)
                .textFieldStyle(.roundedBorder)
            
            if !errors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(errors, id: \.self) { err in
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            Text(err)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.top, 2)
            }
            
            Button("Delete", role: .destructive, action: onDelete)
                .font(.caption)
                .controlSize(.small)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(errors.isEmpty ? Color.clear : Color.red.opacity(0.4), lineWidth: 1)
        )
    }
    
    private var portBinding: Binding<String> {
        Binding<String>(
            get: { project.port.map { String($0) } ?? "" },
            set: { project.port = Int($0) }
        )
    }
}

/// Manages a LaunchAgent plist for running the app at login.
struct LaunchAtLogin {
    private static var plistPath: String {
        NSString(string: "~/Library/LaunchAgents/com.user.AnythingManager.plist").expandingTildeInPath
    }
    
    static var appPath: String {
        let bundle = Bundle.main
        if bundle.bundlePath.hasSuffix(".app") {
            return bundle.bundlePath
        }
        let binaryPath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
        let binaryURL = URL(fileURLWithPath: binaryPath)
        let repoRoot = binaryURL
            .deletingLastPathComponent() // .build/debug/
            .deletingLastPathComponent() // .build/
            .deletingLastPathComponent() // repo root
        return repoRoot
            .appendingPathComponent("Applications")
            .appendingPathComponent("AnythingManager.app")
            .path
    }
    
    static var lastError: String? = nil
    
    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }
    
    static func setEnabled(_ enabled: Bool) {
        lastError = nil
        if enabled {
            enable()
        } else {
            disable()
        }
    }
    
    private static func enable() {
        let plist: [String: Any] = [
            "Label": "com.user.AnythingManager",
            "ProgramArguments": [appPath],
            "RunAtLoad": true
        ]
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            let url = URL(fileURLWithPath: plistPath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["load", plistPath]
            try? task.run()
        } catch {
            lastError = "Failed to enable: \(error.localizedDescription)"
        }
    }
    
    private static func disable() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", plistPath]
        try? task.run()
        do {
            try FileManager.default.removeItem(atPath: plistPath)
        } catch {
            lastError = "Failed to disable: \(error.localizedDescription)"
        }
    }
}
