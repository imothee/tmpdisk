//
//  WindowManager.swift
//  TmpDisk
//
//  Created by Tim on 2/12/22.
//

import Foundation
import AppKit

class WindowManager: NSObject, NSWindowDelegate {
    private var newTmpDiskWindow: NSWindowController?
    private var autoCreateManagerWindow: NSWindowController?
    private var preferencesWindow: NSWindowController?
   
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            switch window.windowController {
            case newTmpDiskWindow:
                newTmpDiskWindow = nil
                break
            case autoCreateManagerWindow:
                autoCreateManagerWindow = nil
                break
            case preferencesWindow:
                preferencesWindow = nil
                break
            default:
                return
            }
        }
    }
    
    func showNewTmpDiskWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        if newTmpDiskWindow == nil {
            newTmpDiskWindow = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "NewTmpDiskWindow") as? NSWindowController
            newTmpDiskWindow?.window?.delegate = self
        }
        
        newTmpDiskWindow?.showWindow(nil)
        newTmpDiskWindow?.window?.makeKey()
    }
    
    func showAutoCreateManagerWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        if autoCreateManagerWindow == nil {
            autoCreateManagerWindow = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "AutoCreateManagerWindow") as? NSWindowController
            autoCreateManagerWindow?.window?.delegate = self
        }
        
        autoCreateManagerWindow?.showWindow(nil)
        autoCreateManagerWindow?.window?.makeKey()
    }
    
    func showPreferencesWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        if preferencesWindow == nil {
            preferencesWindow = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "PreferencesWindow") as? NSWindowController
            preferencesWindow?.window?.delegate = self
        }
        
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKey()
    }
}
