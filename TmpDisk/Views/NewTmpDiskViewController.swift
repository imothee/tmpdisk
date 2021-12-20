//
//  NewTmpDiskView.swift
//  TmpDisk
//
//  Created by Tim on 12/11/21.
//

import Foundation
import AppKit

class NewTmpDiskViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet weak var diskName: NSTextField!
    @IBOutlet weak var useTmpFs: NSButton!
    
    @IBOutlet weak var diskSizeLabel: NSTextField!
    @IBOutlet weak var diskSizeStepper: NSStepper!
    @IBOutlet weak var diskSize: NSTextField!
    @IBOutlet weak var diskSizeSuffixLabel: NSTextField!
    @IBOutlet weak var folders: NSTextField!
    
    @IBOutlet weak var autoCreate: NSButton!
    @IBOutlet weak var index: NSButton!
    @IBOutlet weak var hidden: NSButton!
    
    var volume = TmpDiskVolume()
    
    // MARK: - View controller lifecycle
    
    override public func viewDidAppear() {
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
            self.volume.size = textField.integerValue
        }
        if let textField = obj.object as? NSTextField, self.folders.identifier == textField.identifier {
            self.volume.folders = textField.stringValue.split(separator: ",").map { String($0) }
        }
    }
    
    // MARK: - IBACtions
    
    @IBAction func sizeStepped(_ sender: NSStepper) {
        self.volume.size = sender.integerValue
        self.diskSize.stringValue = "\(sender.integerValue)"
    }
    
    @IBAction func onUseTmpFsChange(_ sender: NSButton) {
        if sender.state == .on {
            self.volume.tmpFs = true
            
            self.diskSizeLabel.stringValue = "Max Size"
        } else {
            self.volume.tmpFs = false
            
            self.diskSizeLabel.stringValue = "Disk Size"
        }
    }
    
    @IBAction func onAutoCreateChange(_ sender: NSButton) {
        self.volume.autoCreate = sender.state == .on
    }
    
    @IBAction func onIndexChange(_ sender: NSButton) {
        self.volume.indexed = sender.state == .on
    }
    
    @IBAction func onHiddenChange(_ sender: NSButton) {
        self.volume.hidden = sender.state == .on
    }
    
    @IBAction func createTapped(_ sender: NSButton) {
        // Todo: Check for name
        // Todo: Check for integer size if no tmpFs
        
        TmpDiskManager.shared.createTmpDisk(volume: self.volume) { error in
            if let error = error {
                DispatchQueue.main.async {
                    switch error {
                    case .noName:
                        self.showError(message: "Your TmpDisk must have a name")
                        break;
                    case .exists:
                        self.showError(message: "A Volume named \(self.volume.name) already exists")
                        break;
                    case .invalidSize:
                        self.showError(message: "Size must be a number of megabytes > 0")
                        break;
                    case .failed:
                        self.showError(message: "Failed to create TmpDisk")
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
    
    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
