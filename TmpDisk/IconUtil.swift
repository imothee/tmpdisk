//
//  IconUtil.swift
//  TmpDisk
//
//  Created by Tim on 12/17/22.
//

import Foundation
import AppKit

class IconUtil {
    private let iconutilPath = "/usr/bin/iconutil"
    
    static let shared: IconUtil = {
        let instance = IconUtil()
        // setup code
        return instance
    }()
    
    private func createIconSet(image: NSImage, iconSetURL: URL) throws {
        // Create the iconset directory
        try FileManager.default.createDirectory(at: iconSetURL, withIntermediateDirectories: true)
        
        // Write out all the icon files
        for dimension in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let size = NSSize(width: dimension * scale, height: dimension * scale)
                let filename = "icon_\(dimension)x\(dimension)\(scale == 1 ? "" : "@\(scale)x").png"

                let frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
                guard let representation = image.bestRepresentation(for: frame, context: nil, hints: nil) else {
                    print("Issue loading tiff from image")
                    return
                }
                let newImage = NSImage(size: size, flipped: false, drawingHandler: { (_) -> Bool in
                    return representation.draw(in: frame)
                })
                guard let tiffRep = newImage.tiffRepresentation,
                      let bitmapRep = NSBitmapImageRep(data: tiffRep),
                      let pngData = bitmapRep.representation(using: .png, properties: [:])
                else {
                    return
                }
                
                try pngData.write(to: iconSetURL.appendingPathComponent(filename))
            }
        }
    }
    
    func convertImageToICNS(image: NSImage) throws -> String {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let iconSetURL = tmpDir.appendingPathComponent("icon.iconset")
        let iconURL = tmpDir.appendingPathComponent("icon.icns")
        
        // Get the iconset of all the sized images
        try self.createIconSet(image: image, iconSetURL: iconSetURL)
        
        // Now we need to convert to an icns
        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", "icns", iconSetURL.lastPathComponent]
        
        process.launchPath = iconutilPath
        process.currentDirectoryPath = tmpDir.path
        process.launch()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            print("FAILED")
        }
        
        let data = try Data(contentsOf: iconURL)
        try? FileManager.default.removeItem(at: tmpDir)
        return data.base64EncodedString()
    }
    
}
