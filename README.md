# TmpDisk

TmpDisk is an Open Source simple RamDisk management tool. RamDisks are disks that use your memory (RAM) to create virtual hard disks on your Mac. RamDisks can be any size, limited only by your total memory and lightning fast. They are also temporary. Any files stored on a RamDisk will be permanently deleted when the disk is ejected. No need to worry about deleting, trash or cleaning up temporary files anymore. **Warning** A TmpDisk will not survive a restart or ejecting. Any files or information on the disk will be PERMANENTLY deleted once the computer is shutdown or the disk ejected. TmpDisks are perfect for

- Saving large files such as photos while editing
- Downloading and extracting zip files
- Storing of temporary logs and files
- Easily cleaning up tmp files
- **NEW in 2.3.0**: Folder syncs for persistent RAM disk workflows

## Support

For support, tracking updates, announcement and to participate in the Imothee Community please join us on [Discord](https://discord.gg/5UgyRYaEq6)

Maintaining TmpDisk for over [10 years](https://www.macupdate.com/app/mac/44022/tmpdisk) has been expensive and exhausting. If you can, please support us! We're looking for testers, volunteers, translators, advocates and donations.

## Installing

As of 2.3.0 TmpDisk supports macOS 10.13 (High Sierra) and later.

After 2.0.4 TmpDisk supports a minimum MacOS version of 10.14.6.

Down the latest release https://github.com/imothee/tmpdisk/releases/latest or clone the repository and build the application yourself. All required files are included.

## Usage

TmpDisk installs as a Status Bar application. You can use the menu to create new tmpdisks, eject existing tmpdisks and click on a disk to open it in finder.

## What's New in 2.3.0

### Standalone CLI
The command-line tool is now fully standalone and can create RAM disks without the GUI app running. Volumes created via CLI are automatically discovered by the GUI app.

### Folder Syncs
Sync a folder to/from your RAM disk:
- **On Create**: Contents are copied from the source folder to the RAM disk
- **Save Button**: A save icon appears in the menu for synced volumes
- **Auto-Save**: Optionally sync back to source on a schedule
- **Save on Eject**: Choose to save, discard, or prompt when ejecting

### Auto-Eject on Quit
New option to automatically eject volumes when the app quits.

## Folder Syncs Feature

Folder syncs let you copy a folder's contents to a RAM disk on creation, then save changes back when you're done.

### How It Works

1. **Create a synced RAM disk**: Specify a source folder when creating the disk
2. **Work at RAM speed**: Contents are copied to the RAM disk
3. **Save changes**: Click the save icon or use `tmpdisk save` to sync back
4. **Eject safely**: Choose whether to save changes when ejecting

### CLI Usage

```bash
# Create with folder sync
tmpdisk name=Work size=2GB --sync=/path/to/project --save-on-eject=yes

# Create with auto-save every 5 minutes
tmpdisk name=Cache size=512MB --sync=/path/to/cache --sync-interval=5

# Manually save changes back to source
tmpdisk save Work
```

## Command Line Interface

As of 2.3.0 TmpDisk includes a fully standalone CLI that can create RAM disks without requiring the GUI app to be running.

### Installation

Optionally install the CLI to your bin directory:
```bash
sudo ln -s /Applications/TmpDisk.app/Contents/Resources/TmpDiskCLI /usr/local/bin/tmpdisk
```

### Usage

```
TmpDisk CLI - Create and manage RAM disks

USAGE:
    tmpdisk [command] [options]

COMMANDS:
    create      Create a new RAM disk (default)
    eject       Eject a RAM disk
    save        Save RAM disk contents back to sync source
    list        List all TmpDisk volumes
    help        Show this help message

CREATE OPTIONS:
    name=NAME           Set the disk name (required)
    size=SIZE[MB|GB]    Set the disk size (default: 64MB)
    fs=FILESYSTEM       Set the filesystem type (default: APFS)
                        Available: APFS, APFSX, HFS+, TMPFS, HFSX, JHFS+, JHFSX

FLAGS:
    -a, --autocreate    Add to autocreate list (recreated on app startup)
    -i, --indexed       Enable Spotlight indexing
    -w, --warn          Warn on eject if volume has files
    -x, --noexec        Mount with noexec (requires admin)
    -H, --hidden        Hidden volume (nobrowse)
    -e, --autoeject     Eject when app quits
    --folders=a,b,c     Folders to create in volume

SYNC OPTIONS:
    --sync=PATH         Sync source folder (contents copied to/from RAM disk)
    --sync-interval=N   Auto-save interval in minutes (0 = manual only)
    --save-on-eject=X   Save on eject: yes, no, or prompt (default: prompt)

EJECT OPTIONS:
    --force             Force eject even if volume is in use

EXAMPLES:
    # Basic usage
    tmpdisk create name=MyDisk size=512MB fs=APFS --indexed --autocreate
    tmpdisk name=MyDisk size=1GB --hidden --noexec

    # With folder sync
    tmpdisk name=Work size=2GB --sync=/path/to/project --save-on-eject=yes
    tmpdisk name=Cache size=512MB --sync=/path/to/cache --sync-interval=5

    # Other commands
    tmpdisk save MyDisk           # Save contents back to sync source
    tmpdisk eject MyDisk
    tmpdisk eject MyDisk --force
    tmpdisk list

Note: TMPFS and --noexec require admin privileges.
      When using sudo, the volume is created for the invoking user.
```

### CLI-Created Volumes

Volumes created via CLI will:
- Write a `.tmpdisk` metadata file so the GUI app can discover them
- Appear in the GUI app's menu if the app is running
- Be added to autocreate list if `--autocreate` flag is used
- Sync from source folder on creation if `--sync` is specified

### Legacy App Arguments

As of 1.0.4 you can also run the app from the command line and pass in arguments to create a TmpDisk on startup.

`open -a /Applications/TmpDisk.app --args -name=TestDisk -size=64`

Will create a TmpDisk name TestDisk with 64MB space.
