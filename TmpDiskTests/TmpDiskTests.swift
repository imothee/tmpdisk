//
//  TmpDiskTests.swift
//  TmpDiskTests
//
//  Created by Tim on 12/11/21.
//

import XCTest
@testable import TmpDisk

class TmpDiskTests: XCTestCase {

    func testCreateTmpDiskNoName() throws {
        let volume = TmpDiskVolume()
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNotNil(error)
            XCTAssertEqual(error!, TmpDiskError.noName)
        }
    }
    
    // MARK: - TmpDisk
    
    func testCreateTmpDiskSucceedsAndEjects() throws {
        let volume = TmpDiskVolume(name: "testvolume", size: 8)
        let expectation = self.expectation(description: "Creating")
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "Volume should exist")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                XCTAssertNil(error)
                XCTAssertFalse(volume.isMounted(), "Volume should not exist")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCreateFolders() throws {
        var volume = TmpDiskVolume(name: "testwithfolders", size: 8)
        volume.folders = ["folder1", "folder2/subfolder1"]
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "Volume should exist")
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: "\(volume.path())/folder1"), "Volume should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: "\(volume.path())/folder2/subfolder1"), "Volume should exist")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCreateAlreadyExists() throws {
        let volume = TmpDiskVolume(name: "testexists", size: 8)
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "Volume should exist")
            
            TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
                XCTAssertNotNil(error)
                XCTAssertEqual(error!, TmpDiskError.exists)
                
                TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                    expectation.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Tmpfs
    
    func testCreateTmpfsSucceedsAndEjects() throws {
        let volume = TmpDiskVolume(name: "testtmpfsvolume", size: 8, fileSystem: "TMPFS")
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            sleep(1)
            XCTAssertTrue(volume.isMounted(), "Volume should exist")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                XCTAssertNil(error)
                XCTAssertFalse(volume.isMounted(), "Volume should not exist")
                try? FileManager.default.removeItem(atPath: volume.path())
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 25, handler: nil)
    }
    
    func testCreateTmpfsFolders() throws {
        var volume = TmpDiskVolume(name: "testtmpfsvolumefolders", size: 8, fileSystem: "TMPFS")
        volume.folders = ["folder1", "folder2/subfolder1"]
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            sleep(1)
            XCTAssertTrue(volume.isMounted(), "Volume should exist")
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: "\(volume.path())/folder1"), "Volume should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: "\(volume.path())/folder2/subfolder1"), "Volume should exist")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                try? FileManager.default.removeItem(atPath: volume.path())
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCreateTmpfsExists() throws {
        let volume = TmpDiskVolume(name: "testexists", size: 8, fileSystem: "TMPFS")
        let expectation = self.expectation(description: "Creating")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            sleep(1)
            XCTAssertTrue(volume.isMounted(), "Volume should exist")
            
            TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
                XCTAssertNotNil(error)
                XCTAssertEqual(error!, TmpDiskError.exists)
                
                TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                    try? FileManager.default.removeItem(atPath: volume.path())
                    expectation.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Hidden Volume Tests

    func testCreateHiddenVolumeSucceedsAndEjectsAPFS() throws {
        var volume = TmpDiskVolume(name: "testhiddenvolume", size: 8)
        volume.hidden = true
        let expectation = self.expectation(description: "Creating hidden volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "Hidden volume should exist")
            
            XCTAssertTrue(Util.isMountedWith(path: volume.path(), flags: ["nobrowse"]), "Hidden volume should not be browsable")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                XCTAssertFalse(volume.isMounted(), "Volume should not exist after ejection")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCreateHiddenVolumeSucceedsAndEjectsHFS() throws {
        var volume = TmpDiskVolume(name: "testhiddenvolume", size: 8, fileSystem: "HFS+")
        volume.hidden = true
        let expectation = self.expectation(description: "Creating hidden volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "Hidden volume should exist")
            
            XCTAssertTrue(Util.isMountedWith(path: volume.path(), flags: ["nobrowse"]), "Hidden volume should not be browsable")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                XCTAssertFalse(volume.isMounted(), "Volume should not exist after ejection")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    // MARK: - Case Sensitive Tests

    func testCreateCaseSensitiveAPFSVolumeSucceeds() throws {
        let volume = TmpDiskVolume(name: "testcasesensitivevolume", size: 8, fileSystem: "APFSX")
        let expectation = self.expectation(description: "Creating case-sensitive volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "Case-sensitive volume should exist")
            
            // Test case sensitivity by creating two files with different cases
            let lowerCasePath = "\(volume.path())/testfile"
            let upperCasePath = "\(volume.path())/TESTFILE"
            
            FileManager.default.createFile(atPath: lowerCasePath, contents: Data(), attributes: nil)
            FileManager.default.createFile(atPath: upperCasePath, contents: Data(), attributes: nil)
            
            // Both files should exist in a case-sensitive filesystem
            XCTAssertTrue(FileManager.default.fileExists(atPath: lowerCasePath), "Lowercase file should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: upperCasePath), "Uppercase file should exist")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCreateCaseSensitiveHFSVolumeSucceeds() throws {
        let volume = TmpDiskVolume(name: "testcasesensitivevolume", size: 8, fileSystem: "HFSX")
        let expectation = self.expectation(description: "Creating case-sensitive volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "Case-sensitive volume should exist")
            
            // Test case sensitivity by creating two files with different cases
            let lowerCasePath = "\(volume.path())/testfile"
            let upperCasePath = "\(volume.path())/TESTFILE"
            
            FileManager.default.createFile(atPath: lowerCasePath, contents: Data(), attributes: nil)
            FileManager.default.createFile(atPath: upperCasePath, contents: Data(), attributes: nil)
            
            // Both files should exist in a case-sensitive filesystem
            XCTAssertTrue(FileManager.default.fileExists(atPath: lowerCasePath), "Lowercase file should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: upperCasePath), "Uppercase file should exist")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - NoExec Tes ts

    func testCreateNoExecVolumeSucceeds() throws {
        var volume = TmpDiskVolume(name: "testnoexecvolume", size: 8)
        volume.noExec = true
        let expectation = self.expectation(description: "Creating noexec volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "NoExec volume should exist")
            
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
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    // MARK: - NoExec and Hidden
    
    func testNoExecAndHiddenVolumeSucceedsAPFS() throws {
        var volume = TmpDiskVolume(name: "testnoexecandhiddenvolume", size: 8)
        volume.noExec = true
        volume.hidden = true
        let expectation = self.expectation(description: "Creating noexec and hidden volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "NoExec and hidden volume should exist")
            
            XCTAssertTrue(Util.isMountedWith(path: volume.path(), flags: ["nobrowse", "noexec"]), "Volume should have nobrowse and noexec")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testNoExecAndHiddenVolumeSucceedsHFS() throws {
        var volume = TmpDiskVolume(name: "testnoexecandhiddenvolume", size: 8, fileSystem: "HFS+")
        volume.noExec = true
        volume.hidden = true
        let expectation = self.expectation(description: "Creating noexec and hidden volume")
        
        TmpDiskManager.shared.createTmpDisk(volume: volume) {error in
            XCTAssertNil(error)
            XCTAssertTrue(volume.isMounted(), "NoExec and hidden volume should exist")
            
            XCTAssertTrue(Util.isMountedWith(path: volume.path(), flags: ["nobrowse", "noexec"]), "Volume should have nobrowse and noexec")
            
            TmpDiskManager.shared.ejectVolume(volume: volume) { error in
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
}
