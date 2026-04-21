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
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Back") {
                    onBack()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            Divider().padding(.vertical, 10)
            
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
                    
                    Text("Projects")
                        .font(.subheadline)
                    
                    VStack(spacing: 12) {
                        ForEach($manager.projects) { $project in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    TextField("Name", text: $project.name)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Port", text: portBinding(for: $project))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                }
                                TextField("Path", text: $project.path)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Command", text: $project.command)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("Delete", role: .destructive) {
                                    projectToDelete = project
                                    showDeleteConfirm = true
                                }
                                .font(.caption)
                                .controlSize(.small)
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Divider().padding(.vertical, 10)
            
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
            .padding(.bottom, 12)
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
    
    private func portBinding(for project: Binding<Project>) -> Binding<String> {
        Binding<String>(
            get: { project.wrappedValue.port.map { String($0) } ?? "" },
            set: { project.wrappedValue.port = Int($0) }
        )
    }
}

/// Manages a LaunchAgent plist for running the app at login.
struct LaunchAtLogin {
    private static var plistPath: String {
        NSString(string: "~/Library/LaunchAgents/com.user.AnythingManager.plist").expandingTildeInPath
    }
    
    /// Derives the .app path dynamically. When running inside a bundled .app we use Bundle.main.
    /// During development (swift run) we fall back to the repo-relative Applications folder.
    static var appPath: String {
        let bundle = Bundle.main
        if bundle.bundlePath.hasSuffix(".app") {
            return bundle.bundlePath
        }
        // Development fallback: derive from this source file location.
        let sourceFile = URL(fileURLWithPath: #file)
        let repoRoot = sourceFile
            .deletingLastPathComponent() // AnythingManager/
            .deletingLastPathComponent() // Sources/
            .deletingLastPathComponent() // AnythingManager/
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
