//
//  PreferencesWindowViewController.swift
//  TmpDisk
//
//  Created by @imothee on 12/19/21.
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

class PreferencesViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet weak var updateHelper: NSButton!
    @IBOutlet weak var useHelper: NSSegmentedControl!
    @IBOutlet weak var rootFolder: NSTextField!

    var helperInstalled: Bool = false
    
    override public func viewDidAppear() {
        super.viewDidAppear()
        if let root = UserDefaults.standard.object(forKey: "rootFolder") as? String {
            self.rootFolder.stringValue = root
        }
        self.rootFolder.placeholderString = TmpDiskHome
        
        if Util.checkHelperVersion() != nil {
            helperInstalled = true
            useHelper.setSelected(true, forSegment: 1)
        } else {
            updateHelper.isHidden = true
        }
    }
    
    @IBAction func toggleHelper(_ sender: NSSegmentedControl) {
        if useHelper.isSelected(forSegment: 1) {
            if !helperInstalled {
                let installed = Util.installHelper(update: false)
                if installed {
                    updateHelper.isHidden = false
                    helperInstalled = true
                } else {
                    useHelper.setSelected(true, forSegment: 0)
                }
            }
        } else {
            if helperInstalled {
                let client = XPCClient()
                client.uninstall()
                updateHelper.isHidden = true
                helperInstalled = false
            }
        }
    }
    
    @IBAction func updateHelper(_ sender: NSButton) {
        Util.installHelper(update: true)
    }
    
    @IBAction func savePreferences(_ sender: NSButton) {
        if !TmpDiskManager.shared.volumes.filter({ $0.tmpFs }).isEmpty {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("You can't change the root volume while tmpFS disks are mounted.", comment: "")
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        if rootFolder.stringValue.isEmpty {
            UserDefaults.standard.removeObject(forKey: "rootFolder")
            TmpDiskManager.rootFolder = TmpDiskHome
            self.view.window?.close()
            return
        }
        
        UserDefaults.standard.set(rootFolder.stringValue, forKey: "rootFolder")
        TmpDiskManager.rootFolder = rootFolder.stringValue
        self.view.window?.close()
    }
}
