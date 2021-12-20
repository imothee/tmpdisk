//
//  TmpDiskMenuItem.swift
//  TmpDisk
//
//  Created by Tim on 12/19/21.
//

import Foundation
import AppKit



class TmpDiskMenuItem: NSMenuItem {
    let recreateHandler: () -> Void
    let ejectHandler: () -> Void
    
    required init(title string: String, action selector: Selector?, keyEquivalent charCode: String, recreateHandler: @escaping () -> Void, ejectHandler: @escaping () -> Void) {
        self.recreateHandler = recreateHandler
        self.ejectHandler = ejectHandler
        
        super.init(title: string, action: selector, keyEquivalent: charCode)
        
        let view = NSView.init(frame: NSRect(x: 0, y: 0, width: 150, height: 25))
        
        let label = NSTextField(frame: NSRect(x: 20, y: 2.5, width: 90, height: 20))
        label.stringValue = string
        label.isBezeled = false
        label.isEditable = false
        label.isBordered = false
        label.isSelectable = false
        label.drawsBackground = false
        view.addSubview(label)
        
        let recreate = NSButton(frame: NSRect(x: 110, y: 5, width: 15, height: 15))
        recreate.action = #selector(onRecreate(sender:))
        recreate.target = self
        recreate.image = NSImage(named: "recreate")
        recreate.alternateImage = NSImage(named: "recreate_a")
        recreate.imagePosition = .imageOnly
        recreate.isBordered = false
        view.addSubview(recreate)
        
        let eject = NSButton(frame: NSRect(x: 130, y: 5, width: 15, height: 15))
        eject.action = #selector(onEject(sender:))
        eject.target = self
        eject.image = NSImage(named: "eject")
        eject.alternateImage = NSImage(named: "eject_a")
        eject.imagePosition = .imageOnly
        eject.isBordered = false
        view.addSubview(eject)
        
        self.view = view
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Actions
    
    @objc func onRecreate(sender: NSButton) {
        self.recreateHandler()
    }
    
    @objc func onEject(sender: NSButton) {
        self.ejectHandler()
    }
}
