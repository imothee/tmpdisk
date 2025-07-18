//
//  AppDelegate.swift
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

import Cocoa

import ServiceManagement

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
    static let tmpDiskMounted = Notification.Name("TmpDiskMounted")
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBar = StatusBarController.init()
        
        NotificationCenter.default.addObserver(forName: .tmpDiskMounted, object: nil, queue: .main) { notification in
            self.statusBar?.buildCurrentTmpDiskMenu()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { notification in
            if let path = notification.userInfo?["NSDevicePath"] as? String {
                if TmpDiskManager.shared.diskEjected(path: path) {
                    // We had a TmpDisk removed so we need to refresh the statusbar
                    self.statusBar?.buildCurrentTmpDiskMenu()
                }
            }
        }
        
        // Kill the launcher app if it's around
        let launcherAppId = "com.imothee.TmpDiskLauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
        
        // Handle any args
        handleArgs()
        
        // Setup the command watcher
        startListeningForCommands()
        
        // Check the helper status
        checkHelperStatus()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    private func handleArgs() {
        // Get the args from the process
        runArgs(ProcessInfo.processInfo.arguments)
    }
    
    private func handleIncomingCommand(_ command: String) {
        // Get args from the string
        let args = command.components(separatedBy: " ")
        runArgs(args)
    }
    
    private func runArgs(_ args: [String]) {
        // Check if TmpDisk was loaded with command line args
        let (name, size, fs) = getArgs(args)
        if let name = name, let size = size {
            let volume = TmpDiskVolume(name: name, size: size, fileSystem: fs)
            TmpDiskManager.shared.createTmpDisk(volume: volume, onCreate: {_ in})
        }
    }
    
    // We expect args in the format -argname=argval
    private func getArgs(_ args: [String]) -> (String?, Int?, String?) {
        var name: String?
        var size: Int?
        var units = DiskSizeUnit.mb
        var fileSystem: String?
        
        for arg in args {
            let values = arg.components(separatedBy: "=")
            if values.count == 2 {
                switch values[0] {
                case "-name", "name":
                    name = values[1]
                    break
                case "-size", "size":
                    // Check to see if the string ends in MB or GB case insensitive
                    var sizeString = values[1].lowercased()
                    if sizeString.hasSuffix("mb") || sizeString.hasSuffix("gb") {
                        if sizeString.hasSuffix("gb") {
                            units = DiskSizeUnit.gb
                        }
                        sizeString = String(sizeString.dropLast(2))
                    }
                    size = Int(sizeString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                    break
                case "-units", "units":
                    let unitString = values[1].lowercased()
                    if unitString == "gb" {
                        units = DiskSizeUnit.gb
                    }
                case "-fs", "fs":
                    let fsString = values[1].uppercased()
                    if FileSystemManager.availableFileSystems().contains(where: { $0.name == fsString }) {
                        fileSystem = fsString
                    }
                default:
                    break
                }
            }
        }
        
        let convertedSize: Int?
        if let size = size {
            convertedSize = Int(DiskSizeManager.shared.convertSize(Double(size), from: .mb, to: units))
        } else {
            convertedSize = nil
        }
        return (name, convertedSize, fileSystem)
    }
    
    private func startListeningForCommands() {
        let pipePath = "/tmp/tmpdisk_cmd"
        
        // Create the pipe once
        if FileManager.default.fileExists(atPath: pipePath) {
            unlink(pipePath)
        }

        mkfifo(pipePath, 0o644)
        
        DispatchQueue.global(qos: .background).async {
            while true {
                // Open the pipe for reading in a blocking mode
                let fileDescriptor = open(pipePath, O_RDONLY)
                if fileDescriptor == -1 {
                    print("Failed to open pipe for reading: \(errno)")
                    sleep(1)
                    continue
                }
                
                var buffer = [UInt8](repeating: 0, count: 1024)
                let bytesRead = read(fileDescriptor, &buffer, buffer.count)
                close(fileDescriptor)
                
                if bytesRead > 0 {
                    let data = Data(buffer[0..<bytesRead])
                    if let command = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty {
                        DispatchQueue.main.async {
                            self.handleIncomingCommand(command)
                        }
                    }
                }
            }
        }
    }
    
    // Check if the helper is installed, if it is check if it needs to be updated
    private func checkHelperStatus() {
        if let build = Util.checkHelperVersion() {
            if let newestHelperVersion = Util.latestEmbeddedHelperVersion() {
                if newestHelperVersion > build {
                    _ = Util.installHelper(update: true)
                }
            }
        }
    }
}

