//
//  AppDelegate.swift
//  TmpDisk
//
//  Created by Tim on 12/11/21.
//

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

