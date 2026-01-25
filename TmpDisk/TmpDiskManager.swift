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

class TmpDiskManager {

    static let shared: TmpDiskManager = {
        let instance = TmpDiskManager()
        // setup code
        return instance
    }()

    /// Root folder for TMPFS volumes - uses TmpDiskConfig for consistent behavior
    static var rootFolder: String {
        return TmpDiskConfig.rootFolder
    }

    var volumes: Set<TmpDiskVolume> = []

    // Sync timers for periodic sync
    private var syncTimers: [String: Timer] = [:]

    init() {
        // Discover existing volumes using shared logic
        for volume in DiskOperations.findAllVolumes() {
            self.volumes.insert(volume)
        }

        // AutoCreate any saved TmpDisks
        for volume in self.getAutoCreateVolumes() {
            self.createTmpDisk(volume: volume) { error in
                if let error = error {
                    Logger.shared.error("Failed to auto-create volume '\(volume.name)': \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.autoCreateError(name: volume.name, error: error)
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
        let needsRoot = isTmpFS || volume.noExec

        // Use DiskOperations for command generation (include chown for privileged operations)
        let task: String
        do {
            task = isTmpFS
                ? try DiskOperations.createTmpFsCommand(volume: volume, fixOwnership: needsRoot)
                : DiskOperations.createRamDiskCommand(volume: volume, fixOwnership: needsRoot)
        } catch {
            return onCreate(.failed)
        }

        if Util.checkHelperVersion() != nil && needsRoot {
            // Run using the helper for privileged operations (TMPFS or noexec)
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

        // Run using tasks (AppleScript prompt for admin)
        self.runTask(task, needsRoot: needsRoot) { status in
            if status != 0 {
                return onCreate(.failed)
            }
            self.diskCreated(volume: volume)
            onCreate(nil)
        }
    }
    
    func ejectAllTmpDisks(recreate: Bool, onCompletion: (() -> Void)? = nil) {
        let names = self.volumes.map { $0.name }
        self.ejectTmpDisksWithName(names: names, recreate: recreate, onCompletion: onCompletion)
    }
    
    func ejectTmpDisksWithName(names: [String], recreate: Bool, force: Bool = false, onCompletion: (() -> Void)? = nil) {
        let group = DispatchGroup()
        for volume in self.volumes.filter({ names.contains($0.name) }) {
            group.enter()
            ejectVolume(volume: volume, force: force) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        if error == .inUse {
                            self.ejectErrorDiskInUse(volume: volume, recreate: recreate)
                        } else {
                            self.ejectError(name: volume.name)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.volumes.remove(volume)
                        NotificationCenter.default.post(name: .tmpDiskMounted, object: nil)
                        
                        if recreate {
                            // We've force ejected so recreate the TmpDisk
                            self.createTmpDisk(volume: volume, onCreate: {_ in })
                        } else if FileSystemManager.isTmpFS(volume.fileSystem) {
                            try? FileManager.default.removeItem(atPath: volume.path())
                        }
                    }
                }
                group.leave()
            }
        }
        if onCompletion != nil {
            group.wait()
            DispatchQueue.main.async {
                onCompletion!()
            }
        }
    }
    
    func ejectVolume(volume: TmpDiskVolume, force: Bool = false, onEjected: @escaping (TmpDiskError?) -> Void) {
        // Use DiskOperations for command generation
        let task = DiskOperations.ejectCommand(volume: volume, force: force)
        let isTmpFS = FileSystemManager.isTmpFS(volume.fileSystem)

        if Util.checkHelperVersion() != nil && isTmpFS {
            // Run using the helper
            let client = XPCClient()

            client.ejectVolume(task) { error in
                onEjected(error)
            }
            return
        }

        // We only need to do this for now if we're not using the helper
        // TODO: Move back to optionally handling workspace unmount
        self.runTask(task, needsRoot: isTmpFS) { status in
            if status == 16 {
                onEjected(TmpDiskError.inUse)
            } else if status != 0 {
                // General error (not found etc)
                onEjected(TmpDiskError.failed)
            } else {
                onEjected(nil)
            }
        }
    }
    
    // MARK: - Error handling
    
    func ejectErrorDiskInUse(volume: TmpDiskVolume, recreate: Bool) {
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("The volume \"%@\" wasn't ejected because one or more programs may be using it", comment: ""), volume.name)
        alert.informativeText = NSLocalizedString("To eject the disk immediately, hit the Force Eject button", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Force Eject", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn {
            self.ejectTmpDisksWithName(names: [volume.name], recreate: recreate, force: true)
        }
    }
    
    func ejectError(name: String) {
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Failed to eject \"%@\"", comment: ""), name)
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }

    func autoCreateError(name: String, error: TmpDiskError) {
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Failed to auto-create \"%@\"", comment: ""), name)
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
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
        // Use DiskOperations for metadata and folder creation
        DiskOperations.writeMetadata(volume: volume)

        if volume.indexed {
            self.indexVolume(volume: volume)
        }

        // Create the folders if there are any set
        DiskOperations.createFolders(volume: volume)

        // Create the icon if there is one set (AppKit-specific)
        self.createIcon(volume: volume)

        // Sync from source if configured
        if volume.hasSyncSource {
            self.syncFromSource(volume: volume)
        }

        if volume.autoCreate {
            self.addAutoCreateVolume(volume: volume)
        }

        // Start sync timer if periodic sync is configured
        if volume.hasSyncSource && volume.syncInterval > 0 {
            self.startSyncTimer(for: volume)
        }

        DispatchQueue.main.async {
            self.volumes.insert(volume)
            NotificationCenter.default.post(name: .tmpDiskMounted, object: nil)
        }
    }

    func indexVolume(volume: TmpDiskVolume) {
        // Use DiskOperations for command generation
        let task = DiskOperations.indexCommand(volume: volume)
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
        // Escape backslashes and quotes for AppleScript string
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
            do shell script "\(escapedCommand)" with administrator privileges
        """
        task.arguments = ["-e", script]
        return task
    }
    
    // MARK: - Volume Discovery

    /// Add a volume that was created externally (e.g., by CLI)
    func addExternalVolume(_ volume: TmpDiskVolume) {
        if !volumes.contains(where: { $0.name == volume.name }) {
            volumes.insert(volume)
            NotificationCenter.default.post(name: .tmpDiskMounted, object: nil)
        }
    }

    /// Check if a path is a TmpDisk volume and add it if so
    func checkForExternalTmpDisk(at path: String) {
        let tmpdiskFilePath = "\(path)/.tmpdisk"
        if FileManager.default.fileExists(atPath: tmpdiskFilePath),
           let jsonData = FileManager.default.contents(atPath: tmpdiskFilePath),
           let volume = try? JSONDecoder().decode(TmpDiskVolume.self, from: jsonData) {
            addExternalVolume(volume)
        }
    }

    // MARK: - Sync Operations

    /// Sync from source folder to RAM disk
    func syncFromSource(volume: TmpDiskVolume) {
        guard volume.hasSyncSource else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = DiskOperations.syncFromSource(volume: volume)
            if !result.success {
                Logger.shared.error("Sync from source failed for '\(volume.name)': \(result.message ?? "Unknown error")")
            } else {
                Logger.shared.info("Synced from source for '\(volume.name)'")
            }
        }
    }

    /// Sync RAM disk back to source folder
    func syncToSource(volume: TmpDiskVolume, completion: ((Bool) -> Void)? = nil) {
        guard volume.hasSyncSource else {
            completion?(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = DiskOperations.syncToSource(volume: volume)
            if !result.success {
                Logger.shared.error("Sync to source failed for '\(volume.name)': \(result.message ?? "Unknown error")")
            } else {
                Logger.shared.info("Saved '\(volume.name)' to source")
            }
            DispatchQueue.main.async {
                completion?(result.success)
            }
        }
    }

    /// Start periodic sync timer for a volume
    func startSyncTimer(for volume: TmpDiskVolume) {
        guard volume.syncInterval > 0 else { return }

        // Cancel existing timer if any
        stopSyncTimer(for: volume.name)

        let interval = TimeInterval(volume.syncInterval * 60) // Convert minutes to seconds
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.syncToSource(volume: volume, completion: nil)
        }
        syncTimers[volume.name] = timer
        Logger.shared.info("Started sync timer for '\(volume.name)' (every \(volume.syncInterval) min)")
    }

    /// Stop sync timer for a volume
    func stopSyncTimer(for name: String) {
        if let timer = syncTimers[name] {
            timer.invalidate()
            syncTimers.removeValue(forKey: name)
        }
    }

    /// Handle save-on-eject for a volume
    /// Returns true if eject should proceed, false if cancelled
    func handleSaveOnEject(volume: TmpDiskVolume, completion: @escaping (Bool) -> Void) {
        guard volume.hasSyncSource else {
            completion(true)
            return
        }

        switch volume.saveOnEject {
        case .no:
            completion(true)
        case .yes:
            syncToSource(volume: volume) { _ in
                completion(true)
            }
        case .prompt:
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = String(format: NSLocalizedString("Save changes to \"%@\"?", comment: ""), volume.name)
                alert.informativeText = String(format: NSLocalizedString("Do you want to save the contents back to \"%@\" before ejecting?", comment: ""), volume.syncSource ?? "")
                alert.alertStyle = .warning
                alert.addButton(withTitle: NSLocalizedString("Save", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Don't Save", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

                let response = alert.runModal()
                switch response {
                case .alertFirstButtonReturn:
                    // Save
                    self.syncToSource(volume: volume) { _ in
                        completion(true)
                    }
                case .alertSecondButtonReturn:
                    // Don't Save
                    completion(true)
                default:
                    // Cancel
                    completion(false)
                }
            }
        }
    }

    /// Eject with save-on-eject handling
    func ejectVolumeWithSync(volume: TmpDiskVolume, force: Bool = false, recreate: Bool = false, onEjected: @escaping (TmpDiskError?) -> Void) {
        // Stop any sync timer
        stopSyncTimer(for: volume.name)

        // Handle save-on-eject if not recreating (recreate preserves the purpose of the sync)
        if !recreate {
            handleSaveOnEject(volume: volume) { shouldProceed in
                if shouldProceed {
                    self.ejectVolume(volume: volume, force: force, onEjected: onEjected)
                } else {
                    // User cancelled - restart timer if needed
                    if volume.syncInterval > 0 {
                        self.startSyncTimer(for: volume)
                    }
                    onEjected(nil) // Not an error, just cancelled
                }
            }
        } else {
            ejectVolume(volume: volume, force: force, onEjected: onEjected)
        }
    }
}
