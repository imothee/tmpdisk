//
//  TmpDiskManager.swift
//  TmpDisk
//
//  Created by @imothee on 12/11/21.
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
import AppKit

let TmpDiskHome = "\(NSHomeDirectory())/.tmpdisk"

class TmpDiskManager {
    
    static let shared: TmpDiskManager = {
        let instance = TmpDiskManager()
        // setup code
        return instance
    }()
 
    static var rootFolder = UserDefaults.standard.object(forKey: "rootFolder") as? String ?? TmpDiskHome
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
        if let vols = try? FileManager.default.contentsOfDirectory(atPath: TmpDiskManager.rootFolder) {
            for vol in vols {
                // For now we don't check if it's mounted, just check for the tmpdisk file
                let tmpdiskFilePath = "\(TmpDiskManager.rootFolder)/\(vol)/.tmpdisk"
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
        for volume in self.getAutoCreateVolumes() {
            self.createTmpDisk(volume: volume) { error in
                if let error = error {
                    // TODO: Add autocreate error
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
                    
                    let caseSensitive = vol["caseSensitive"] as? Bool ?? false
                    let journaled = vol["journaled"] as? Bool ?? false
                    let warnOnEject = vol["warnOnEject"] as? Bool ?? false
                    let folders = vol["folders"] as? [String] ?? []
                    let icon = vol["icon"] as? String
                    
                    let volume = TmpDiskVolume(
                        name: name,
                        size: size,
                        indexed: indexed,
                        hidden: hidden,
                        tmpFs: tmpFs,
                        caseSensitive: caseSensitive,
                        journaled: journaled,
                        warnOnEject: warnOnEject,
                        folders: folders,
                        icon: icon
                    )
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
        
        if Util.checkHelperVersion() != nil {
            let client = XPCClient()
//            if client.connection == nil {
//                return onCreate(.helperNotInstalled)
//            }
            
            var task: String?
            if volume.tmpFs {
                task = try? self.createTmpFsTask(volume: volume)
            } else {
                task = self.createRamDiskTask(volume: volume)
            }
            
            guard let task = task else {
                return onCreate(.failed)
            }
            
            client.createVolume(task) { error in
                if error != nil {
                    return onCreate(error)
                }
                self.diskCreated(volume: volume)
                onCreate(nil)
            }
            return
        }
        
        // Old flow without the helper installed
        
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
            self.diskCreated(volume: volume)
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
                DispatchQueue.main.async {
                    self.volumes.remove(volume)
                }
                
                if recreate {
                    self.createTmpDisk(volume: volume, onCreate: {_ in })
                }
            } catch let error as NSError {
                if error.code == fBsyErr {
                    DispatchQueue.main.async {
                        self.ejectErrorDiskInUse(name: volume.name, recreate: recreate)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.ejectError(name: volume.name)
                    }
                }
            }
            
            group.leave()
        }
        
    }
    
    func forceEject(name: String, recreate: Bool) {
        guard let volume = self.volumes.first(where: { name == $0.name }) else {
            return
        }
        
        let task = Process()
        task.launchPath = "/sbin/umount"
        
        let command = volume.path()
        task.arguments = ["-f", command]
        
        task.terminationHandler = { process in
            if process.terminationStatus != 0 {
                DispatchQueue.main.async {
                    self.ejectError(name: name)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.volumes.remove(volume)
                
                if recreate {
                    // We've force ejected so recreate the TmpDisk
                    self.createTmpDisk(volume: volume, onCreate: {_ in })
                }
            }
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
    
    func ejectErrorDiskInUse(name: String, recreate: Bool) {
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("The volume \"%@\" wasn't ejected because one or more programs may be using it", comment: ""), name)
        alert.informativeText = NSLocalizedString("To eject the disk immediately, hit the Force Eject button", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Force Eject", comment: ""))
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            self.forceEject(name: name, recreate: recreate)
        }
    }
    
    func ejectError(name: String) {
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Failed to eject \"%@\"", comment: ""), name)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
    
    func diskCreated(volume: TmpDiskVolume) {
        if let jsonData = try? JSONEncoder().encode(volume) {
            let jsonString = String(data: jsonData, encoding: .utf8)!
            try? jsonString.write(toFile: "\(volume.path())/.tmpdisk", atomically: true, encoding: .utf8)
        }
            
        if volume.indexed {
            self.indexVolume(volume: volume)
        }
        
        // Create the folders if there are any set
        self.createFolders(volume: volume)
        
        // Create the icon if there is one set
        self.createIcon(volume: volume)
        
        if volume.autoCreate {
            self.addAutoCreateVolume(volume: volume)
        }
        
        DispatchQueue.main.async {
            self.volumes.insert(volume)
        }
        NotificationCenter.default.post(name: .tmpDiskMounted, object: nil)
    }
    
    func createTmpFsTask(volume: TmpDiskVolume) throws -> String {
        // Setup the volume mount folder
        if !FileManager.default.fileExists(atPath: volume.path()) {
             try FileManager.default.createDirectory(atPath: volume.path(), withIntermediateDirectories: true, attributes: nil)
        }
        
        return "mount_tmpfs -s\(volume.size)M \(volume.path())"
    }
    
    func createRamDiskTask(volume: TmpDiskVolume) -> String {
        let dSize = UInt64(volume.size) * 2048
        
        let filesystem: String = {
            switch (volume.caseSensitive, volume.journaled) {
            case (false, false):
                return "HFS+" // Mac OS Extended
            case (true, false):
                return "HFSX" // Mac OS Extended (Case-sensitive)
            case (false, true):
                return "JHFS+" // Mac OS Extended (Journaled)
            case (true, true):
                return "JHFSX" // Mac OS Extended (Case-sensitive, Journaled)
            }
        }()
        
        if volume.hidden {
            return "d=$(hdiutil attach -nomount ram://\(dSize)) && diskutil eraseDisk \(filesystem) %noformat% $d && newfs_hfs -v \"\(volume.name)\" \"$(echo $d | tr -d ' ')s1\" && hdiutil attach -nomount $d && hdiutil attach -nobrowse \"$(echo $d | tr -d ' ')s1\""
        } else {
            return "diskutil eraseVolume \(filesystem) \"\(volume.name)\" `hdiutil attach -nomount ram://\(dSize)`"
        }
    }
    
    func createTmpFs(volume: TmpDiskVolume) throws -> Process {
        // Run the process
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        let command = try createTmpFsTask(volume: volume)
        let script = """
            do shell script "\(command)" with administrator privileges
        """

        task.arguments = ["-e", script]
        return task
    }
    
    func createRamDisk(volume: TmpDiskVolume) -> Process {
        let task = Process()
        task.launchPath = "/bin/sh"
        
        let command = createRamDiskTask(volume: volume)
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
    
    func createIcon(volume: TmpDiskVolume) {
        if let icon = volume.icon {
            if let data = Data(base64Encoded: icon) {
                let image = NSImage(data: data)
                NSWorkspace.shared.setIcon(image, forFile: volume.path())
            }
        }
    }
}
