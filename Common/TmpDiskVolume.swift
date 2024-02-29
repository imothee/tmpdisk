//
//  TmpDiskVolume.swift
//  TmpDisk
//
//  Created by Tim on 2/28/24.
//

import Foundation

struct TmpDiskVolume: Hashable, Codable {
    var name: String = ""
    var size: Int = 16
    var autoCreate: Bool = false
    var indexed: Bool = false
    var hidden: Bool = false
    var tmpFs: Bool = false
    var caseSensitive: Bool = false
    var journaled: Bool = false
    var warnOnEject: Bool = false
    var folders: [String] = []
    var icon: String?
    
    func path() -> String {
        if tmpFs {
            return "\(TmpDiskManager.rootFolder)/\(name)"
        }
        return "/Volumes/\(name)"
    }
    
    func URL() -> URL {
        return NSURL.fileURL(withPath: self.path())
    }
    
    func dictionary() -> Dictionary<String, Any> {
        return [
            "name": name,
            "size": size,
            "indexed": indexed,
            "hidden": hidden,
            "tmpFs": tmpFs,
            "caseSensitive": caseSensitive,
            "journaled": journaled,
            "warnOnEject": warnOnEject,
            "folders": folders,
            "icon": icon ?? "",
        ]
    }
    
    func showWarning() -> Bool {
        if warnOnEject {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: self.path()) {
                if !files.filter({ ![".DS_Store", ".tmpdisk", ".fseventsd"].contains($0) }).isEmpty {
                    return true
                }
            }
        }
        return false
    }
}
