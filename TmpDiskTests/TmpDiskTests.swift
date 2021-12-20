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
}
