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
                // TODO: Add autocreate error
            }
        }
    }
    
    // MARK: - TmpDiskManager API
    
    func getAutoCreateVolumes() -> Set<TmpDiskVolume> {
        var autoCreateVolumes: Set<TmpDiskVolume> = []
        if let autoCreate = UserDefaults.standard.object(forKey: "autoCreate") as? [Dictionary<String, Any>] {
            for vol in autoCreate {
                if let volume = TmpDiskVolume(from: vol) {
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
        
        if volumes.contains(where: { $0.name == volume.name || $0.path() == volume.path() }) || volume.isMounted() {
            return onCreate(.exists)
        }
        
        let isTmpFS = FileSystemManager.isTmpFS(volume.fileSystem)
        
        let task = isTmpFS ? try? self.createTmpFsTask(volume: volume) : self.createRamDiskTask(volume: volume)
        
        guard let task = task else {
            return onCreate(.failed)
        }
        
        if Util.checkHelperVersion() != nil && isTmpFS {
            // Run using the helper only for TmpFS
            let client = XPCClient()
            
            client.createVolume(task) { error in
                if error != nil {
                    return onCreate(error)
                }
                self.diskCreated(volume: volume)
                onCreate(nil)
            }
            return
        }
        
        // Run using tasks
        self.runTask(task, needsRoot: FileSystemManager.isTmpFS(volume.fileSystem)) { status in
            if status != 0 {
                return onCreate(.failed)
            }
            self.diskCreated(volume: volume)
            onCreate(nil)
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
            ejectVolume(volume: volume, recreate: recreate)
            group.leave()
        }
        
    }
    
    func ejectVolume(volume: TmpDiskVolume, recreate: Bool, force: Bool = false) {
        let task = self.ejectTask(volume: volume, force: force)
        let isTmpFS = FileSystemManager.isTmpFS(volume.fileSystem)
        
        let onEjected: () -> Void = {
            DispatchQueue.main.async {
                self.volumes.remove(volume)
                
                if recreate {
                    // We've force ejected so recreate the TmpDisk
                    self.createTmpDisk(volume: volume, onCreate: {_ in })
                } else if isTmpFS {
                    try? FileManager.default.removeItem(atPath: volume.path())
                }
                NotificationCenter.default.post(name: .tmpDiskMounted, object: nil)
            }
        }
        
        if Util.checkHelperVersion() != nil && isTmpFS {
            // Run using the helper
            let client = XPCClient()
            
            client.ejectVolume(task) { error in
                if let error = error {
                    if error == .inUse {
                        DispatchQueue.main.async {
                            self.ejectErrorDiskInUse(volume: volume, recreate: recreate)
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self.ejectError(name: volume.name)
                    }
                    return
                }
                onEjected()
            }
            return
        }
        
        // We only need to do this for now if we're not using the helper
        // TODO: Move back to optioanlly handling workspace unmount
        self.runTask(task, needsRoot: isTmpFS) { status in
            if status == 16 {
                // Disk in use
                DispatchQueue.main.async {
                    self.ejectErrorDiskInUse(volume: volume, recreate: recreate)
                }
                return
            } else if status != 0 {
                // General error (not found etc)
                DispatchQueue.main.async {
                    self.ejectError(name: volume.name)
                }
                return
            }
            onEjected()
        }
    }
    
    // MARK: - Error handling
    
    func ejectErrorDiskInUse(volume: TmpDiskVolume, recreate: Bool) {
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("The volume \"%@\" wasn't ejected because one or more programs may be using it", comment: ""), volume.name)
        alert.informativeText = NSLocalizedString("To eject the disk immediately, hit the Force Eject button", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Force Eject", comment: ""))
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            self.ejectVolume(volume: volume, recreate: recreate, force: true)
        }
    }
    
    func ejectError(name: String) {
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Failed to eject \"%@\"", comment: ""), name)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Helper functions
    
    /*
     diskEjected takes a path and checks to see if it's a TmpDisk
     If it is, remove it from the volumes and return true so we can refresh the menubar
     */
    func diskEjected(path: String) -> Bool {
        for volume in self.volumes {
            if volume.path().lowercased() == path.lowercased() {
                self.volumes.remove(volume)
                return true
            }
        }
        return false
    }
    
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
    
    func createFolders(volume: TmpDiskVolume) {
        for folder in volume.folders {
            let path = "\(volume.path())/\(folder)"
            if !FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    
    func indexVolume(volume: TmpDiskVolume) {
        let task = self.indexTask(volume: volume)
        self.runTask(task) { _ in }
    }
    
    func createIcon(volume: TmpDiskVolume) {
        if let icon = volume.icon {
            if let data = Data(base64Encoded: icon) {
                let image = NSImage(data: data)
                NSWorkspace.shared.setIcon(image, forFile: volume.path())
            }
        }
    }
    
    // MARK: - Task Runner
    
    func runTask(_ command: String, needsRoot: Bool = false, onTermination: @escaping (Int32) -> Void) {
        let task = needsRoot ? self.runAppleScript(command) : self.runShell(command)
        task.terminationHandler = { process in
            onTermination(process.terminationStatus)
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
    
    func runShell(_ command: String) -> Process {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        return task
    }
    
    func runAppleScript(_ command: String) -> Process {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        let script = """
            do shell script "\(command)" with administrator privileges
        """
        task.arguments = ["-e", script]
        return task
    }
    
    // MARK: - Tasks
    
    func ejectTask(volume: TmpDiskVolume, force: Bool) -> String {
        return "/usr/bin/hdiutil detach \(force ? "-force" : "") \"\(volume.path())\""
    }
    
    func indexTask(volume: TmpDiskVolume) -> String {
        return "mdutil -i on \"\(volume.path())\""
    }
    
    func createTmpFsTask(volume: TmpDiskVolume) throws -> String {
        // Setup the volume mount folder
        if !FileManager.default.fileExists(atPath: volume.path()) {
             try FileManager.default.createDirectory(atPath: volume.path(), withIntermediateDirectories: true, attributes: nil)
        }
        
        return "mount_tmpfs -s\(volume.size)M \(volume.noExec ? "-o noexec " : "")\(volume.path())"
    }
    
    func createRamDiskTask(volume: TmpDiskVolume) -> String {
        let dSize = UInt64(volume.size) * 2048
        
        let fileSystem = volume.fileSystem
        
        let format: String
        if FileSystemManager.isAPFS(fileSystem) {
            format = "newfs_apfs -v \"\(volume.name)\" \"$(echo $DISK_ID | tr -d ' ')s1\" && \\"
        } else {
            format = "newfs_hfs -v \"\(volume.name)\" \"$(echo $DISK_ID | tr -d ' ')s1\" && \\"
        }
        
        let path = volume.path()
        
        let attach: String
        if volume.noExec && volume.hidden {
            attach = """
            hdiutil attach -nomount $DISK_ID && \\
            mount -t hfs,apfs -o noexec,nobrowse "$(echo $DISK_ID | tr -d ' ')s1" \(path)
            """
        } else if volume.noExec {
            attach = """
            hdiutil attach $DISK_ID -mountpoint "\(path)" && \\
            mount -u -t hfs,apfs -o noexec "$(echo $DISK_ID | tr -d ' ')s1" \(path)
            """
        } else if volume.hidden {
            attach = """
            hdiutil attach -nomount $DISK_ID && \\
            hdiutil attach -nobrowse -mountpoint "\(path)" $DISK_ID
            """
        } else {
            attach = "hdiutil attach -mountpoint \"\(path)\" $DISK_ID"
        }
        
        
        return """
        DISK_ID=$(hdiutil attach -nomount ram://\(dSize)) && \\
        diskutil eraseDisk \(fileSystem) %noformat% $DISK_ID && \\
        \(format)
        \(attach)
        """
    }
}
