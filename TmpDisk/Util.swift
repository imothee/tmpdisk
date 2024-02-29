//
//  Util.swift
//  TmpDisk
//
//  Created by Tim on 2/28/24.
//

import Foundation
import AppKit
import SecurityFoundation
import ServiceManagement

struct Util {
    
    static func askAuthorization() -> AuthorizationRef? {
        
        var auth: AuthorizationRef?
        let status: OSStatus = AuthorizationCreate(nil, nil, [], &auth)
        if status != errAuthorizationSuccess {
            NSLog("[SMJBS]: Authorization failed with status code \(status)")
            
            return nil
        }
        
        return auth
    }
    
    @discardableResult
    static func blessHelper(label: String, authorization: AuthorizationRef) -> Bool {
        
        var error: Unmanaged<CFError>?
        let blessStatus = SMJobBless(kSMDomainSystemLaunchd, label as CFString, authorization, &error)
        
        if !blessStatus {
            NSLog("[SMJBS]: Helper bless failed with error \(error!.takeUnretainedValue())")
        }
        
        return blessStatus
    }
    
    // Returns a version number or nil if helper is not installed
    static func checkHelperVersion() -> Int? {
        // Registered with launchd
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["print", "system/\(Constant.helperMachLabel)"]
        process.qualityOfService = QualityOfService.userInitiated
        process.standardOutput = nil
        process.standardError = nil
        process.launch()
        process.waitUntilExit()
        let registeredWithLaunchd = (process.terminationStatus == 0)
        
        if registeredWithLaunchd {
            let plist = NSDictionary(contentsOfFile: "/Library/LaunchDaemons/com.imothee.TmpDiskHelper.plist")
            if let build = plist?["Build"] as? String {
                return Int(build)
            }
        }
        return nil
    }
    
    static func latestEmbeddedHelperVersion() -> Int? {
        if let build = Bundle.main.infoDictionary?["TmpDiskHelperVersion"] as? String {
            return Int(build)
        }
        return nil
    }
    
    static func installHelper(update: Bool = false) -> Bool {
        let messageText = update ?
            NSLocalizedString("There is an updated TmpDiskHelper, do you wish to install it? Requires admin password.", comment: "") :
            NSLocalizedString("Do you wish to install TmpDiskHelper? It will require your admin password.", comment: "")
        
        let alert = NSAlert()
        alert.messageText = messageText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            guard let auth = Util.askAuthorization() else {
                fatalError("Authorization not acquired.")
            }
                    
            Util.blessHelper(label: Constant.helperMachLabel, authorization: auth)
            return true
        }
        return false
    }
}
