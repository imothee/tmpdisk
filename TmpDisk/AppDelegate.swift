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
        
        // Check if TmpDisk was loaded with command line args
        let (name, size) = getArgs()
        if let name = name, let size = size {
            let volume = TmpDiskVolume(name: name, size: size)
            TmpDiskManager.shared.createTmpDisk(volume: volume, onCreate: {_ in})
        }
        
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
        
        // Check the helper status
        checkHelperStatus()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // We expect args in the format -argname=argval
    private func getArgs() -> (String?, Int?) {
        let args = ProcessInfo.processInfo.arguments
        var name: String?
        var size: Int?
        
        for arg in args {
            let values = arg.components(separatedBy: "=")
            if values.count == 2 {
                switch values[0] {
                case "-name":
                    name = values[1]
                    break
                case "-size":
                    size = (values[1] as NSString).integerValue
                    break
                default:
                    break
                }
            }
        }
        return (name, size)
    }
    
    // Check if the helper is installed, if it is check if it needs to be updated
    private func checkHelperStatus() {
        if let build = Util.checkHelperVersion() {
            if let newestHelperVersion = Util.latestEmbeddedHelperVersion() {
                if newestHelperVersion > build {
                    Util.installHelper(update: true)
                }
            }
        }
    }
}

