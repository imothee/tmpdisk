//
//  TmpDiskCreator.swift
//  TmpDiskHelper
//
//  Created by Tim on 2/28/24.
//

import Foundation

class TmpDiskCreatorImpl: NSObject, TmpDiskCreator {
    
    func createTmpDisk(_ command: String, onCreate: @escaping (Bool) -> Void) {
        NSLog("[SMJBS]: \(#function)")
        
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        let created = (task.terminationStatus == 0)
        
        onCreate(created)
    }
    
    func ejectTmpDisk(_ command: String, onEject: @escaping (Int32) -> Void) {
        NSLog("[SMJBS]: \(#function)")
        
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        onEject(task.terminationStatus)
    }
    
    func uninstall() {
        try? FileManager.default.removeItem(atPath: "/Library/PrivilegedHelperTools/com.imothee.TmpDiskHelper")
        try? FileManager.default.removeItem(atPath: "/Library/LaunchDaemons/com.imothee.TmpDiskHelper.plist")
        
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["bootout", "system/com.imothee.TmpDiskHelper"]
        task.waitUntilExit()
        try? task.run()
    }
}
