//
//  StatusBarController.swift
//  TmpDisk
//
//  Created by Tim on 12/11/21.
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

import AppKit
import ServiceManagement
import Sparkle

class StatusBarController {
    private var statusItem: NSStatusItem
    private var statusMenu: NSMenu
    private var currentTmpDisksMenu: NSMenu
    
    private let launcherAppId = "com.imothee.TmpDiskLauncher"
    private let updaterController: SPUStandardUpdaterController
    
    private let windowManager = WindowManager()
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: 28.0)
        statusMenu = NSMenu()
        currentTmpDisksMenu = NSMenu()
        
        // Sparkle
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        // Check to see the app is in the login items
        let jobDicts = SMCopyAllJobDictionaries( kSMDomainUserLaunchd ).takeRetainedValue() as NSArray as! [[String:AnyObject]]
        let startOnLogin = jobDicts.filter { $0["Label"] as! String == self.launcherAppId }.isEmpty == false
        
        // Create the menu
        if let statusBarButton = statusItem.button {
            statusBarButton.image = NSImage(named: "disk")
            statusBarButton.image?.size = NSSize(width: 18.0, height: 18.0)
            statusBarButton.image?.isTemplate = true
        }
        
        // New TmpDisk section
        let newTmpDiskItem = NSMenuItem(title: NSLocalizedString("New TmpDisk", comment: ""), action: #selector(newTmpDisk(sender:)), keyEquivalent: "n")
        newTmpDiskItem.target = self
        statusMenu.addItem(newTmpDiskItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        // Existing TmpDisk section
        let currentTmpDisksItem = NSMenuItem(title: NSLocalizedString("Current TmpDisks", comment: ""), action: nil, keyEquivalent: "")
        
        statusMenu.addItem(currentTmpDisksItem)
        statusMenu.setSubmenu(self.currentTmpDisksMenu, for: currentTmpDisksItem)
        
        self.buildCurrentTmpDiskMenu()
        
        // Recreate All
        let recreateAllItem = NSMenuItem(title: NSLocalizedString("Recreate All", comment: ""), action: #selector(recreateAll(sender:)), keyEquivalent: "")
        recreateAllItem.target = self
        statusMenu.addItem(recreateAllItem)
        
        // AutocreateManager
        let autoCreateManagerItem = NSMenuItem(title: NSLocalizedString("AutoCreate Manager", comment: ""), action: #selector(autoCreateManager(sender:)), keyEquivalent: "")
        autoCreateManagerItem.target = self
        statusMenu.addItem(autoCreateManagerItem)
        
        // Separator
        statusMenu.addItem(NSMenuItem.separator())
        
        // Settings section
        let startLoginItem = NSMenuItem(title: NSLocalizedString("Always Start on Login", comment: ""), action: #selector(toggleStartOnLogin(sender:)), keyEquivalent: "")
        startLoginItem.target = self
        startLoginItem.state = startOnLogin ? .on : .off
        statusMenu.addItem(startLoginItem)
        
        let checkUpdateItem = NSMenuItem(title: NSLocalizedString("Check for Updates", comment: ""), action:nil, keyEquivalent: "")
        checkUpdateItem.target = updaterController
        checkUpdateItem.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        statusMenu.addItem(checkUpdateItem)
        
        let preferencesItem = NSMenuItem(title: NSLocalizedString("Preferences", comment: ""), action: #selector(preferences(sender:)), keyEquivalent: "")
        preferencesItem.target = self
        statusMenu.addItem(preferencesItem)
        
        // Separator
        statusMenu.addItem(NSMenuItem.separator())
        
        // Help and about section
        let helpItem = NSMenuItem(title: NSLocalizedString("Help Center", comment: ""), action: #selector(help(sender:)), keyEquivalent: "")
        helpItem.target = self
        statusMenu.addItem(helpItem)
        
        let aboutItem = NSMenuItem(title: NSLocalizedString("About TmpDisk", comment: ""), action: #selector(about(sender:)), keyEquivalent: "")
        aboutItem.target = self
        statusMenu.addItem(aboutItem)
        
        // Separator
        statusMenu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quit(sender:)), keyEquivalent: "")
        quitItem.target = self
        statusMenu.addItem(quitItem)
        
        // Add the menu to the item
        statusItem.menu = statusMenu
    }
    
    func windowWillClose(window: NSWindowController) {
        
    }
    
    // MARK: - Internal
    
    func confirmEject(volume: TmpDiskVolume) -> Bool {
        if (volume.showWarning()) {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Volume contains files, are you sure you want to eject?", comment: "")
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            return alert.runModal() == .alertFirstButtonReturn
        }
        return true
    }
    
    func buildCurrentTmpDiskMenu() {
        self.currentTmpDisksMenu.removeAllItems()
        for volume in TmpDiskManager.shared.volumes {
            let volumeItem = TmpDiskMenuItem.init(title: volume.name, action: nil, keyEquivalent: "", clickHandler: {
                NSWorkspace.shared.open(volume.URL())
                self.statusMenu.cancelTracking()
            }, recreateHandler: {
                if self.confirmEject(volume: volume) {
                    TmpDiskManager.shared.ejectTmpDisksWithName(names: [volume.name], recreate: true)
                }
                self.statusMenu.cancelTracking()
            }, ejectHandler: {
                if self.confirmEject(volume: volume) {
                    TmpDiskManager.shared.ejectTmpDisksWithName(names: [volume.name], recreate: false)
                }
                self.statusMenu.cancelTracking()
            })
            volumeItem.target = self
            self.currentTmpDisksMenu.addItem(volumeItem)
        }
    }
    
    // MARK: - Actions
    
    @objc func newTmpDisk(sender: AnyObject) {
        windowManager.showNewTmpDiskWindow()
    }
    
    @objc func recreateAll(sender: AnyObject) {
        TmpDiskManager.shared.ejectAllTmpDisks(recreate: true)
    }
    
    @objc func autoCreateManager(sender: AnyObject) {
        windowManager.showAutoCreateManagerWindow()
    }
    
    @objc func toggleStartOnLogin(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            if menuItem.state == .on {
                SMLoginItemSetEnabled(self.launcherAppId as CFString, false)
                menuItem.state = .off
            } else {
                SMLoginItemSetEnabled(self.launcherAppId as CFString, true)
                menuItem.state = .on
            }
        }
    }
    
    @objc func preferences(sender: AnyObject) {
        windowManager.showPreferencesWindow()
    }
    
    @objc func help(sender: AnyObject) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Help content", comment: "Help content string")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func about(sender: AnyObject) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("About content", comment: "About content string")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func quit(sender: AnyObject) {
        NSApp.terminate(nil)
    }
}
