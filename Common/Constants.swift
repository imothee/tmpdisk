//
//  Constants.swift
//  TmpDiskHelper
//
//  Created by Tim on 2/28/24.
//

import Foundation

struct Constant {
    static let helperMachLabel = "com.imothee.TmpDiskHelper"
}

enum TmpDiskError: Error {
    case noName
    case exists
    case invalidSize
    case failed
    case helperInvalidated
    case helperFailed
    case inUse
}
