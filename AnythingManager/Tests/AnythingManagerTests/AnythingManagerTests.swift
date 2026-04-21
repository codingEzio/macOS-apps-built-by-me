import XCTest
@testable import AnythingManager

final class ProjectTests: XCTestCase {
    func testDefaultProject() {
        let p = Project.defaultProject()
        XCTAssertEqual(p.name, "anything")
        XCTAssertEqual(p.command, "bun run dev")
        XCTAssertTrue(p.path.contains("anything"))
        XCTAssertNil(p.port)
    }
    
    func testProjectCodable() {
        let original = Project(id: UUID(), name: "test", path: "/tmp/test", command: "echo hi", port: 3000)
        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(Project.self, from: data)
        
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.path, decoded.path)
        XCTAssertEqual(original.command, decoded.command)
        XCTAssertEqual(original.port, decoded.port)
    }
}

final class PortCheckerTests: XCTestCase {
    func testWellKnownPortInUse() {
        // Port 22 (SSH) is usually occupied on macOS
        let occupied = PortChecker.isPortInUse(22)
        XCTAssertTrue(occupied, "Port 22 should be in use on a typical macOS system")
    }
    
    func testRandomHighPortNotInUse() {
        // Pick a very high random port unlikely to be used
        let port = 54321
        let occupied = PortChecker.isPortInUse(port)
        XCTAssertFalse(occupied, "Port \(port) should not be in use during tests")
    }
    
    func testPidsForOccupiedPort() {
        let pids = PortChecker.pidsUsingPort(22)
        XCTAssertFalse(pids.isEmpty, "Should find at least one PID on port 22")
    }
}

@MainActor
final class ProcessManagerTests: XCTestCase {
    func testInitialState() {
        let manager = ProcessManager()
        XCTAssertFalse(manager.projects.isEmpty, "Should load default project if empty")
    }
    
    func testIsRunningForUnknownProject() {
        let manager = ProcessManager()
        let id = UUID()
        XCTAssertFalse(manager.isRunning(projectId: id))
    }
    
    func testSaveAndLoadProjects() {
        let manager = ProcessManager()
        let originalCount = manager.projects.count
        
        manager.projects.append(Project(id: UUID(), name: "x", path: "/x", command: "y", port: nil))
        manager.saveProjects()
        
        let fresh = ProcessManager()
        XCTAssertEqual(fresh.projects.count, originalCount + 1)
        XCTAssertTrue(fresh.projects.contains { $0.name == "x" })
    }
}
