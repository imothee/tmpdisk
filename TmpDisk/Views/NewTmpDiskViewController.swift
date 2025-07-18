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
    
    @IBOutlet weak var diskSizeLabel: NSTextField!
    @IBOutlet weak var diskSizeStepper: NSStepper!
    @IBOutlet weak var diskSize: NSTextField!
    @IBOutlet weak var folders: NSTextField!
    @IBOutlet weak var mountPoint: NSTextField!
    
    @IBOutlet weak var icon: NSImageView!
    
    @IBOutlet weak var diskUnitSelector: NSPopUpButton!
    @IBOutlet weak var diskSizeSelector: NSPopUpButton!
    
    @IBOutlet weak var autoCreate: NSButton!
    @IBOutlet weak var index: NSButton!
    @IBOutlet weak var hidden: NSButton!
    @IBOutlet weak var noExec: NSButton!
    
    @IBOutlet weak var fileSystemLabel: NSTextField!
    @IBOutlet weak var fileSystemButton: NSPopUpButton!
    
    var volume = TmpDiskVolume()
    var currentUnit: DiskSizeUnit = .mb
    
    // MARK: - View controller lifecycle
    
    override public func viewDidAppear() {
        super.viewDidAppear()
        self.diskName.delegate = self
        self.diskSize.delegate = self
        self.folders.delegate = self
        self.mountPoint.delegate = self
        self.setDefaultUnits()
        
        self.fileSystemButton.addItems(withTitles: FileSystemManager.availableFileSystemDescriptions())
    }
    
    // MARK: - NSTextFieldDelegate
    
    public func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField, self.diskName.identifier == textField.identifier {
            self.volume.name = textField.stringValue
        } else if let textField = obj.object as? NSTextField, self.diskSize.identifier == textField.identifier {
            self.setVolumeSize()
            _ = validateSize()
        } else if let textField = obj.object as? NSTextField, self.folders.identifier == textField.identifier {
            self.volume.folders = textField.stringValue.split(separator: ",").map { String($0) }
        } else if let textField = obj.object as? NSTextField, self.mountPoint.identifier == textField.identifier {
            self.volume.mountPoint = textField.stringValue == "" ? nil : textField.stringValue
        }
    }
    
    // MARK: - IBActions
    
    @IBAction func sizeStepped(_ sender: NSStepper) {
        if currentUnit == .mb {
            self.diskSize.stringValue = String(sender.integerValue)
        } else {
            let dSize = sender.integerValue / 1000
            self.diskSize.stringValue = String(format: "%.2f", dSize)
        }
        _ = validateSize()
    }
    
    @IBAction func unitSelected(_ sender: NSPopUpButton) {
        let selectedUnit = DiskSizeUnit(rawValue: sender.indexOfSelectedItem) ?? .mb
        
        if selectedUnit != currentUnit {
            // Convert the current value to the new unit
            let currentSize = self.diskSize.doubleValue
            let convertedSize = DiskSizeManager.shared.convertSize(
                currentSize,
                from: currentUnit,
                to: selectedUnit
            )
            
            // Update the display
            self.diskSize.stringValue = DiskSizeManager.shared.formatSize(
                convertedSize,
                in: selectedUnit
            )
            
            // Update the current unit
            currentUnit = selectedUnit
            UserDefaults.standard.set(currentUnit.rawValue, forKey: "defaultUnits")
        }
    }
    
    @IBAction func sizeSelected(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 1, 2, 3, 4:
            let percentages = DiskSizeManager.shared.commonRamSizePercentages()
            let percentIndex = sender.indexOfSelectedItem - 1
            let percent = percentages[percentIndex]
            let ramSizeMB = DiskSizeManager.shared.ramSizeForPercentage(percent)
            
            // For TmpFS, limit to 50% RAM
            if FileSystemManager.isTmpFS(volume.fileSystem) && percent > 0.5 {
                // Show warning about exceeding limit
                DiskSizeManager.shared.showTmpFSSizeWarning()
                
                // Set to 50% instead
                let safeSize = DiskSizeManager.shared.maxTmpFSSizeMB
                self.diskSize.stringValue = DiskSizeManager.shared.formatSize(safeSize, in: currentUnit)
            } else {
                // Normal behavior for other filesystems or within limit
                self.diskSize.stringValue = DiskSizeManager.shared.formatSize(ramSizeMB, in: currentUnit)
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
    
    @IBAction func onFileSystemChange(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        let fileSystem = FileSystemManager.availableFileSystems()[index]
        
        self.volume.fileSystem = fileSystem.name
        
        if FileSystemManager.isTmpFS(fileSystem.name) {
            self.diskSizeLabel.stringValue = "Max Size (Limited to 50% Ram by MacOS)"
            // Hidden button
            self.hidden.isHidden = true
            self.hidden.state = .off
            self.volume.hidden = false
        } else {
            self.diskSizeLabel.stringValue = "Disk Size"
            self.hidden.isHidden = false
        }
        _ = self.validateSize()
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
    
    @IBAction func onNoExecChange(_ sender: NSButton) {
        self.volume.noExec = sender.state == .on
    }
    
    @IBAction func createTapped(_ sender: NSButton) {
        let spinner = NSProgressIndicator(frame: NSRect(x: 58.5, y: 7.5, width: 13, height: 13))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        
        sender.addSubview(spinner)
        sender.isEnabled = false
        
        self.setVolumeSize()
        
        if !validateSize() {
            return
        }
        
        if FileSystemManager.isTmpFS(volume.fileSystem) {
            // Check if we've ever prompted them to install the helper
            let helperPrompted = UserDefaults.standard.object(forKey: "helperPromptShowns") as? Bool
            let helperVersion = Util.checkHelperVersion()
            
            if helperPrompted == nil && helperVersion == nil {
                UserDefaults.standard.set(true, forKey: "helperPromptShown")
                
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("You can now install the TmpDiskHelper to create TmpFS volumes without entering a password each time. The helper can be managed in TmpDisk preferences and requires your Admin Password to install.", comment: "")
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Don't ask again")
                if alert.runModal() == .alertFirstButtonReturn {
                    _ = Util.installHelper()
                }
            }
        }
        
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
                        if self.currentUnit == .mb {
                            self.showError(message: NSLocalizedString("Size must be a number of megabytes > 0", comment: ""))
                        } else {
                            self.showError(message: NSLocalizedString("Size must be a number of gigabytes >= 0.01", comment: ""))
                        }
                        break;
                    case .failed:
                        self.showError(message: NSLocalizedString("Failed to create TmpDisk", comment: ""))
                        break;
                    case .helperInvalidated:
                        self.showError(message: NSLocalizedString("The helper failed connection validation. Please try reinstalling the helper.", comment: ""))
                        break;
                    case .helperFailed:
                        self.showError(message: NSLocalizedString("The helper crashed, please check TmpDisk logs in the Console app and log a bug.", comment: ""))
                        break;
                    case .inUse:
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
        if currentUnit == .mb {
            self.volume.size = self.diskSize.integerValue
        } else if currentUnit == .gb {
            self.volume.size = Int(DiskSizeManager.shared.convertGBtoMB(self.diskSize.doubleValue))
        }
    }
    
    func setDefaultUnits() {
        func setDefaultUnits() {
            if let defaultUnits = UserDefaults.standard.object(forKey: "defaultUnits") as? Int,
               let unit = DiskSizeUnit(rawValue: defaultUnits) {
                diskUnitSelector.selectItem(at: defaultUnits)
                self.currentUnit = unit
            }
        }
    }
    
    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func validateSize() -> Bool {
        let currentSize = self.diskSize.doubleValue
        let isTmpFS = FileSystemManager.isTmpFS(volume.fileSystem)
        
        // Validate using the DiskSizeManager
        let validation = DiskSizeManager.shared.validateDiskSize(currentSize, in: currentUnit, isTmpFS: isTmpFS)
        
        if !validation.isValid {
            // Show warning
            if isTmpFS {
                DiskSizeManager.shared.showTmpFSSizeWarning()
            } else {
                DiskSizeManager.shared.showInsufficientRamWarning()
            }
            
            // Set to max allowed value formatted in the current unit
            self.diskSize.stringValue = DiskSizeManager.shared.formatSize(
                validation.correctedSizeMB,
                in: currentUnit
            )
            
            // Update volume size
            self.setVolumeSize()
            return false
        }
        return true
    }
}
