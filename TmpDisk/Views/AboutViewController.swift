//
//  AboutViewController.swift
//  TmpDisk
//
//  Created by Tim on 1/28/23.
//

import AppKit

class AboutViewController: NSViewController {
    @IBOutlet weak var issuesUrl: NSTextField!
    @IBOutlet weak var sourceUrl: NSTextField!
    
    override func viewDidLoad() {
        issuesUrl.allowsEditingTextAttributes = true
        issuesUrl.isSelectable = true
        
        sourceUrl.allowsEditingTextAttributes = true
        sourceUrl.isSelectable = true
        
        let issuesAttributedString = NSMutableAttributedString(string: issuesUrl.stringValue, attributes:[.link: URL(string: issuesUrl.stringValue)!])
        
        let sourceAttributedString = NSMutableAttributedString(string: sourceUrl.stringValue, attributes:[.link: URL(string: sourceUrl.stringValue)!])
        
        issuesUrl.attributedStringValue = issuesAttributedString
        sourceUrl.attributedStringValue = sourceAttributedString
    }
    
}
