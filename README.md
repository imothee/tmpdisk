# TmpDisk

TmpDisk is an Open Source simple RamDisk management tool. RamDisks are disks that use your memory (RAM) to create virtual hard disks on your Mac. RamDisks can be any size, limited only by your total memory and lightning fast. They are also temporary. Any files stored on a RamDisk will be permanently deleted when the disk is ejected. No need to worry about deleting, trash or cleaning up temporary files anymore. **Warning** A TmpDisk will not survive a restart or ejecting. Any files or information on the disk will be PERMANENTLY deleted once the computer is shutdown or the disk ejected. TmpDisks are perfect for

- Saving large files such as photos while editing
- Downloading and extracting zip files
- Storing of temporary logs and files
- Easily cleaning up tmp files

## Installing

After 2.0.4 TmpDisk supports a minimum MacOS version of 10.14.6.

Down the latest release https://github.com/imothee/tmpdisk/releases/latest or clone the repository and build the application yourself. All required files are included.

## Usage

TmpDisk installs as a Status Bar application. You can use the menu to create new tmpdisks, eject existing tmpdisks and click on a disk to open it in finder.

As of 2.2.0 there is now a CLI helper that lets you create TmpDisks from the command line
Optionally install the CLI to your bin directory
`sudo ln -s /Applications/TmpDisk.app/Contents/Resources/TmpDiskCLI /usr/local/bin/tmpdisk`

Usage

```
TmpDisk Command Help
===================

Commands:
  help                    Display this help message

Parameters:
  name=VALUE              Set the disk name (default: TmpDisk)
  size=VALUE[MB|GB]       Set the disk size (default: 64MB)
  units=[MB|GB]           Set the size units (default: MB)
  fs=FILESYSTEM           Set the filesystem type (default: APFS)
                          Available: APFS, APFSX, HFS+, TMPFS, HFSX, JHFS+, JHFSX

Examples:
  tmpdisk name=MyDisk size=1GB
  tmpdisk size=512 fs=HFS+
  tmpdisk help

Note: Parameters can be prefixed with '-' (e.g., -name=MyDisk)
```

As of 1.0.4 you can also run the app from the command line and pass in arguments to create a TmpDisk on startup.

`open -a /Applications/TmpDisk.app --args -name=TestDisk -size=64`

Will create a TmpDisk name TestDisk with 64MB space.
