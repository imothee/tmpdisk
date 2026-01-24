//
//  Logger.swift
//  TmpDisk
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

class Logger {
    static let shared = Logger()

    static var logFileURL: URL {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
        return logsDir.appendingPathComponent("TmpDisk.log")
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private let queue = DispatchQueue(label: "com.imothee.TmpDisk.logger")

    private init() {
        // Ensure logs directory exists
        let logsDir = Logger.logFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }

    private func write(_ message: String, level: String) {
        queue.async {
            let timestamp = self.dateFormatter.string(from: Date())
            let logLine = "[\(timestamp)] [\(level)] \(message)\n"

            // Also log to system console
            NSLog("TmpDisk: [%@] %@", level, message)

            // Append to log file
            let fileURL = Logger.logFileURL
            if let data = logLine.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: fileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: fileURL)
                }
            }
        }
    }

    func info(_ message: String) {
        write(message, level: "INFO")
    }

    func warning(_ message: String) {
        write(message, level: "WARNING")
    }

    func error(_ message: String) {
        write(message, level: "ERROR")
    }

    static func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }
}
