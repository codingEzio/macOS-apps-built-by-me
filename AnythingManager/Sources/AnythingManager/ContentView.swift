import SwiftUI

struct ContentView: View {
    @StateObject private var manager = ProcessManager()
    @State private var showingSettings = false
    @State private var showingLogs: Project? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            Divider()
                .padding(.vertical, 8)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($manager.projects) { $project in
                        ProjectCard(project: $project, manager: manager, showingLogs: $showingLogs)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: 360)
            
            Divider()
                .padding(.vertical, 8)
            
            footer
        }
        .padding(.vertical, 12)
    }
    
    var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "command.square.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("Anything Manager")
                .font(.system(size: 14, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    var footer: some View {
        HStack {
            Button("设置") {
                showingSettings = true
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(manager: manager)
            }
            
            Spacer()
            
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct ProjectCard: View {
    @Binding var project: Project
    @ObservedObject var manager: ProcessManager
    @Binding var showingLogs: Project?
    
    var isRunning: Bool {
        manager.isRunning(projectId: project.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                if isRunning {
                    Button("停止") {
                        manager.stop(projectId: project.id)
                    }
                    .controlSize(.small)
                    
                    Button("重启") {
                        manager.restart(project: project)
                    }
                    .controlSize(.small)
                } else {
                    let portOccupied = project.port.map { PortChecker.isPortInUse($0) && !isRunning } ?? false
                    
                    Button(portOccupied ? "强制启动" : "启动") {
                        if portOccupied {
                            manager.killConflictingPortAndStart(project: project)
                        } else {
                            manager.start(project: project)
                        }
                    }
                    .controlSize(.small)
                }
            }
            
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
                            Text("被占用")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            if isRunning {
                Button("查看日志") {
                    showingLogs = project
                }
                .font(.caption)
                .sheet(item: $showingLogs) { logProject in
                    LogView(manager: manager, project: logProject)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct LogView: View {
    @ObservedObject var manager: ProcessManager
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(project.name) 日志")
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
            }
            
            ScrollView {
                Text(manager.logs[project.id] ?? "暂无日志")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
        }
        .padding()
        .frame(width: 600, height: 400)
    }
}
