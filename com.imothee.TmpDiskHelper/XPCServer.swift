//
//  XPCServer.swift
//  TmpDiskHelper
//
//  Created by Tim on 2/28/24.
//

import Foundation

class XPCServer: NSObject {
    
    internal static let shared = XPCServer()
    
    private var listener: NSXPCListener?
    
    internal func start() {
        listener = NSXPCListener(machServiceName: Constant.helperMachLabel)
        listener?.delegate = self
        listener?.resume()
    }
    
    private func connetionInterruptionHandler() {
        NSLog("[SMJBS]: \(#function)")
    }
    
    private func connectionInvalidationHandler() {
        NSLog("[SMJBS]: \(#function)")
    }
    
    private func isValidClient(forConnection connection: NSXPCConnection) -> Bool {
        
        var token = connection.auditToken;
        let tokenData = Data(bytes: &token, count: MemoryLayout.size(ofValue:token))
        let attributes = [kSecGuestAttributeAudit : tokenData]
        
        // Check which flags you need
        let flags: SecCSFlags = []
        var code: SecCode? = nil
        var status = SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, flags, &code)
        
        if status != errSecSuccess {
            return false
        }
        
        guard let dynamicCode = code else {
            return false
        }
        // in this sample we duplicate the requirements from the Info.plist for simplicity
        // in a commercial application you could want to put the requirements in one place, for example in Active Compilation Conditions (Swift), or in preprocessor definitions (C, Objective-C)
        let entitlements = "identifier \"com.imothee.TmpDisk\" and anchor apple generic and certificate leaf[subject.CN] = \"Apple Development: Timothy Marks (R824A4SSXM)\" and certificate 1[field.1.2.840.113635.100.6.2.1] /* exists */"
        var requirement: SecRequirement?
        
        status = SecRequirementCreateWithString(entitlements as CFString, flags, &requirement)
        
        if status != errSecSuccess {
            return false
        }
        
        status = SecCodeCheckValidity(dynamicCode, flags, requirement)
        
        return status == errSecSuccess
    }
}

extension XPCServer: NSXPCListenerDelegate {
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        NSLog("[SMJBS]: \(#function)")
        
        if (!isValidClient(forConnection: newConnection)) {
            NSLog("[SMJBS]: Client is not valid")
            return false
        }
        
        NSLog("[SMJBS]: Client is valid")
        
        let creator = TmpDiskCreatorImpl()
        
        newConnection.exportedInterface = NSXPCInterface(with: TmpDiskCreator.self)
        newConnection.exportedObject = creator
        
        newConnection.remoteObjectInterface = NSXPCInterface(with: TmpDiskClient.self)
        
        newConnection.interruptionHandler = connetionInterruptionHandler
        newConnection.invalidationHandler = connectionInvalidationHandler
        
        newConnection.resume()
        
        creator.client = newConnection.remoteObjectProxy as? TmpDiskClient
        
        return true
    }
}
