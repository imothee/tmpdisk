//
//  DiskOperations.swift
//  TmpDisk
//
//  Created by Claude on 2025.
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

/// Result of a disk operation
struct DiskOperationResult {
    let success: Bool
    let exitCode: Int32
    let error: TmpDiskError?
    let message: String?

    static func success(message: String? = nil) -> DiskOperationResult {
        DiskOperationResult(success: true, exitCode: 0, error: nil, message: message)
    }

    static func failure(_ error: TmpDiskError, message: String? = nil) -> DiskOperationResult {
        DiskOperationResult(success: false, exitCode: 1, error: error, message: message)
    }

    static func failure(exitCode: Int32, message: String? = nil) -> DiskOperationResult {
        let error: TmpDiskError = exitCode == 16 ? .inUse : .failed
        return DiskOperationResult(success: false, exitCode: exitCode, error: error, message: message)
    }
}

/// Standalone disk operations that can be used by both the GUI app and CLI
class DiskOperations {

    // MARK: - Command Generation

    /// Get the user who should own created volumes
    static var volumeOwner: String {
        if let sudoUser = ProcessInfo.processInfo.environment["SUDO_USER"] {
            return sudoUser
        }
        return NSUserName()
    }

    /// Generate the shell command to create a RAM disk
    static func createRamDiskCommand(volume: TmpDiskVolume, fixOwnership: Bool = false) -> String {
        let dSize = UInt64(volume.size) * 2048
        let fileSystem = volume.fileSystem
        let volumeName = volume.name
        let path = volume.path()

        // Resolve the correct device to mount
        let resolveMountDevice: String
        if FileSystemManager.isAPFS(fileSystem) {
            // Mount the synthesized container (diskY)
            resolveMountDevice = """
            MOUNT_DEV=$(diskutil list $DISK_ID | awk '/Apple_APFS Container/ {print $NF}') && \\
            """
        } else {
            // Mount the single HFS+ partition (diskXs2)
            resolveMountDevice = """
            MOUNT_DEV=$(diskutil list $DISK_ID | awk '/Apple_HFS/ {print $NF}') && \\
            """
        }

        // noExec requires remounting with mount -u -o noexec
        // For hidden volumes, we need to preserve nobrowse when adding noexec
        let noExecLine: String
        if volume.noExec {
            if volume.hidden {
                noExecLine = " && \\\nmount -u -o nobrowse,noexec \"\(path)\""
            } else {
                noExecLine = " && \\\nmount -u -o noexec \"\(path)\""
            }
        } else {
            noExecLine = ""
        }

        // Fix ownership if running with elevated privileges
        let chownLine: String
        if fixOwnership {
            chownLine = " && \\\n/usr/sbin/chown -R \(volumeOwner) \"\(path)\""
        } else {
            chownLine = ""
        }

        let script: String

        if FileSystemManager.isAPFS(fileSystem) || FileSystemManager.isHFS(fileSystem) {
            if volume.hidden {
                // For hidden volumes: diskutil eraseDisk auto-mounts at /Volumes/name,
                // so we unmount from there, then re-attach with -nobrowse
                if FileSystemManager.isAPFS(fileSystem) {
                    // For APFS: use the original disk ID to re-attach the whole container
                    script = """
                    DISK_ID=$(hdiutil attach -nomount ram://\(dSize)) && \\
                    diskutil eraseDisk \(fileSystem) "\(volumeName)" $DISK_ID && \\
                    diskutil unmount "/Volumes/\(volumeName)" && \\
                    hdiutil attach -nobrowse -mountpoint "\(path)" $DISK_ID\(noExecLine)\(chownLine)
                    """
                } else {
                    // For HFS+: use the specific HFS partition
                    script = """
                    DISK_ID=$(hdiutil attach -nomount ram://\(dSize)) && \\
                    diskutil eraseDisk \(fileSystem) "\(volumeName)" $DISK_ID && \\
                    \(resolveMountDevice)
                    diskutil unmount "/Volumes/\(volumeName)" && \\
                    hdiutil attach -nobrowse -mountpoint "\(path)" /dev/$MOUNT_DEV\(noExecLine)\(chownLine)
                    """
                }
            } else {
                // For non-hidden: diskutil eraseDisk mounts at /Volumes/name,
                // which is already the correct location for standard volumes
                script = """
                DISK_ID=$(hdiutil attach -nomount ram://\(dSize)) && \\
                diskutil eraseDisk \(fileSystem) "\(volumeName)" $DISK_ID\(noExecLine)\(chownLine)
                """
            }
        } else {
            // Fallback for any other filesystem
            let hiddenFlag = volume.hidden ? "-nobrowse " : ""
            script = """
            DISK_ID=$(hdiutil attach -nomount ram://\(dSize)) && \\
            diskutil eraseDisk \(fileSystem) "\(volumeName)" $DISK_ID && \\
            hdiutil attach \(hiddenFlag)-mountpoint "\(path)" $DISK_ID\(noExecLine)\(chownLine)
            """
        }

        return script
    }

    /// Generate the shell command to create a TMPFS mount
    /// Also creates the mount directory if needed
    static func createTmpFsCommand(volume: TmpDiskVolume, fixOwnership: Bool = false) throws -> String {
        // Setup the volume mount folder
        if !FileManager.default.fileExists(atPath: volume.path()) {
            try FileManager.default.createDirectory(atPath: volume.path(), withIntermediateDirectories: true, attributes: nil)
        }

        var command = "mount_tmpfs -s\(volume.size)M \(volume.noExec ? "-o noexec " : "")\(volume.path())"

        // Fix ownership if running with elevated privileges
        if fixOwnership {
            command += " && /usr/sbin/chown -R \(volumeOwner) \"\(volume.path())\""
        }

        return command
    }

    /// Generate the shell command to eject a volume
    static func ejectCommand(volume: TmpDiskVolume, force: Bool = false) -> String {
        return "/usr/bin/hdiutil detach \(force ? "-force" : "") \"\(volume.path())\""
    }

    /// Generate the shell command to enable Spotlight indexing
    static func indexCommand(volume: TmpDiskVolume) -> String {
        return "mdutil -i on \"\(volume.path())\""
    }

    // MARK: - Process Execution

    /// Create a Process configured to run a shell command
    static func shellProcess(_ command: String) -> Process {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        return task
    }

    /// Create a Process configured to run a command with admin privileges via AppleScript
    static func adminProcess(_ command: String) -> Process {
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

    /// Run a shell command synchronously
    /// - Parameters:
    ///   - command: The shell command to run
    ///   - needsRoot: Whether the command requires root privileges
    /// - Returns: The exit code of the process
    @discardableResult
    static func runSync(_ command: String, needsRoot: Bool = false) -> Int32 {
        let task: Process

        if needsRoot && !TmpDiskConfig.isRoot {
            // Need admin privileges and we're not root - use AppleScript
            task = adminProcess(command)
        } else {
            // Either we don't need root, or we're already root
            task = shellProcess(command)
        }

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return -1
        }
    }

    /// Run a shell command asynchronously
    /// - Parameters:
    ///   - command: The shell command to run
    ///   - needsRoot: Whether the command requires root privileges
    ///   - completion: Called with the exit code when the process terminates
    static func runAsync(_ command: String, needsRoot: Bool = false, completion: @escaping (Int32) -> Void) {
        let task: Process

        if needsRoot && !TmpDiskConfig.isRoot {
            // Need admin privileges and we're not root - use AppleScript
            task = adminProcess(command)
        } else {
            // Either we don't need root, or we're already root
            task = shellProcess(command)
        }

        task.terminationHandler = { process in
            completion(process.terminationStatus)
        }

        do {
            try task.run()
        } catch {
            completion(-1)
        }
    }

    // MARK: - High-Level Operations

    /// Create a volume (synchronous version for CLI)
    static func createVolumeSync(volume: TmpDiskVolume) -> DiskOperationResult {
        // Validation
        if volume.name.isEmpty {
            return .failure(.noName, message: "Volume name is required")
        }

        if volume.size <= 0 {
            return .failure(.invalidSize, message: "Volume size must be greater than 0")
        }

        if volume.isMounted() {
            return .failure(.exists, message: "Volume '\(volume.name)' already exists")
        }

        let isTmpFS = FileSystemManager.isTmpFS(volume.fileSystem)
        let needsRoot = isTmpFS || volume.noExec

        // Generate the command (include chown if running with elevated privileges)
        let command: String
        do {
            command = isTmpFS
                ? try createTmpFsCommand(volume: volume, fixOwnership: needsRoot)
                : createRamDiskCommand(volume: volume, fixOwnership: needsRoot)
        } catch {
            return .failure(.failed, message: "Failed to prepare volume: \(error.localizedDescription)")
        }

        // Execute the command
        let exitCode = runSync(command, needsRoot: needsRoot)

        if exitCode != 0 {
            return .failure(exitCode: exitCode, message: "Failed to create volume (exit code: \(exitCode))")
        }

        // Post-creation tasks
        writeMetadata(volume: volume)

        if volume.indexed {
            runSync(indexCommand(volume: volume))
        }

        createFolders(volume: volume)

        if volume.autoCreate {
            addToAutoCreate(volume: volume)
        }

        return .success(message: "Volume '\(volume.name)' created at \(volume.path())")
    }

    /// Eject a volume (synchronous version for CLI)
    static func ejectVolumeSync(volume: TmpDiskVolume, force: Bool = false) -> DiskOperationResult {
        let isTmpFS = FileSystemManager.isTmpFS(volume.fileSystem)
        let command = ejectCommand(volume: volume, force: force)
        let exitCode = runSync(command, needsRoot: isTmpFS)

        if exitCode == 16 {
            return .failure(.inUse, message: "Volume '\(volume.name)' is in use")
        } else if exitCode != 0 {
            return .failure(exitCode: exitCode, message: "Failed to eject volume (exit code: \(exitCode))")
        }

        // Clean up TMPFS mount directory
        if isTmpFS {
            try? FileManager.default.removeItem(atPath: volume.path())
        }

        return .success(message: "Volume '\(volume.name)' ejected")
    }

    /// Eject a volume by name (synchronous version for CLI)
    static func ejectVolumeByName(_ name: String, force: Bool = false) -> DiskOperationResult {
        // Find the volume
        if let volume = findVolumeByName(name) {
            return ejectVolumeSync(volume: volume, force: force)
        }

        // Try creating a volume object for the path and eject it
        let volume = TmpDiskVolume(name: name, size: 0)
        if volume.isMounted() {
            return ejectVolumeSync(volume: volume, force: force)
        }

        return .failure(.failed, message: "Volume '\(name)' not found")
    }

    // MARK: - Metadata and Folders

    /// Write the .tmpdisk metadata file to the volume
    static func writeMetadata(volume: TmpDiskVolume) {
        let metadataPath = "\(volume.path())/.tmpdisk"

        // Retry a few times - volume permissions may not be ready immediately after mount
        for attempt in 1...3 {
            do {
                let jsonData = try JSONEncoder().encode(volume)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    try jsonString.write(toFile: metadataPath, atomically: true, encoding: .utf8)
                    return // Success
                }
            } catch {
                if attempt < 3 {
                    // Wait a bit for the volume to be fully ready
                    Thread.sleep(forTimeInterval: 0.5)
                } else {
                    fputs("Warning: Failed to write metadata for volume '\(volume.name)': \(error.localizedDescription)\n", stderr)
                }
            }
        }
    }

    /// Create folders within the volume
    static func createFolders(volume: TmpDiskVolume) {
        for folder in volume.folders {
            let path = "\(volume.path())/\(folder)"
            if !FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    fputs("Warning: Failed to create folder '\(folder)' in volume '\(volume.name)': \(error.localizedDescription)\n", stderr)
                }
            }
        }
    }

    // MARK: - AutoCreate Management

    /// Add a volume to the autocreate list
    static func addToAutoCreate(volume: TmpDiskVolume) {
        let defaults = TmpDiskConfig.appDefaults

        var autoCreate = defaults.array(forKey: "autoCreate") as? [[String: Any]] ?? []

        // Remove existing entry with same name if present
        autoCreate.removeAll { ($0["name"] as? String) == volume.name }

        // Add the new volume
        autoCreate.append(volume.dictionary())
        defaults.set(autoCreate, forKey: "autoCreate")
        defaults.synchronize()
    }

    /// Remove a volume from the autocreate list
    static func removeFromAutoCreate(name: String) {
        let defaults = TmpDiskConfig.appDefaults

        var autoCreate = defaults.array(forKey: "autoCreate") as? [[String: Any]] ?? []
        autoCreate.removeAll { ($0["name"] as? String) == name }
        defaults.set(autoCreate, forKey: "autoCreate")
        defaults.synchronize()
    }

    // MARK: - Volume Discovery

    /// Find all mounted TmpDisk volumes
    static func findAllVolumes() -> [TmpDiskVolume] {
        var volumes: [TmpDiskVolume] = []

        // Check /Volumes for RAM disks
        if let vols = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes") {
            for vol in vols {
                let tmpdiskFilePath = "/Volumes/\(vol)/.tmpdisk"
                if FileManager.default.fileExists(atPath: tmpdiskFilePath),
                   let jsonData = FileManager.default.contents(atPath: tmpdiskFilePath),
                   let volume = try? JSONDecoder().decode(TmpDiskVolume.self, from: jsonData) {
                    volumes.append(volume)
                }
            }
        }

        // Check TMPFS root folder
        let rootFolder = TmpDiskConfig.rootFolder
        if let vols = try? FileManager.default.contentsOfDirectory(atPath: rootFolder) {
            for vol in vols {
                let tmpdiskFilePath = "\(rootFolder)/\(vol)/.tmpdisk"
                if FileManager.default.fileExists(atPath: tmpdiskFilePath),
                   let jsonData = FileManager.default.contents(atPath: tmpdiskFilePath),
                   let volume = try? JSONDecoder().decode(TmpDiskVolume.self, from: jsonData) {
                    // Avoid duplicates
                    if !volumes.contains(where: { $0.name == volume.name }) {
                        volumes.append(volume)
                    }
                }
            }
        }

        return volumes
    }

    /// Find a volume by name
    static func findVolumeByName(_ name: String) -> TmpDiskVolume? {
        return findAllVolumes().first { $0.name == name }
    }

    // MARK: - Sync Operations

    /// Sync from source folder to RAM disk (load)
    /// Uses rsync to copy contents from syncSource to the volume
    static func syncFromSource(volume: TmpDiskVolume) -> DiskOperationResult {
        guard let source = volume.syncSource, !source.isEmpty else {
            return .failure(.failed, message: "No sync source configured")
        }

        guard volume.isMounted() else {
            return .failure(.failed, message: "Volume is not mounted")
        }

        // Ensure source path ends with / to copy contents, not the folder itself
        let sourcePath = source.hasSuffix("/") ? source : source + "/"
        let destPath = volume.path() + "/"

        // Use rsync to copy from source to volume
        // -a = archive mode (preserves permissions, times, etc.)
        // -v = verbose
        // --delete = delete files in dest that don't exist in source
        // --exclude = skip .tmpdisk metadata file
        let command = "/usr/bin/rsync -av --exclude='.tmpdisk' \"\(sourcePath)\" \"\(destPath)\""

        let exitCode = runSync(command, needsRoot: false)

        if exitCode != 0 {
            return .failure(exitCode: exitCode, message: "Failed to sync from source (exit code: \(exitCode))")
        }

        return .success(message: "Synced from '\(source)' to '\(volume.name)'")
    }

    /// Sync from RAM disk back to source folder (save)
    /// Uses rsync to copy contents from volume back to syncSource
    static func syncToSource(volume: TmpDiskVolume) -> DiskOperationResult {
        guard let source = volume.syncSource, !source.isEmpty else {
            return .failure(.failed, message: "No sync source configured")
        }

        guard volume.isMounted() else {
            return .failure(.failed, message: "Volume is not mounted")
        }

        // Ensure paths end with / for rsync
        let sourcePath = volume.path() + "/"
        let destPath = source.hasSuffix("/") ? source : source + "/"

        // Use rsync to copy from volume back to source
        // -a = archive mode (preserves permissions, times, etc.)
        // -v = verbose
        // --delete = delete files in dest that don't exist in source
        // --exclude = skip .tmpdisk metadata file and system files
        let command = "/usr/bin/rsync -av --delete --exclude='.tmpdisk' --exclude='.DS_Store' --exclude='.fseventsd' \"\(sourcePath)\" \"\(destPath)\""

        let exitCode = runSync(command, needsRoot: false)

        if exitCode != 0 {
            return .failure(exitCode: exitCode, message: "Failed to sync to source (exit code: \(exitCode))")
        }

        return .success(message: "Saved '\(volume.name)' to '\(source)'")
    }

    /// Save a volume by name (sync back to source)
    static func saveVolumeByName(_ name: String) -> DiskOperationResult {
        guard let volume = findVolumeByName(name) else {
            return .failure(.failed, message: "Volume '\(name)' not found")
        }

        return syncToSource(volume: volume)
    }
}
