//
//  Protocols.swift
//  TmpDiskHelper
//
//  Created by Tim on 2/28/24.
//

import Foundation

@objc protocol TmpDiskCreator {
    func createTmpDisk(_ command: String)
    func uninstall()
}

@objc public protocol TmpDiskClient {
    func tmpDiskCreated(_ success: Bool)
}
