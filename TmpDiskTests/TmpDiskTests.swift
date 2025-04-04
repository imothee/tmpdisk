//
//  TmpDiskTests.swift
//  TmpDiskTests
//
//  Created by Tim on 12/11/21.
//

import XCTest
@testable import TmpDisk

class TmpDiskTests: XCTestCase {

    override func setUpWithError() throws {
        TmpDiskManager.shared.ejectAllTmpDisks(recreate: false)
    }

    override func tearDownWithError() throws {
        TmpDiskManager.shared.ejectAllTmpDisks(recreate: false)
    }

    func testCreateTmpDiskNoName() throws {
        let volume = TmpDiskVolume()
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNotNil(error)
            XCTAssertEqual(error!, TmpDiskError.noName)
        }
    }
    
    // MARK: - TmpDisk
    
    func testCreateTmpDiskSucceedsAndEjects() throws {
        let volume = TmpDiskVolume(name: "testvolume")
        let expectation = self.expectation(description: "Creating")
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Volume should exist")
            
            TmpDiskManager.shared.ejectTmpDisksWithName(names: [volume.name], recreate: false)
            XCTAssertFalse(TmpDiskManager.shared.exists(volume: volume), "Volume should not exist")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCreateFolders() throws {
        let volume = TmpDiskVolume(name: "testwithfolders", folders: ["folder1", "folder2/subfolder1"])
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Volume should exist")
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: "\(volume.path())/folder1"), "Volume should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: "\(volume.path())/folder2/subfolder1"), "Volume should exist")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCreateExists() throws {
        let volume = TmpDiskVolume(name: "testexists")
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Volume should exist")
            
            TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
                XCTAssertNotNil(error)
                XCTAssertEqual(error!, TmpDiskError.exists)
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Tmpfs
    
    func testCreateTmpfsSucceedsAndEjects() throws {
        let volume = TmpDiskVolume(name: "testtmpfsvolume", tmpFs: true)
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Volume should exist")
            
            TmpDiskManager.shared.ejectTmpDisksWithName(names: [volume.name], recreate: false)
            XCTAssertFalse(TmpDiskManager.shared.exists(volume: volume), "Volume should not exist")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 25, handler: nil)
    }
    
    func testCreateTmpfsFolders() throws {
        let volume = TmpDiskVolume(name: "testwithfolders", tmpFs: true, folders: ["folder1", "folder2/subfolder1"])
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Volume should exist")
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: "\(volume.path())/folder1"), "Volume should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: "\(volume.path())/folder2/subfolder1"), "Volume should exist")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCreateTmpfsExists() throws {
        let volume = TmpDiskVolume(name: "testexists", tmpFs: true)
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Volume should exist")
            
            TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
                XCTAssertNotNil(error)
                XCTAssertEqual(error!, TmpDiskError.exists)
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Hidden Volume Tests

    func testCreateHiddenVolumeSucceedsAndEjects() throws {
        let volume = TmpDiskVolume(name: "testhiddenvolume", hidden: true)
        let expectation = self.expectation(description: "Creating hidden volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Hidden volume should exist")
            
            // Verify the volume is not visible in Finder
            let volumeURL = URL(fileURLWithPath: volume.path())
            var resourceValues = try? volumeURL.resourceValues(forKeys: [.isHiddenKey])
            XCTAssertTrue(resourceValues?.isHidden ?? false, "Volume should be hidden")
            
            TmpDiskManager.shared.ejectTmpDisksWithName(names: [volume.name], recreate: false)
            XCTAssertFalse(TmpDiskManager.shared.exists(volume: volume), "Volume should not exist after ejection")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    // MARK: - Case Sensitive Tests

    func testCreateCaseSensitiveVolumeSucceeds() throws {
        let volume = TmpDiskVolume(name: "testcasesensitivevolume", caseSensitive: true)
        let expectation = self.expectation(description: "Creating case-sensitive volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Case-sensitive volume should exist")
            
            // Test case sensitivity by creating two files with different cases
            let lowerCasePath = "\(volume.path())/testfile"
            let upperCasePath = "\(volume.path())/TESTFILE"
            
            FileManager.default.createFile(atPath: lowerCasePath, contents: Data(), attributes: nil)
            FileManager.default.createFile(atPath: upperCasePath, contents: Data(), attributes: nil)
            
            // Both files should exist in a case-sensitive filesystem
            XCTAssertTrue(FileManager.default.fileExists(atPath: lowerCasePath), "Lowercase file should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: upperCasePath), "Uppercase file should exist")
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    // MARK: - Journaled Tests

    func testCreateJournaledVolumeSucceeds() throws {
        let volume = TmpDiskVolume(name: "testjournaledvolume", journaled: true)
        let expectation = self.expectation(description: "Creating journaled volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Journaled volume should exist")
            
            // We can't directly test if journaling is enabled, but we can check if creation succeeds
            // A more robust test would involve running diskutil info command and parsing the output
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    // MARK: - NoExec Tests

    func testCreateNoExecVolumeSucceeds() throws {
        let volume = TmpDiskVolume(name: "testnoexecvolume", noExec: true)
        let expectation = self.expectation(description: "Creating noexec volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "NoExec volume should exist")
            
            // Create a test script that should not be executable
            let scriptPath = "\(volume.path())/test.sh"
            let scriptContent = "#!/bin/bash\necho 'This should not run'\n"
            try? scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            // Make it executable (this should normally make it executable)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            
            // Try to execute it - this should fail on a noexec volume
            let process = Process()
            process.executableURL = URL(fileURLWithPath: scriptPath)
            
            do {
                try process.run()
                process.waitUntilExit()
                XCTFail("Script should not be executable on noexec volume")
            } catch {
                // Expected behavior - script execution should fail
                XCTAssertTrue(true, "Script execution failed as expected on noexec volume")
            }
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    // MARK: - Combination Tests

    func testCombinedFeaturesVolume() throws {
        let volume = TmpDiskVolume(
            name: "testcombinedvolume",
            hidden: true,
            caseSensitive: true,
            journaled: true,
            noExec: true
        )
        let expectation = self.expectation(description: "Creating combined features volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(TmpDiskManager.shared.exists(volume: volume), "Combined features volume should exist")
            
            // Check if volume is hidden
            let volumeURL = URL(fileURLWithPath: volume.path())
            var resourceValues = try? volumeURL.resourceValues(forKeys: [.isHiddenKey])
            XCTAssertTrue(resourceValues?.isHidden ?? false, "Volume should be hidden")
            
            // Test case sensitivity
            let lowerCasePath = "\(volume.path())/combinedtest"
            let upperCasePath = "\(volume.path())/COMBINEDTEST"
            
            FileManager.default.createFile(atPath: lowerCasePath, contents: Data(), attributes: nil)
            FileManager.default.createFile(atPath: upperCasePath, contents: Data(), attributes: nil)
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: lowerCasePath), "Lowercase file should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: upperCasePath), "Uppercase file should exist")
            
            // Test noexec functionality
            let scriptPath = "\(volume.path())/test.sh"
            let scriptContent = "#!/bin/bash\necho 'This should not run'\n"
            try? scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: scriptPath)
            
            do {
                try process.run()
                process.waitUntilExit()
                XCTFail("Script should not be executable on noexec volume")
            } catch {
                // Expected behavior
                XCTAssertTrue(true, "Script execution failed as expected on noexec volume")
            }
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
}
