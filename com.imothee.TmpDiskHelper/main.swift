//
//  main.swift
//  TmpDiskHelper
//
//  Created by Tim on 2/27/24.
//

import Foundation

NSLog("[SMJBS]: Privileged TmpDiskHelper has started")

XPCServer.shared.start()

CFRunLoopRun()
