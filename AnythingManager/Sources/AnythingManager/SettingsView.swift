import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: ProcessManager
    @Environment(\.dismiss) private var dismiss
    @State private var launchAtLogin = false
    @State private var savedToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            
            Divider()
            
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onAppear { launchAtLogin = LaunchAtLogin.isEnabled() }
                .onChange(of: launchAtLogin) { newValue in
                    LaunchAtLogin.setEnabled(newValue)
                }
            
            Text("Projects")
                .font(.subheadline)
                .padding(.top, 8)
            
            List {
                ForEach($manager.projects) { $project in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("Name", text: $project.name)
                                .textFieldStyle(.roundedBorder)
                            TextField("Port (optional)", text: portBinding(for: $project))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                        TextField("Path", text: $project.path)
                            .textFieldStyle(.roundedBorder)
                        TextField("Command", text: $project.command)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    manager.projects.remove(atOffsets: indexSet)
                    manager.saveProjects()
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 180)
            
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
                        withAnimation {
                            savedToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                savedToast = false
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 480, height: 420)
    }
    
    private func portBinding(for project: Binding<Project>) -> Binding<String> {
        Binding<String>(
            get: {
                if let port = project.wrappedValue.port {
                    return String(port)
                }
                return ""
            },
            set: { newValue in
                project.wrappedValue.port = Int(newValue)
            }
        )
    }
}

struct LaunchAtLogin {
    private static var plistPath: String {
        NSString(string: "~/Library/LaunchAgents/com.user.AnythingManager.plist").expandingTildeInPath
    }
    
    private static var appPath: String {
        let repoRoot = NSString(string: "/path/to/repo").expandingTildeInPath
        return "\(repoRoot)/Applications/AnythingManager.app/Contents/MacOS/AnythingManager"
    }
    
    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }
    
    static func setEnabled(_ enabled: Bool) {
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
            print("Failed to enable launch at login: \(error)")
        }
    }
    
    private static func disable() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", plistPath]
        try? task.run()
        
        try? FileManager.default.removeItem(atPath: plistPath)
    }
}
