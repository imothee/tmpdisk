//
//  DiskSizeManagerUI.swift
//  TmpDisk
//
//  Created by Claude on 2025.
//
//  This file is part of TmpDisk.
//
//  TmpDisk is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TmpDisk is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TmpDisk.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
import AppKit

/// AppKit-specific UI extensions for DiskSizeManager
extension DiskSizeManager {
    /// Shows a warning alert about the TmpFS size limitation
    func showTmpFSSizeWarning() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("TmpFS volumes are limited to 50% of RAM. Setting to maximum allowed value.", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showInsufficientRamWarning() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Insufficient RAM to allocate to TmpDisk. Please reduce the size.", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
