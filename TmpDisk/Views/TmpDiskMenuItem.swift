//
//  TmpDiskMenuItem.swift
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



class TmpDiskMenuItem: NSMenuItem {
    let clickHandler: () -> Void
    let recreateHandler: () -> Void
    let ejectHandler: () -> Void
    
    required init(title string: String, action selector: Selector?, keyEquivalent charCode: String, clickHandler: @escaping () -> Void, recreateHandler: @escaping () -> Void, ejectHandler: @escaping () -> Void) {
        self.clickHandler = clickHandler
        self.recreateHandler = recreateHandler
        self.ejectHandler = ejectHandler
        
        super.init(title: string, action: selector, keyEquivalent: charCode)
        
        let view = NSView.init(frame: NSRect(x: 0, y: 0, width: 150, height: 25))

        let label = NSButton(frame: NSRect(x: 20, y: 2.5, width: 90, height: 20))
        label.action = #selector(onClick(sender:))
        label.target = self
        label.title = title
        label.isBordered = false
        label.alignment = .left
        view.addSubview(label)

        let recreate = NSButton(frame: NSRect(x: 110, y: 5, width: 15, height: 15))
        recreate.action = #selector(onRecreate(sender:))
        recreate.target = self
        recreate.image = NSImage(named: "recreate_a")
        recreate.alternateImage = NSImage(named: "recreate")
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
    
    @objc func onClick(sender: NSButton) {
        self.clickHandler()
    }
    
    @objc func onRecreate(sender: NSButton) {
        self.recreateHandler()
    }
    
    @objc func onEject(sender: NSButton) {
        self.ejectHandler()
    }
}
