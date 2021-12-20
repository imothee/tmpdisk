//
//  TmpDiskManager.swift
//  TmpDisk
//
//  Created by Tim on 12/11/21.
//

import Foundation
import AppKit

let TmpDiskHome = "\(NSHomeDirectory())/.tmpdisk"

struct TmpDiskVolume: Hashable, Codable {
    var name: String = ""
    var size: Int = 16
    var autoCreate: Bool = false
    var indexed: Bool = false
    var hidden: Bool = false
    var tmpFs: Bool = false
    var folders: [String] = []
    
    func path() -> String {
        if tmpFs {
            return "\(TmpDiskHome)/volumes/\(name)"
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
            "tmpFs": tmpFs,
            "folders": folders
        ]
    }
}

enum TmpDiskError: Error {
    case noName
    case exists
    case invalidSize
    case failed
}

class TmpDiskManager {
    
    static let shared: TmpDiskManager = {
        let instance = TmpDiskManager()
        // setup code
        return instance
    }()
 
    var volumes: Set<TmpDiskVolume> = []
    
    init() {
        // Check for existing tmpdisks
        if let vols = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes") {
            for vol in vols {
                let tmpdiskFilePath = "/Volumes/\(vol)/.tmpdisk"
                if FileManager.default.fileExists(atPath: tmpdiskFilePath) {
                    if let jsonData = FileManager.default.contents(atPath: tmpdiskFilePath) {
                        if let volume = try? JSONDecoder().decode(TmpDiskVolume.self, from: jsonData) {
                            self.volumes.insert(volume)
                        }
                    }
                }
            }
        }
        
        // Check for existing tmpfs
        if let vols = try? FileManager.default.contentsOfDirectory(atPath: "\(TmpDiskHome)/volumes") {
            for vol in vols {
                // For now we don't check if it's mounted, just check for the tmpdisk file
                let tmpdiskFilePath = "\(TmpDiskHome)/volumes/\(vol)/.tmpdisk"
                if FileManager.default.fileExists(atPath: tmpdiskFilePath) {
                    if let jsonData = FileManager.default.contents(atPath: tmpdiskFilePath) {
                        if let volume = try? JSONDecoder().decode(TmpDiskVolume.self, from: jsonData) {
                            self.volumes.insert(volume)
                        }
                    }
                }
            }
        }
        
        // AutoCreate any saved TmpDisks
        if let autoCreate = UserDefaults.standard.object(forKey: "autoCreate") as? [Dictionary<String, Any>] {
            for vol in autoCreate {
                if let name = vol["name"] as? String, let size = vol["size"] as? Int, let indexed = vol["indexed"] as? Bool, let hidden = vol["hidden"] as? Bool, let tmpFs = vol["tmpFs"] as? Bool {
                
                    let folders = vol["folders"] as? [String] ?? []
                    
                    let volume = TmpDiskVolume(name: name, size: size, indexed: indexed, hidden: hidden, tmpFs: tmpFs, folders: folders)
                    self.createTmpDisk(volume: volume) { error in
                        if let error = error {
                            // TODO: Add autocreate error
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - TmpDiskManager API
    
    func getAutoCreateVolumes() -> Set<TmpDiskVolume> {
        var autoCreateVolumes: Set<TmpDiskVolume> = []
        if let autoCreate = UserDefaults.standard.object(forKey: "autoCreate") as? [Dictionary<String, Any>] {
            for vol in autoCreate {
                if let name = vol["name"] as? String, let size = vol["size"] as? Int, let indexed = vol["indexed"] as? Bool, let hidden = vol["hidden"] as? Bool, let tmpFs = vol["tmpFs"] as? Bool {
                
                    let folders = vol["folders"] as? [String] ?? []
                    
                    let volume = TmpDiskVolume(name: name, size: size, indexed: indexed, hidden: hidden, tmpFs: tmpFs, folders: folders)
                    autoCreateVolumes.insert(volume)
                }
            }
        }
        return autoCreateVolumes
    }
    
    func addAutoCreateVolume(volume: TmpDiskVolume) {
        var autoCreateVolumes = self.getAutoCreateVolumes()
        autoCreateVolumes.insert(volume)
        self.saveAutoCreateVolumes(volumes: autoCreateVolumes)
    }
    
    func saveAutoCreateVolumes(volumes: Set<TmpDiskVolume>) {
        let value = volumes.map { $0.dictionary() }
        UserDefaults.standard.set(value, forKey: "autoCreate")
    }
    
    func createTmpDisk(volume: TmpDiskVolume, onCreate: @escaping (TmpDiskError?) -> Void) {
        if volume.name.isEmpty  {
            return onCreate(.noName)
        }
        
        if volume.size <= 0 {
            return onCreate(.invalidSize)
        }
        
        if volumes.contains(where: { $0.name == volume.name }) || self.exists(volume: volume) {
            return onCreate(.exists)
        }
        
        let task: Process?
        if volume.tmpFs {
            task = try? self.createTmpFs(volume: volume)
        } else {
            task = self.createRamDisk(volume: volume)
        }
        
        guard let task = task else {
            return onCreate(.failed)
        }
        
        task.terminationHandler = { process in
            if process.terminationStatus != 0 {
                return onCreate(.failed)
            }
            
            if let jsonData = try? JSONEncoder().encode(volume) {
                let jsonString = String(data: jsonData, encoding: .utf8)!
                try? jsonString.write(toFile: "\(volume.path())/.tmpdisk", atomically: true, encoding: .utf8)
            }
                
            if volume.indexed {
                self.indexVolume(volume: volume)
            }
            
            self.createFolders(volume: volume)
            
            if volume.autoCreate {
                self.addAutoCreateVolume(volume: volume)
            }
            
            self.volumes.insert(volume)
            NotificationCenter.default.post(name: .tmpDiskMounted, object: nil)
            onCreate(nil)
        }
        if #available(macOS 10.13, *) {
            do {
                try task.run()
            } catch {
                print(error)
            }
        } else {
            task.launch()
        }
    }
    
    func ejectAllTmpDisks(recreate: Bool) {
        let names = self.volumes.map { $0.name }
        self.ejectTmpDisksWithName(names: names, recreate: recreate)
    }
    
    func ejectTmpDisksWithName(names: [String], recreate: Bool) {
        let group = DispatchGroup()
        for volume in self.volumes.filter({ names.contains($0.name) }) {
            group.enter()
            
            let ws = NSWorkspace()
            do {
                try ws.unmountAndEjectDevice(at: volume.URL())
                if volume.tmpFs {
                    try FileManager.default.removeItem(atPath: volume.path())
                }
            } catch {
                print(error)
            }
            
            self.volumes.remove(volume)
            
            if recreate {
                self.createTmpDisk(volume: volume, onCreate: {_ in })
            }
            group.leave()
        }
        
    }
    
    /*
     diskEjected takes a path and checks to see if it's a TmpDisk
     If it is, remove it from the volumes and return true so we can refresh the menubar
     */
    func diskEjected(path: String) -> Bool {
        for volume in self.volumes {
            if volume.path() == path {
                self.volumes.remove(volume)
                return true
            }
        }
        return false
    }
    
    // MARK: - Helper functions
    
    func createTmpFs(volume: TmpDiskVolume) throws -> Process {
        // Setup the volume mount folder
        if !FileManager.default.fileExists(atPath: volume.path()) {
             try FileManager.default.createDirectory(atPath: volume.path(), withIntermediateDirectories: true, attributes: nil)
        }
        
        // Run the process
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        let command = "mount_tmpfs -s\(volume.size)M \(volume.path())"
        
        let script = """
        tell application "Terminal"
            do shell script "\(command)" with administrator privileges
            quit
        end tell
        """
        
        task.arguments = ["-e", script]
        return task
    }
    
    func createRamDisk(volume: TmpDiskVolume) -> Process {
        let task = Process()
        task.launchPath = "/bin/sh"
        
        let dSize = UInt64(volume.size) * 2048
        
        let command: String
        if volume.hidden {
            command = "d=$(hdiutil attach -nomount ram://\(dSize)) && diskutil eraseDisk HFS+ %noformat% $d && newfs_hfs -v \"\(volume.name)\" \"$(echo $d | tr -d ' ')s1\" && hdiutil attach -nomount $d && hdiutil attach -nobrowse \"$(echo $d | tr -d ' ')s1\""
        } else {
            command = "diskutil eraseVolume HFS+ \"\(volume.name)\" `hdiutil attach -nomount ram://\(dSize)`"
        }
        
        print(command)
        
        task.arguments = ["-c", command]
        return task
    }
    
    func createFolders(volume: TmpDiskVolume) {
        for folder in volume.folders {
            let path = "\(volume.path())/\(folder)"
            if !FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    
    func indexVolume(volume: TmpDiskVolume) {
        let task = Process()
        task.launchPath = "/bin/sh"
        
        let command = "mdutil -i on \(volume.path())"
        task.arguments = ["-c", command]
        task.launch()
    }
    
    func exists(volume: TmpDiskVolume) -> Bool {
        if volume.tmpFs {
            // TODO: lookup mount instead of just the tmpdisk file
            return FileManager.default.fileExists(atPath: "\(volume.path())/.tmpdisk")
        }
        return FileManager.default.fileExists(atPath: volume.path())
    }
    
}
