# CLAUDE.md - TmpDisk Project Guide

## Project Overview

TmpDisk is a macOS application for creating and managing RAM disks (temporary virtual hard disks stored in memory). It has been actively maintained for over 10 years and is licensed under GPLv3.

**Key Value Proposition**: RAM disks are extremely fast and automatically clean up when ejected or on system restart, making them ideal for temporary file operations.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│         Main Application (TmpDisk)                       │
│  - GUI Status Bar Interface (AppKit/Cocoa)               │
│  - Disk Management & Mounting                            │
│  - User Preferences & Settings                           │
└─────────────┬───────────────────────────────────────────┘
              │ XPC Communication
              ↓
┌─────────────────────────────────────────────────────────┐
│    Privileged Helper (com.imothee.TmpDiskHelper)        │
│  - Runs with system privileges via SMJobBless            │
│  - Executes privileged disk operations (TMPFS)           │
│  - XPC server with code signature validation             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│    CLI Tool (TmpDiskCLI)                                │
│  - Command-line interface                               │
│  - Communicates via named pipe (/tmp/tmpdisk_cmd)       │
└─────────────────────────────────────────────────────────┘
```

## Directory Structure

```
/
├── TmpDisk/                    # Main GUI application (27 Swift files)
│   ├── AppDelegate.swift       # App entry point, lifecycle, command parsing
│   ├── TmpDiskManager.swift    # Singleton: volume creation/ejection/management
│   ├── StatusBarController.swift # System status bar menu
│   ├── XPCClient.swift         # Client for privileged helper communication
│   ├── WindowManager.swift     # Window management
│   └── ViewControllers/        # UI controllers (New, Preferences, AutoCreate, About)
│
├── Common/                     # Shared code between targets
│   ├── TmpDiskVolume.swift     # Volume data model (Codable)
│   ├── FileSystemManager.swift # Filesystem types (APFS, HFS+, TMPFS, etc.)
│   ├── DiskSizeManager.swift   # Size calculations and RAM validation
│   ├── Constants.swift         # Shared constants and TmpDiskError enum
│   └── Protocols.swift         # TmpDiskCreator XPC protocol
│
├── com.imothee.TmpDiskHelper/  # Privileged helper daemon
│   ├── TmpDiskCreator.swift    # Executes privileged shell commands
│   └── XPCServer.swift         # XPC listener with signature validation
│
├── TmpDiskCLI/                 # Command-line interface
│   └── main.swift              # CLI entry point, pipes to main app
│
├── TmpDiskLauncher/            # Login item launcher
└── TmpDiskTests/               # Unit and UI tests
```

## Key Technologies

- **Swift** - Primary language
- **AppKit/Cocoa** - macOS GUI framework
- **XPC** - Secure inter-process communication for privilege separation
- **ServiceManagement** - SMJobBless for helper installation
- **Sparkle** - Auto-update framework (SPM dependency)

## Build & Run

```bash
# Build from Xcode
open TmpDisk.xcodeproj

# Targets:
# - TmpDisk (main app)
# - com.imothee.TmpDiskHelper (privileged helper)
# - TmpDiskCLI (command-line tool)
# - TmpDiskTests (unit tests)
```

**Minimum macOS**: 11.5 (code may work on earlier versions)

## Key Patterns

### Singleton Pattern
- `TmpDiskManager.shared` - Central volume management
- `DiskSizeManager.shared` - Size calculations

### Notification Pattern
- `Notification.Name.tmpDiskMounted` - Posted when volumes mount/unmount

### XPC Protocol
```swift
@objc protocol TmpDiskCreator {
    func createVolume(_ command: String, withReply reply: @escaping (Int32, String?) -> Void)
    func ejectVolume(_ command: String, withReply reply: @escaping (Int32, String?) -> Void)
}
```

## Filesystem Support

| Type | Description | Notes |
|------|-------------|-------|
| APFS | Apple File System | Default, modern |
| APFSX | APFS Case-Sensitive | |
| HFS+ | Mac OS Extended | Legacy |
| TMPFS | Memory-only | Requires admin/helper |
| HFSX, JHFS+, JHFSX | HFS+ variants | |

## File Locations

- **App Config**: `UserDefaults` (autoCreate volumes, rootFolder, preferences)
- **TMPFS Root**: `~/.tmpdisk/` (configurable via rootFolder)
- **Volume Metadata**: `.tmpdisk` JSON file in each volume root
- **Named Pipe**: `/tmp/tmpdisk_cmd` (CLI communication)
- **Helper**: `/Library/PrivilegedHelperTools/com.imothee.TmpDiskHelper`

## Testing

```bash
# Run unit tests from Xcode or:
xcodebuild test -scheme TmpDisk -destination 'platform=macOS'
```

Tests cover:
- Disk creation validation (no name, success cases)
- Volume ejection
- Folder creation within volumes

## Localization

Supported languages:
- English (en)
- Spanish (es)
- Chinese Simplified (zh-Hans)

UI strings use `NSLocalizedString()`.

## Common Development Tasks

### Adding a new filesystem type
1. Add to `FileSystemManager.allFileSystems` array
2. Add detection method if needed (`isAPFS`, `isHFS`, etc.)
3. Update `createRamDiskTask()` in TmpDiskManager if special handling needed

### Adding a new preference
1. Add UI in `PreferencesViewController.swift`
2. Store/retrieve via `UserDefaults.standard`
3. Use in relevant managers

### Modifying privileged operations
1. Update `TmpDiskCreator.swift` in helper target
2. May require helper version bump and reinstallation

## Code Style

- Swift with AppKit (not SwiftUI)
- GPL-3.0 license headers on all source files
- Localized strings for all user-facing text
- Avoid force unwrapping except for static/guaranteed values
