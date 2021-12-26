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
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

