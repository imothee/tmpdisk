//
//  TmpDiskCreator.swift
//  TmpDiskHelper
//
//  Created by Tim on 2/28/24.
//

import Foundation

class TmpDiskCreatorImpl: NSObject, TmpDiskCreator {
    
    var client: TmpDiskClient?
    
    func createTmpDisk(_ command: String) {
        NSLog("[SMJBS]: \(#function)")
        
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        let created = (task.terminationStatus == 0)
        
        client?.tmpDiskCreated(created)
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
