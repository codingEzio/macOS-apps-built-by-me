import Foundation

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var path: String
    var command: String
    var port: Int?
    
    static func defaultProject() -> Project {
        Project(
            id: UUID(),
            name: "anything",
            path: NSString(string: "/path/to/project").expandingTildeInPath,
            command: "bun run dev",
            port: 3000
        )
    }
}
