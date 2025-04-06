//
//  FileSystemManager.swift
//  TmpDisk
//
//  Created by Tim on 4/3/25.
//
//  This file is part of TmpDisk.
//
//  TmpDisk is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TmpDisk is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TmpDisk.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

struct FileSystemType: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: FileSystemType, rhs: FileSystemType) -> Bool {
        return lhs.name == rhs.name
    }
}

class FileSystemManager {
    // All filesystem types with descriptions
    private static let allFileSystems: [FileSystemType] = [
        FileSystemType(name: "APFS", description: "Apple File System - Suggested"),
        FileSystemType(name: "APFSX", description: "Apple File System (Case Sensitive)"),
        FileSystemType(name: "HFS+", description: "Mac OS Extended - Legacy"),
        FileSystemType(name: "TMPFS", description: "TmpFS - Requires Admin or TmpDisk Helper"),
        FileSystemType(name: "HFSX", description: "Mac OS Extended (Case-sensitive)"),
        FileSystemType(name: "JHFS+", description: "Mac OS Extended (Journaled)"),
        FileSystemType(name: "JHFSX", description: "Mac OS Extended (Case-sensitive, Journaled)"),
    ]
    
    // Get filesystem types appropriate for the current OS version
    static func availableFileSystems() -> [FileSystemType] {
        var available = allFileSystems
        
        if #available(macOS 10.13, *) {
            // Keep APFS for macOS 10.13+ (High Sierra and later)
        } else {
            // Remove APFS from available options for earlier macOS versions
            available.removeAll { $0.name == "APFS" || $0.name == "APFSX" }
        }
        
        return available
    }
    
    // Get the descriptions of avaialable file systems
    static func availableFileSystemDescriptions() -> [String] {
        return availableFileSystems().map(\.self.description)
    }
    
    static func isTmpFS(_ fileSystemName: String) -> Bool {
        return fileSystemName == "TMPFS"
    }
    
    static func isAPFS(_ fileSystemName: String) -> Bool {
        return fileSystemName == "APFS" || fileSystemName == "APFSX"
    }
    
    static func description(for fileSystemName: String) -> String? {
        return availableFileSystems().first(where: { $0.name == fileSystemName })?.description
    }
}
