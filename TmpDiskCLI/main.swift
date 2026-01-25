//
//  main.swift
//  TmpDiskCLI
//
//  Created by Tim on 4/6/25.
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

// Parse command line arguments
let options = parseArguments(CommandLine.arguments)

// Execute the appropriate command
switch options.command {
case .help:
    printHelp()
    exit(0)

case .list:
    executeList()

case .eject:
    executeEject(options: options)

case .save:
    executeSave(options: options)

case .create:
    executeCreate(options: options)
}

// MARK: - Command Implementations

func executeList() {
    let volumes = DiskOperations.findAllVolumes()

    if volumes.isEmpty {
        print("No TmpDisk volumes found.")
        exit(0)
    }

    print("TmpDisk Volumes:")
    print(String(repeating: "-", count: 70))

    for volume in volumes {
        let mounted = volume.isMounted() ? "mounted" : "not mounted"
        let flags = buildFlagString(for: volume)
        print("  \(volume.name)")
        print("    Path: \(volume.path())")
        print("    Size: \(volume.size)MB, FS: \(volume.fileSystem), Status: \(mounted)")
        if !flags.isEmpty {
            print("    Flags: \(flags)")
        }
        print()
    }

    exit(0)
}

func buildFlagString(for volume: TmpDiskVolume) -> String {
    var flags: [String] = []
    if volume.autoCreate { flags.append("autocreate") }
    if volume.indexed { flags.append("indexed") }
    if volume.warnOnEject { flags.append("warn-on-eject") }
    if volume.noExec { flags.append("noexec") }
    if volume.hidden { flags.append("hidden") }
    if volume.autoEjectOnExit { flags.append("auto-eject") }
    if !volume.folders.isEmpty { flags.append("folders: \(volume.folders.joined(separator: ", "))") }
    if volume.hasSyncSource {
        flags.append("sync: \(volume.syncSource!)")
        if volume.syncInterval > 0 {
            flags.append("interval: \(volume.syncInterval)min")
        }
    }
    return flags.joined(separator: ", ")
}

func executeSave(options: CLIOptions) {
    guard let volumeName = options.volumeToSave else {
        fputs("Error: Volume name required for save command.\n", stderr)
        fputs("Usage: tmpdisk save <volume-name>\n", stderr)
        exit(1)
    }

    guard let volume = DiskOperations.findVolumeByName(volumeName) else {
        fputs("Error: Volume '\(volumeName)' not found.\n", stderr)
        exit(1)
    }

    guard volume.hasSyncSource else {
        fputs("Error: Volume '\(volumeName)' has no sync source configured.\n", stderr)
        exit(1)
    }

    print("Saving '\(volume.name)' to '\(volume.syncSource!)'...")

    let result = DiskOperations.syncToSource(volume: volume)

    if result.success {
        print(result.message ?? "Save completed successfully.")
        exit(0)
    } else {
        fputs("Error: \(result.message ?? "Failed to save volume")\n", stderr)
        exit(1)
    }
}

func executeEject(options: CLIOptions) {
    guard let volumeName = options.volumeToEject else {
        fputs("Error: Volume name required for eject command.\n", stderr)
        fputs("Usage: tmpdisk eject <volume-name> [--force]\n", stderr)
        exit(1)
    }

    let result = DiskOperations.ejectVolumeByName(volumeName, force: options.force)

    if result.success {
        print(result.message ?? "Volume ejected successfully.")
        exit(0)
    } else {
        fputs("Error: \(result.message ?? "Failed to eject volume")\n", stderr)
        exit(1)
    }
}

func executeCreate(options: CLIOptions) {
    // Validate we have a name
    guard let name = options.name, !name.isEmpty else {
        fputs("Error: Volume name is required.\n", stderr)
        fputs("Usage: tmpdisk create name=<name> [size=<size>] [fs=<filesystem>] [flags]\n", stderr)
        fputs("Run 'tmpdisk help' for more information.\n", stderr)
        exit(1)
    }

    // Create the volume object
    guard let volume = options.toVolume() else {
        fputs("Error: Failed to create volume configuration.\n", stderr)
        exit(1)
    }

    // Validate size
    let isTmpFS = FileSystemManager.isTmpFS(volume.fileSystem)
    let validation = DiskSizeManager.shared.validateDiskSize(Double(volume.size), in: .mb, isTmpFS: isTmpFS)

    if !validation.isValid {
        if isTmpFS {
            fputs("Warning: TmpFS volumes are limited to 50% of RAM. Using maximum allowed size.\n", stderr)
        } else {
            fputs("Warning: Adjusted size to stay within available RAM.\n", stderr)
        }
    }

    // Warn about privilege requirements
    if isTmpFS || volume.noExec {
        if !TmpDiskConfig.isRoot {
            print("Note: This operation requires admin privileges. You will be prompted for your password.")
        }
    }

    // Create the volume
    print("Creating volume '\(volume.name)' (\(volume.size)MB, \(volume.fileSystem))...")

    let result = DiskOperations.createVolumeSync(volume: volume)

    if result.success {
        print(result.message ?? "Volume created successfully.")
        print("Path: \(volume.path())")

        // Sync from source if configured
        if volume.hasSyncSource {
            print("Syncing from '\(volume.syncSource!)'...")
            let syncResult = DiskOperations.syncFromSource(volume: volume)
            if syncResult.success {
                print("Sync completed.")
            } else {
                fputs("Warning: Sync failed: \(syncResult.message ?? "Unknown error")\n", stderr)
            }
        }

        if volume.autoCreate {
            print("Volume added to autocreate list.")
        }

        exit(0)
    } else {
        fputs("Error: \(result.message ?? "Failed to create volume")\n", stderr)

        if let error = result.error {
            switch error {
            case .exists:
                fputs("A volume with this name already exists.\n", stderr)
            case .noName:
                fputs("Volume name is required.\n", stderr)
            case .invalidSize:
                fputs("Invalid volume size.\n", stderr)
            default:
                break
            }
        }

        exit(1)
    }
}
