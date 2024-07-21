//
//  XPCClient.swift
//  TmpDisk
//
//  Created by Tim on 2/28/24.
//

import Foundation

class XPCClient {
    
    var connection: NSXPCConnection?
    
    func initConnection() {
        if connection == nil {
            connection = NSXPCConnection(machServiceName: Constant.helperMachLabel,
                                             options: .privileged)
            
            connection?.remoteObjectInterface = NSXPCInterface(with: TmpDiskCreator.self)
            
            connection?.invalidationHandler = connectionInvalidationHandler
            connection?.interruptionHandler = connectionInterruptionHandler
        }
    }
    
    func createVolume(_ command: String, onCreate: @escaping (TmpDiskError?) -> Void) {
        
        initConnection()
        connection?.resume()
        
        let creator = connection?.remoteObjectProxyWithErrorHandler({ error in
            let e = error as NSError
            if e.code == 4099 {
                onCreate(.helperFailed)
            } else if e.code == 4097 {
                onCreate(.helperInvalidated)
            } else {
                onCreate(.helperFailed)
            }
        }) as? TmpDiskCreator
        creator?.createTmpDisk(command) { created in
            if created {
                onCreate(nil)
            } else {
                onCreate(.failed)
            }
        }
    }
    
    func uninstall() {
        initConnection()
        connection?.resume()

        let creator = connection?.remoteObjectProxy as? TmpDiskCreator
        creator?.uninstall()
    }
    
    private func connectionInterruptionHandler() {
        NSLog("[XPCTEST] \(type(of: self)): connection has been interrupted XPCTEST")
        connection = nil
    }
    
    private func connectionInvalidationHandler() {
        NSLog("[XPCTEST] \(type(of: self)): connection has been invalidated XPCTEST")
        connection = nil
    }
}
