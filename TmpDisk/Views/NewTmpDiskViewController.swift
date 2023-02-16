//
//  NewTmpDiskView.swift
//  TmpDisk
//
//  Created by @imothee on 12/11/21.
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

class NewTmpDiskViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet weak var diskName: NSTextField!
    @IBOutlet weak var useTmpFs: NSButton!
    
    @IBOutlet weak var diskSizeLabel: NSTextField!
    @IBOutlet weak var diskSizeStepper: NSStepper!
    @IBOutlet weak var diskSize: NSTextField!
    @IBOutlet weak var folders: NSTextField!
    
    @IBOutlet weak var icon: NSImageView!
    
    @IBOutlet weak var diskUnitSelector: NSPopUpButton!
    @IBOutlet weak var diskSizeSelector: NSPopUpButton!
    
    @IBOutlet weak var autoCreate: NSButton!
    @IBOutlet weak var index: NSButton!
    @IBOutlet weak var hidden: NSButton!
    @IBOutlet weak var caseSensitive: NSButton!
    @IBOutlet weak var journaled: NSButton!
    
    var volume = TmpDiskVolume()
    var unitIndex = 0
    
    // MARK: - View controller lifecycle
    
    override public func viewDidAppear() {
        super.viewDidAppear()
        self.diskName.delegate = self
        self.diskSize.delegate = self
        self.folders.delegate = self
    }
    
    // MARK: - NSTextFieldDelegate
    
    public func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField, self.diskName.identifier == textField.identifier {
            self.volume.name = textField.stringValue
        }
        if let textField = obj.object as? NSTextField, self.diskSize.identifier == textField.identifier {
            self.setVolumeSize()
        }
        if let textField = obj.object as? NSTextField, self.folders.identifier == textField.identifier {
            self.volume.folders = textField.stringValue.split(separator: ",").map { String($0) }
        }
    }
    
    // MARK: - IBActions
    
    @IBAction func sizeStepped(_ sender: NSStepper) {
        if unitIndex == 0 {
            self.diskSize.stringValue = String(sender.integerValue)
        } else {
            let dSize = sender.integerValue / 1000
            self.diskSize.stringValue = String(format: "%.2f", dSize)
        }
    }
    
    @IBAction func unitSelected(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 0:
            if unitIndex == 1 {
                let dSize = self.diskSize.doubleValue * 1000
                self.diskSize.stringValue = String(Int(dSize))
                unitIndex = 0
            }
            break
        case 1:
            if unitIndex == 0 {
                let dSize = self.diskSize.doubleValue / 1000.0
                self.diskSize.stringValue = String(format: "%.2f", dSize)
                unitIndex = 1
            }
            break
        default:
            return
        }
    }
    
    @IBAction func sizeSelected(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 1, 2, 3, 4:
            let percent = [0.1, 0.25, 0.5, 0.75][sender.indexOfSelectedItem - 1]
            let dSize = (percent * Double(ProcessInfo.init().physicalMemory)) / 1024 / 1024
            if unitIndex == 0 {
                self.diskSize.stringValue = String(Int(dSize))
            } else {
                let newDSize = dSize / 1000.0
                self.diskSize.stringValue = String(format: "%.2f", newDSize)
            }
            sender.selectItem(at: 0)
            break
        default:
            return
        }
    }
    
    @IBAction func onIconChange(_ sender: NSImageView) {
        if let image = sender.image{
            guard image.size.width == image.size.height else {
                self.showError(message: NSLocalizedString("Icon must be square", comment: ""))
                sender.image = nil
                return
            }
            
            guard let iconBase64 = try? IconUtil.shared.convertImageToICNS(image: image) else {
                self.showError(message: NSLocalizedString("Could not convert image to icon", comment: ""))
                sender.image = nil
                return
            }
            
            self.volume.icon = iconBase64
        }
    }
    
    @IBAction func onUseTmpFsChange(_ sender: NSButton) {
        if sender.state == .on {
            self.volume.tmpFs = true
            self.diskSizeLabel.stringValue = "Max Size"
            // Hidden button
            self.hidden.isHidden = true
            self.hidden.state = .off
            self.volume.hidden = false
            // Case sensitive button
            self.caseSensitive.isHidden = true
            self.caseSensitive.state = .off
            self.volume.caseSensitive = false
            // Journaled button
            self.journaled.isHidden = true
            self.journaled.state = .off
            self.volume.journaled = false
        } else {
            self.volume.tmpFs = false
            self.diskSizeLabel.stringValue = "Disk Size"
            self.hidden.isHidden = false
            self.caseSensitive.isHidden = false
            self.journaled.isHidden = false
        }
    }
    
    @IBAction func onAutoCreateChange(_ sender: NSButton) {
        self.volume.autoCreate = sender.state == .on
    }
    
    @IBAction func onIndexChange(_ sender: NSButton) {
        self.volume.indexed = sender.state == .on
    }
    
    @IBAction func onWarnChange(_ sender: NSButton) {
        self.volume.warnOnEject = sender.state == .on
    }
    
    @IBAction func onHiddenChange(_ sender: NSButton) {
        self.volume.hidden = sender.state == .on
    }
    
    @IBAction func onCaseSensitiveChange(_ sender: NSButton) {
        self.volume.caseSensitive = sender.state == .on
    }
    
    @IBAction func onJournaledChange(_ sender: NSButton) {
        self.volume.journaled = sender.state == .on
    }
    
    @IBAction func createTapped(_ sender: NSButton) {
        let spinner = NSProgressIndicator(frame: NSRect(x: 58.5, y: 7.5, width: 13, height: 13))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        
        sender.addSubview(spinner)
        sender.isEnabled = false
        
        self.setVolumeSize()
        
        TmpDiskManager.shared.createTmpDisk(volume: self.volume) { error in
            DispatchQueue.main.async {
                spinner.removeFromSuperview()
                sender.isEnabled = true
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    switch error {
                    case .noName:
                        self.showError(message: NSLocalizedString("Your TmpDisk must have a name", comment: ""))
                        break;
                    case .exists:
                        self.showError(message: NSLocalizedString("A volume with this name already exists", comment: ""))
                        break;
                    case .invalidSize:
                        if self.unitIndex == 0 {
                            self.showError(message: NSLocalizedString("Size must be a number of megabytes > 0", comment: ""))
                        } else {
                            self.showError(message: NSLocalizedString("Size must be a number of gigabytes >= 0.01", comment: ""))
                        }
                        break;
                    case .failed:
                        self.showError(message: NSLocalizedString("Failed to create TmpDisk", comment: ""))
                        break;
                    }
                }
                return
            }
            DispatchQueue.main.async {
                self.view.window?.close()
            }
        }
    }
    
    // MARK: - Internal functions
    
    func setVolumeSize() {
        if unitIndex == 0 {
            self.volume.size = self.diskSize.integerValue
        } else {
            self.volume.size = Int(self.diskSize.doubleValue * 1000)
        }
    }
    
    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
