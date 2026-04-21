import Foundation

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var path: String
    var command: String
    var port: Int?
    
    /// A placeholder project used when no config exists yet.
    /// All values are intentionally generic so no personal paths leak into source.
    static func placeholder() -> Project {
        Project(
            id: UUID(),
            name: "your-project",
            path: "/path/to/your/project",
            command: "bun run dev",
            port: 3000
        )
    }
    
    /// Validates the project configuration and returns a list of human-readable errors.
    func validate() -> [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Name is required")
        }
        
        if path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Path is required")
        } else {
            let expanded = NSString(string: path).expandingTildeInPath
            if !FileManager.default.fileExists(atPath: expanded) {
                errors.append("Path does not exist: \(path)")
            }
        }
        
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Command is required")
        }
        
        if let p = port {
            if p < 1 || p > 65535 {
                errors.append("Port must be between 1 and 65535")
            }
        }
        
        return errors
    }
    
    var isValid: Bool {
        validate().isEmpty
    }
}
