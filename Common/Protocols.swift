//
//  Protocols.swift
//  TmpDiskHelper
//
//  Created by Tim on 2/28/24.
//

import Foundation

@objc protocol TmpDiskCreator {
    func createTmpDisk(_ command: String, onCreate: @escaping (Bool) -> Void)
    func ejectTmpDisk(_ command: String, onEject: @escaping (Int32) -> Void)
    func uninstall()
}
