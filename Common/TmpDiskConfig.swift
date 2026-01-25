//
//  TmpDiskConfig.swift
//  TmpDisk
//
//  Created by Claude on 2025.
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

/// Shared configuration for TmpDisk that works in both the app and CLI contexts
struct TmpDiskConfig {
    /// The default TmpDisk home directory
    /// Handles SUDO_USER to get the real user's home when running as root
    static var tmpDiskHome: String {
        let homeDir: String

        // When running via sudo, get the original user's home directory
        if let sudoUser = ProcessInfo.processInfo.environment["SUDO_USER"] {
            // Use the original user's home directory
            if let pw = getpwnam(sudoUser) {
                homeDir = String(cString: pw.pointee.pw_dir)
            } else {
                homeDir = NSHomeDirectory()
            }
        } else {
            homeDir = NSHomeDirectory()
        }

        return "\(homeDir)/.tmpdisk"
    }

    /// The root folder for TMPFS volumes
    /// Uses the app's UserDefaults if available, otherwise uses tmpDiskHome
    static var rootFolder: String {
        // Try to read from app's UserDefaults first
        if let folder = UserDefaults.standard.string(forKey: "rootFolder"), !folder.isEmpty {
            return folder
        }

        return tmpDiskHome
    }

    /// The app's bundle identifier for UserDefaults access from CLI
    static let appBundleId = "com.imothee.TmpDisk"

    /// Get UserDefaults for the app (works from both app and CLI contexts)
    static var appDefaults: UserDefaults {
        // When running as CLI, we need to access the app's preferences via suite name
        // When running as the app itself, standard defaults work
        if Bundle.main.bundleIdentifier == appBundleId {
            return UserDefaults.standard
        } else {
            return UserDefaults(suiteName: appBundleId) ?? UserDefaults.standard
        }
    }

    /// Check if we're running as root
    static var isRoot: Bool {
        return getuid() == 0
    }

    /// Check if we're running via sudo (has SUDO_USER set)
    static var isSudo: Bool {
        return ProcessInfo.processInfo.environment["SUDO_USER"] != nil
    }
}
