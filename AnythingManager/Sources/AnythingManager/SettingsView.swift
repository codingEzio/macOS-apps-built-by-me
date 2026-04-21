import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var manager: ProcessManager
    @Environment(\.dismiss) private var dismiss
    @State private var launchAtLogin = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
            }
            
            Divider()
            
            Toggle("开机自动启动 AnythingManager", isOn: $launchAtLogin)
                .onAppear { launchAtLogin = isLaunchAtLoginEnabled() }
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(enabled: newValue)
                }
            
            Text("管理项目")
                .font(.subheadline)
                .padding(.top, 8)
            
            List {
                ForEach($manager.projects) { $project in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("名称", text: $project.name)
                                .textFieldStyle(.roundedBorder)
                            TextField("端口", value: $project.port, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        TextField("路径", text: $project.path)
                            .textFieldStyle(.roundedBorder)
                        TextField("启动命令", text: $project.command)
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
                Button("添加项目") {
                    manager.projects.append(
                        Project(id: UUID(), name: "新项目", path: "", command: "bun run dev", port: nil)
                    )
                    manager.saveProjects()
                }
                
                Spacer()
                
                Button("保存") {
                    manager.saveProjects()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 480, height: 420)
    }
}

func isLaunchAtLoginEnabled() -> Bool {
    SMAppService.mainApp.status == .enabled
}

func setLaunchAtLogin(enabled: Bool) {
    let service = SMAppService.mainApp
    do {
        if enabled {
            if service.status != .enabled {
                try service.register()
            }
        } else {
            if service.status == .enabled {
                try service.unregister()
            }
        }
    } catch {
        print("设置开机自启失败: \(error)")
    }
}
