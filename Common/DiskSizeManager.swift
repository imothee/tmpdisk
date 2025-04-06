//
//  DiskSizeManager.swift
//  TmpDisk
//
//  Created on 06/04/25.
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

enum DiskSizeUnit: Int {
    case mb = 0  // Megabytes
    case gb = 1  // Gigabytes
    
    var displayName: String {
        switch self {
        case .mb:
            return "MB"
        case .gb:
            return "GB"
        }
    }
}

class DiskSizeManager {
    static let shared = DiskSizeManager()
    
    // MARK: - RAM Size Properties
    
    /// Total physical RAM in megabytes
    var totalRamSizeMB: Double {
        return Double(ProcessInfo.init().physicalMemory) / 1024 / 1024
    }
    
    /// Maximum allowed size for TmpFS volumes (50% of RAM) in megabytes
    var maxTmpFSSizeMB: Double {
        return totalRamSizeMB * 0.5
    }
    
    // MARK: - RAM Size Percentages
    
    /// Get RAM size for a specific percentage in MB
    func ramSizeForPercentage(_ percentage: Double) -> Double {
        return totalRamSizeMB * percentage
    }
    
    /// Get the common RAM size percentages (10%, 25%, 50%, 75%)
    func commonRamSizePercentages() -> [Double] {
        return [0.1, 0.25, 0.5, 0.75]
    }
    
    // MARK: - Unit Conversion
    
    /// Convert size from MB to GB
    func convertMBtoGB(_ sizeMB: Double) -> Double {
        return sizeMB / 1000.0
    }
    
    /// Convert size from GB to MB
    func convertGBtoMB(_ sizeGB: Double) -> Double {
        return sizeGB * 1000.0
    }
    
    /// Convert size between units
    func convertSize(_ size: Double, from fromUnit: DiskSizeUnit, to toUnit: DiskSizeUnit) -> Double {
        switch (fromUnit, toUnit) {
        case (.mb, .gb):
            return convertMBtoGB(size)
        case (.gb, .mb):
            return convertGBtoMB(size)
        case (.mb, .mb):
            return size
        case (.gb, .gb):
            return size
        }
    }
    
    // MARK: - String Formatting
    
    /// Format size in MB as a string in the given unit
    func formatSize(_ sizeMB: Double, in unit: DiskSizeUnit) -> String {
        switch unit {
        case .mb:
            return String(Int(sizeMB))
        case .gb:
            return String(format: "%.2f", convertMBtoGB(sizeMB))
        }
    }
    
    // MARK: - Validation
    
    /// Validates if the size is within the TmpFS limit
    /// - Parameters:
    ///   - size: The size to validate
    ///   - unit: The unit of the provided size
    /// - Returns: A tuple containing (isValid, correctedSize)
    func validateDiskSize(_ size: Double, in unit: DiskSizeUnit, isTmpFS: Bool = false) -> (isValid: Bool, correctedSizeMB: Double) {
        let sizeInMB = unit == .mb ? size : convertGBtoMB(size)
        
        if isTmpFS && sizeInMB > maxTmpFSSizeMB {
            return (false, maxTmpFSSizeMB)
        } else if sizeInMB < 0 {
            return (false, 1)
        } else if sizeInMB > ( totalRamSizeMB - 2048) {
            // Hold back at least 2GB
            return (false, totalRamSizeMB - 2048)
        }
        
        return (true, sizeInMB)
    }
    
    /// Shows a warning alert about the TmpFS size limitation
    func showTmpFSSizeWarning() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("TmpFS volumes are limited to 50% of RAM. Setting to maximum allowed value.", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showInsufficientRamWarning() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Insufficient RAM to allocate to TmpDisk. Please reduce the size.", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
