//
//  ArgumentParser.swift
//  TmpDiskCLI
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

/// Command to execute
enum CLICommand: String {
    case create
    case eject
    case list
    case save
    case help

    static func from(_ arg: String) -> CLICommand? {
        switch arg.lowercased() {
        case "create": return .create
        case "eject": return .eject
        case "list", "ls": return .list
        case "save", "sync": return .save
        case "help", "--help", "-h": return .help
        default: return nil
        }
    }
}

/// Parsed CLI options
struct CLIOptions {
    var command: CLICommand = .create
    var name: String?
    var size: Int = 64
    var sizeUnit: DiskSizeUnit = .mb
    var fileSystem: String = FileSystemManager.defaultFileSystemName()

    // Boolean flags
    var autoCreate: Bool = false
    var indexed: Bool = false
    var warnOnEject: Bool = false
    var noExec: Bool = false
    var hidden: Bool = false
    var autoEjectOnExit: Bool = false
    var force: Bool = false

    // Folders to create
    var folders: [String] = []

    // Sync options
    var syncSource: String?
    var syncInterval: Int = 0
    var saveOnEject: SaveOnEjectMode = .prompt

    // For eject/save command
    var volumeToEject: String?
    var volumeToSave: String?

    /// Convert to a TmpDiskVolume
    func toVolume() -> TmpDiskVolume? {
        guard let name = name, !name.isEmpty else {
            return nil
        }

        // Convert size to MB if needed
        let sizeInMB: Int
        if sizeUnit == .gb {
            sizeInMB = Int(DiskSizeManager.shared.convertGBtoMB(Double(size)))
        } else {
            sizeInMB = size
        }

        var volume = TmpDiskVolume(name: name, size: sizeInMB, fileSystem: fileSystem)
        volume.autoCreate = autoCreate
        volume.indexed = indexed
        volume.warnOnEject = warnOnEject
        volume.noExec = noExec
        volume.hidden = hidden
        volume.autoEjectOnExit = autoEjectOnExit
        volume.folders = folders
        volume.syncSource = syncSource
        volume.syncInterval = syncInterval
        volume.saveOnEject = saveOnEject

        return volume
    }
}

/// Parse command-line arguments into CLIOptions
func parseArguments(_ args: [String]) -> CLIOptions {
    var options = CLIOptions()
    var argIndex = 0
    let argList = Array(args.dropFirst()) // Skip program name

    while argIndex < argList.count {
        let arg = argList[argIndex]

        // Check for command (if it's the first argument or after flags)
        if argIndex == 0, let command = CLICommand.from(arg) {
            options.command = command
            argIndex += 1
            continue
        }

        // Parse key=value pairs
        if arg.contains("=") {
            let parts = arg.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                let value = String(parts[1])

                switch key {
                case "name":
                    options.name = value
                case "size":
                    parseSize(value, into: &options)
                case "fs", "filesystem":
                    let fsUpper = value.uppercased()
                    if FileSystemManager.availableFileSystems().contains(where: { $0.name == fsUpper }) {
                        options.fileSystem = fsUpper
                    }
                case "folders", "f":
                    options.folders = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                case "sync", "syncsource":
                    options.syncSource = value
                case "syncinterval", "interval":
                    options.syncInterval = Int(value) ?? 0
                case "saveoneject", "save":
                    switch value.lowercased() {
                    case "yes", "true", "1": options.saveOnEject = .yes
                    case "no", "false", "0": options.saveOnEject = .no
                    default: options.saveOnEject = .prompt
                    }
                default:
                    break
                }

                argIndex += 1
                continue
            }
        }

        // Parse flags
        switch arg {
        // Long flags
        case "--autocreate", "-a":
            options.autoCreate = true
        case "--indexed", "-i":
            options.indexed = true
        case "--warn", "-w":
            options.warnOnEject = true
        case "--noexec", "-x":
            options.noExec = true
        case "--hidden", "-H":
            options.hidden = true
        case "--autoeject", "-e":
            options.autoEjectOnExit = true
        case "--force":
            options.force = true
        case "--help", "-h":
            options.command = .help

        // Check if this might be a volume name for eject or save
        default:
            if options.command == .eject && options.volumeToEject == nil && !arg.hasPrefix("-") {
                options.volumeToEject = arg
            } else if options.command == .save && options.volumeToSave == nil && !arg.hasPrefix("-") {
                options.volumeToSave = arg
            } else if let command = CLICommand.from(arg) {
                options.command = command
            }
        }

        argIndex += 1
    }

    return options
}

/// Parse size string which may include unit suffix
private func parseSize(_ value: String, into options: inout CLIOptions) {
    var sizeString = value.lowercased()

    if sizeString.hasSuffix("gb") {
        options.sizeUnit = .gb
        sizeString = String(sizeString.dropLast(2))
    } else if sizeString.hasSuffix("mb") {
        options.sizeUnit = .mb
        sizeString = String(sizeString.dropLast(2))
    }

    if let sizeValue = Int(sizeString.trimmingCharacters(in: .whitespaces)), sizeValue > 0 {
        options.size = sizeValue
    }
}

/// Print help text
func printHelp() {
    let helpText = """
    TmpDisk CLI - Create and manage RAM disks

    USAGE:
        tmpdisk [command] [options]

    COMMANDS:
        create      Create a new RAM disk (default)
        eject       Eject a RAM disk
        save        Save RAM disk contents back to sync source
        list        List all TmpDisk volumes
        help        Show this help message

    CREATE OPTIONS:
        name=NAME           Set the disk name (required)
        size=SIZE[MB|GB]    Set the disk size (default: 64MB)
        fs=FILESYSTEM       Set the filesystem type (default: APFS)
                            Available: \(FileSystemManager.availableFileSystems().map { $0.name }.joined(separator: ", "))

    FLAGS:
        -a, --autocreate    Add to autocreate list (recreated on app startup)
        -i, --indexed       Enable Spotlight indexing
        -w, --warn          Warn on eject if volume has files
        -x, --noexec        Mount with noexec (requires admin)
        -H, --hidden        Hidden volume (nobrowse)
        -e, --autoeject     Eject when app quits
        --folders=a,b,c     Folders to create in volume

    SYNC OPTIONS:
        --sync=PATH         Sync source folder (contents copied to/from RAM disk)
        --sync-interval=N   Auto-save interval in minutes (0 = manual only)
        --save-on-eject=X   Save on eject: yes, no, or prompt (default: prompt)

    EJECT OPTIONS:
        --force             Force eject even if volume is in use

    EXAMPLES:
        tmpdisk create name=MyDisk size=512MB fs=APFS --indexed --autocreate
        tmpdisk name=MyDisk size=1GB --hidden --noexec

        # Create with folder sync
        tmpdisk name=Work size=2GB --sync=/path/to/project --save-on-eject=yes
        tmpdisk name=Cache size=512MB --sync=/path/to/cache --sync-interval=5

        tmpdisk save MyDisk           # Save contents back to sync source
        tmpdisk eject MyDisk
        tmpdisk eject MyDisk --force
        tmpdisk list

    Note: TMPFS and --noexec require admin privileges.
          When using sudo, the volume is created for the invoking user.
    """

    print(helpText)
}
