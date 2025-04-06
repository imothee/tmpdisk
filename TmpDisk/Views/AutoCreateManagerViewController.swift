//
//  AutoCreateManagerViewController.swift
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

class AutoCreateManagerViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    @IBOutlet weak var tableView: NSTableView!
    
    var volumes: [TmpDiskVolume] = []
    
    override func viewDidLoad() {
        self.volumes.append(contentsOf: Array(TmpDiskManager.shared.getAutoCreateVolumes()))
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.volumes.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let volume = self.volumes[row]
        
        switch (tableColumn?.identifier.rawValue) {
        case "name":
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = volume.name
            return cell
        case "size":
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = String(volume.size)
            return cell
        case "folders":
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = volume.folders.joined(separator: ",")
            return cell
        case "mountpoint":
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? NSTableCellView
            cell?.textField?.stringValue = volume.mountPoint ?? ""
            return cell
        case "filesystem":
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? DropdownTableCellView
            cell?.popupView.removeAllItems()
            cell?.popupView.addItems(withTitles: FileSystemManager.availableFileSystemDescriptions())
            if let selected = FileSystemManager.description(for: volume.fileSystem) {
                cell?.popupView.selectItem(withTitle: selected)
            }
            return cell
        case "indexed":
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? CheckboxTableCellView
            cell?.checkbox.state = volume.indexed ? .on : .off
            return cell
        case "noexec":
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? CheckboxTableCellView
            cell?.checkbox.state = volume.noExec ? .on : .off
            return cell
        case "hidden":
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? CheckboxTableCellView
            cell?.checkbox.state = volume.hidden ? .on : .off
            if FileSystemManager.isTmpFS(volume.fileSystem) {
                cell?.checkbox.isEnabled = false
            } else {
                cell?.checkbox.isEnabled = true
            }
            return cell
        case "warn":
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? CheckboxTableCellView
            cell?.checkbox.state = volume.warnOnEject ? .on : .off
            return cell
        default:
            let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? NSTableCellView
            return cell
        }
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            let row = tableView.row(for: textField)
            let column = tableView.column(for: textField)
            
            switch column {
            case 0:
                self.volumes[row].name = textField.stringValue
                break
            case 1:
                let newSize = textField.integerValue
                if newSize > 0 {
                    self.volumes[row].size = newSize
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Size must be a positive number in megabytes"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    return
                }
                break
            case 2:
                self.volumes[row].folders = textField.stringValue.split(separator: ",").map { String($0) }
                break
            case 3:
                self.volumes[row].mountPoint = textField.stringValue == "" ? nil : textField.stringValue
                break
            default:
                return
            }
            
            TmpDiskManager.shared.saveAutoCreateVolumes(volumes: Set(self.volumes))
        }
    }
    
    @IBAction func popupButtonDidChange(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        let fileSystem = FileSystemManager.availableFileSystems()[index]
        
        let row = tableView.row(for: sender)
        self.volumes[row].fileSystem = fileSystem.name
        
        self.tableView.reloadData()
        TmpDiskManager.shared.saveAutoCreateVolumes(volumes: Set(self.volumes))
    }
    
    @IBAction func checkboxDidChange(_ sender: AnyObject) {
        if let button = sender as? NSButton {
            let row = tableView.row(for: button)
            let column = tableView.column(for: button)
            
            switch column {
            case 5:
                self.volumes[row].indexed = button.state == .on
                break
            case 6:
                self.volumes[row].noExec = button.state == .on
                break
            case 7:
                self.volumes[row].hidden = button.state == .on
                break
            case 8:
                self.volumes[row].warnOnEject = button.state == .on
                break
            default:
                return
            }
            
            TmpDiskManager.shared.saveAutoCreateVolumes(volumes: Set(self.volumes))
        }
    }
    
    @IBAction func recreate(_ sender: AnyObject) {
        if let button = sender as? NSButton {
            let row = tableView.row(for: button)
            
            if confirmRecreate() {
                let volume = self.volumes[row]
                if volume.isMounted() {
                    TmpDiskManager.shared.ejectTmpDisksWithName(names: [volume.name], recreate: true)
                } else {
                    TmpDiskManager.shared.createTmpDisk(volume: volume, onCreate: {_ in })
                }
            }
        }
    }
    
    @IBAction func removeRow(_ sender: AnyObject) {
        if let button = sender as? NSButton {
            let row = tableView.row(for: button)
            
            self.volumes.remove(at: row)
            TmpDiskManager.shared.saveAutoCreateVolumes(volumes: Set(self.volumes))
            self.tableView.reloadData()
        }
    }
    
    @IBAction func addVolume(_ sender: AnyObject) {
        self.volumes.append(TmpDiskVolume())
        TmpDiskManager.shared.saveAutoCreateVolumes(volumes: Set(self.volumes))
        self.tableView.reloadData()
    }
    
    func confirmRecreate() -> Bool {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("This will eject and recreate the TmpDisk. All existing data will be lost.", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
