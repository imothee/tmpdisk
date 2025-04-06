//
//  TmpDiskVolume.swift
//  TmpDisk
//
//  Created by Tim on 2/28/24.
//

import Foundation
import AppKit

struct TmpDiskVolume: Hashable, Codable {
    var name: String = ""
    var size: Int = 16
    var autoCreate: Bool = false
    var fileSystem: String
    var indexed: Bool = false
    var noExec: Bool = false
    var hidden: Bool = false
    var warnOnEject: Bool = false
    var folders: [String] = []
    var icon: String?
    var mountPoint: String?
    
    init() {
        self.fileSystem = FileSystemManager.availableFileSystems().first?.name ?? "HFS+"
    }
    
    init(name: String, size: Int) {
        self.name = name
        self.size = size
        self.fileSystem = FileSystemManager.availableFileSystems().first?.name ?? "HFS+"
    }
    
    init?(from dictionary: Dictionary<String, Any>) {
        guard let name = dictionary["name"] as? String,
              let size = dictionary["size"] as? Int,
              let indexed = dictionary["indexed"] as? Bool,
              let hidden = dictionary["hidden"] as? Bool
        else { return nil }
        
        let warnOnEject = dictionary["warnOnEject"] as? Bool ?? false
        let folders = dictionary["folders"] as? [String] ?? []
        let icon = dictionary["icon"] as? String
        let noExec = dictionary["noExec"] as? Bool ?? false
        let mountPoint = dictionary["mountPoint"] as? String
        
        let fileSystem: String
        
        if let fs = dictionary["fileSystem"] as? String {
            fileSystem = fs
        } else {
            let tmpFs = dictionary["tmpFs"] as? Bool
            let caseSensitive = dictionary["caseSensitive"] as? Bool
            let journaled = dictionary["journaled"] as? Bool
            
            // We're going to use HSF+ for legacy tmpdisks
            if tmpFs ?? false {
                fileSystem = "TMPFS"
            } else if caseSensitive ?? false && journaled ?? false {
                fileSystem = "JHFSX"
            } else if caseSensitive ?? false {
                fileSystem = "HFSX"
            } else if journaled ?? false {
                fileSystem = "JHFS+"
            } else {
                fileSystem = "HFS+"
            }
        }
        
        self.name = name
        self.size = size
        self.autoCreate = true
        self.fileSystem = fileSystem
        self.indexed = indexed
        self.hidden = hidden
        self.noExec = noExec
        self.warnOnEject = warnOnEject
        self.folders = folders
        if let icon = icon, icon != "" {
            self.icon = icon
        }
        if let mountPoint = mountPoint, mountPoint != "" {
            self.mountPoint = mountPoint
        }
    }
    
    func path() -> String {
        if let mountPoint = self.mountPoint {
            return mountPoint
        } else if FileSystemManager.isTmpFS(fileSystem) {
            return "\(TmpDiskManager.rootFolder)/\(name)"
        }
        return "/Volumes/\(name)"
    }
    
    func URL() -> URL {
        return NSURL.fileURL(withPath: self.path())
    }
    
    func dictionary() -> Dictionary<String, Any> {
        return [
            "name": name,
            "size": size,
            "indexed": indexed,
            "hidden": hidden,
            "filesystem": fileSystem,
            "noExec": noExec,
            "warnOnEject": warnOnEject,
            "folders": folders,
            "icon": icon ?? "",
            "mountPoint": mountPoint ?? ""
        ]
    }
    
    func showWarning() -> Bool {
        if warnOnEject {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: self.path()) {
                if !files.filter({ ![".DS_Store", ".tmpdisk", ".fseventsd"].contains($0) }).isEmpty {
                    return true
                }
            }
        }
        return false
    }
    
    func isMounted() -> Bool {
        let mountPoint = self.path()
        return NSWorkspace.shared.isFilePackage(atPath: mountPoint) && FileManager.default.fileExists(atPath: mountPoint)
    }
}
