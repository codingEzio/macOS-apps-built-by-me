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
    
    func testProjectCodableRoundTrip() {
        let original = Project(id: UUID(), name: "test", path: "/tmp/test", command: "echo hi", port: 3000)
        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(Project.self, from: data)
        
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.path, decoded.path)
        XCTAssertEqual(original.command, decoded.command)
        XCTAssertEqual(original.port, decoded.port)
    }
    
    func testProjectEquality() {
        let id = UUID()
        let a = Project(id: id, name: "a", path: "/a", command: "a", port: nil)
        let b = Project(id: id, name: "b", path: "/b", command: "b", port: 80)
        XCTAssertEqual(a, b) // Equality is based on ID only
    }
}

final class PortCheckerTests: XCTestCase {
    func testHighRandomPortIsFree() {
        // A very high random port is extremely unlikely to be in use.
        let port = 54321
        let occupied = PortChecker.isPortInUse(port)
        XCTAssertFalse(occupied, "Port \(port) should not be in use during tests")
    }
    
    func testConsistencyBetweenIsPortInUseAndPids() {
        // For any port, isPortInUse should be true iff pidsUsingPort is non-empty.
        let port = 54322
        let inUse = PortChecker.isPortInUse(port)
        let pids = PortChecker.pidsUsingPort(port)
        XCTAssertEqual(inUse, !pids.isEmpty, "isPortInUse and pidsUsingPort must be consistent")
    }
}

@MainActor
final class ProcessManagerTests: XCTestCase {
    private let testSuite = "test.AnythingManager.ProcessManager"
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: testSuite)
    }
    
    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: testSuite)
        super.tearDown()
    }
    
    func testInitialStateLoadsDefaultProject() {
        // Ensure no leftover data in standard UserDefaults
        UserDefaults.standard.removeObject(forKey: "anything_manager_projects")
        let manager = ProcessManager()
        XCTAssertFalse(manager.projects.isEmpty, "Should load default project when empty")
        XCTAssertEqual(manager.projects.first?.name, "anything")
    }
    
    func testIsRunningForUnknownProject() {
        let manager = ProcessManager()
        let id = UUID()
        XCTAssertFalse(manager.isRunning(projectId: id))
    }
    
    func testSaveAndLoadProjects() {
        UserDefaults.standard.removeObject(forKey: "anything_manager_projects")
        let manager = ProcessManager()
        let originalCount = manager.projects.count
        
        manager.projects.append(Project(id: UUID(), name: "x", path: "/x", command: "y", port: nil))
        manager.saveProjects()
        
        let fresh = ProcessManager()
        XCTAssertEqual(fresh.projects.count, originalCount + 1)
        XCTAssertTrue(fresh.projects.contains { $0.name == "x" })
    }
    
    func testErrorStateIsClearedOnStart() {
        let manager = ProcessManager()
        let project = manager.projects.first!
        manager.errors[project.id] = "Some old error"
        // Calling start on an already-running project should not clear errors,
        // but calling start on a new project should.
        manager.start(project: project)
        // Since project is not running yet, error should be cleared.
        XCTAssertNil(manager.errors[project.id])
    }
}

final class LaunchAtLoginTests: XCTestCase {
    func testAppPathDerivation() {
        let path = LaunchAtLogin.appPath
        XCTAssertTrue(path.hasSuffix("AnythingManager.app"), "App path should end with .app")
    }
    
    func testPlistGenerationAndRemoval() {
        // Clean up first
        LaunchAtLogin.setEnabled(false)
        XCTAssertFalse(LaunchAtLogin.isEnabled())
        
        LaunchAtLogin.setEnabled(true)
        XCTAssertTrue(LaunchAtLogin.isEnabled())
        
        LaunchAtLogin.setEnabled(false)
        XCTAssertFalse(LaunchAtLogin.isEnabled())
    }
}
