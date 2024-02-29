//
//  XPCClient.swift
//  TmpDisk
//
//  Created by Tim on 2/28/24.
//

import Foundation

class XPCClient {
    
    var connection: NSXPCConnection?
    
    func createVolume(_ command: String, onCreate: @escaping (TmpDiskError?) -> Void) {
        connection = NSXPCConnection(machServiceName: Constant.helperMachLabel,
                                         options: .privileged)
        
        let impl = TmpDiskClientImpl()
        impl.onCreate = onCreate
        
        connection?.exportedInterface = NSXPCInterface(with: TmpDiskClient.self)
        connection?.exportedObject = impl
        connection?.remoteObjectInterface = NSXPCInterface(with: TmpDiskCreator.self)
        
        connection?.invalidationHandler = connectionInvalidationHandler
        connection?.interruptionHandler = connectionInterruptionHandler
        
        connection?.resume()

        let creator = connection?.remoteObjectProxy as? TmpDiskCreator
        creator?.createTmpDisk(command)
    }
    
    func uninstall() {
        connection = NSXPCConnection(machServiceName: Constant.helperMachLabel,
                                         options: .privileged)
        
        connection?.exportedInterface = NSXPCInterface(with: TmpDiskClient.self)
        connection?.exportedObject = TmpDiskClientImpl()
        connection?.remoteObjectInterface = NSXPCInterface(with: TmpDiskCreator.self)
        
        connection?.invalidationHandler = connectionInvalidationHandler
        connection?.interruptionHandler = connectionInterruptionHandler
        
        connection?.resume()

        let creator = connection?.remoteObjectProxy as? TmpDiskCreator
        creator?.uninstall()
    }
    
    private func connectionInterruptionHandler() {
        NSLog("[XPCTEST] \(type(of: self)): connection has been interrupted XPCTEST")
    }
    
    private func connectionInvalidationHandler() {
        NSLog("[XPCTEST] \(type(of: self)): connection has been invalidated XPCTEST")
    }
}

class TmpDiskClientImpl: NSObject, TmpDiskClient {
    var onCreate: ((TmpDiskError?) -> Void)?
    
    func tmpDiskCreated(_ success: Bool) {
        NSLog("[XPCTEST]: \(#function)")
        if success {
            onCreate?(nil)
        } else {
            onCreate?(.failed)
        }
    }
}
