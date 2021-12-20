//
//  StatusBarController.swift
//  TmpDisk
//
//  Created by Tim on 12/11/21.
//

import AppKit
import ServiceManagement

class StatusBarController {
    private var statusItem: NSStatusItem
    private var statusMenu: NSMenu
    private var currentTmpDisksMenu: NSMenu
    
    private let launcherAppId = "com.imothee.TmpDiskLauncher"
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: 28.0)
        statusMenu = NSMenu()
        currentTmpDisksMenu = NSMenu()
        
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
        
        let checkUpdateItem = NSMenuItem(title: NSLocalizedString("Check for Updates", comment: ""), action: #selector(checkUpdate(sender:)), keyEquivalent: "")
        checkUpdateItem.target = self
        statusMenu.addItem(checkUpdateItem)
        
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
    
    // MARK: - Internal
    
    func buildCurrentTmpDiskMenu() {
        self.currentTmpDisksMenu.removeAllItems()
        for volume in TmpDiskManager.shared.volumes {
            let volumeItem = TmpDiskMenuItem.init(title: volume.name, action: nil, keyEquivalent: "", recreateHandler: {
                TmpDiskManager.shared.ejectTmpDisksWithName(names: [volume.name], recreate: true)
                self.statusMenu.cancelTracking()
            }, ejectHandler: {
                TmpDiskManager.shared.ejectTmpDisksWithName(names: [volume.name], recreate: false)
                self.statusMenu.cancelTracking()
            })
            self.currentTmpDisksMenu.addItem(volumeItem)
        }
    }
    
    // MARK: - Actions
    
    @objc func newTmpDisk(sender: AnyObject) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let newTmpDiskWindow = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "NewTmpDiskWindow") as? NSWindowController
        newTmpDiskWindow?.showWindow(nil)
        newTmpDiskWindow?.window?.makeKey()
    }
    
    @objc func recreateAll(sender: AnyObject) {
        TmpDiskManager.shared.ejectAllTmpDisks(recreate: true)
    }
    
    @objc func autoCreateManager(sender: AnyObject) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let autoCreateManagerWindow = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "AutoCreateManagerWindow") as? NSWindowController
        autoCreateManagerWindow?.showWindow(nil)
        autoCreateManagerWindow?.window?.makeKey()
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
    
    @objc func checkUpdate(sender: AnyObject) {
        
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
