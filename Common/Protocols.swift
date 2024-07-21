//
//  Protocols.swift
//  TmpDiskHelper
//
//  Created by Tim on 2/28/24.
//

import Foundation

@objc protocol TmpDiskCreator {
    func createTmpDisk(_ command: String, onCreate: @escaping (Bool) -> Void)
    func uninstall()
}
