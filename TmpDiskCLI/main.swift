//
//  main.swift
//  TmpDiskCLI
//
//  Created by Tim on 4/6/25.
//

import Foundation

// Check if help was called
if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") || CommandLine.arguments.contains("help") {
    displayHelpText()
    exit(0)
}

let args = CommandLine.arguments.dropFirst().joined(separator: " ")

// Optionally launch the app if not running
_ = try? Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: ["-a", "TmpDisk.app", "--args"] + CommandLine.arguments.dropFirst())

// Write to pipe used by your app
let pipePath = "/tmp/tmpdisk_cmd"

let fileDescriptor = open(pipePath, O_WRONLY)
if fileDescriptor == -1 {
    print("Failed to open pipe for writing: \(errno)")
    exit(1)
}

if let data = args.data(using: .utf8) {
    data.withUnsafeBytes { buffer in
        write(fileDescriptor, buffer.baseAddress, data.count)
    }
}

close(fileDescriptor)

private func displayHelpText() {
    let helpText = """
    TmpDisk Command Help
    ===================
    
    Commands:
      help                    Display this help message
    
    Parameters:
      name=VALUE              Set the disk name (default: TmpDisk)
      size=VALUE[MB|GB]       Set the disk size (default: 64MB)
      units=[MB|GB]           Set the size units (default: MB)
      fs=FILESYSTEM           Set the filesystem type (default: APFS)
                              Available: \(FileSystemManager.availableFileSystems().map { $0.name }.joined(separator: ", "))
    
    Examples:
      tmpdisk name=MyDisk size=1GB
      tmpdisk size=512 fs=HFS+
      tmpdisk help
    
    Note: Parameters can be prefixed with '-' (e.g., -name=MyDisk)
    """
    
    print(helpText)
}
