#!/bin/bash

# Ensure the build directory exists
[ ! -d "./build" ] && mkdir "./build"

# Ensure we have a TmpDisk.app in the folder
if [ ! -f "./TmpDisk.app" ]; then
    echo "Error: TmpDisk.app not found in the current directory"
    exit 1
fi

# Package the TmpDisk.app into the dmg
npx appdmg@latest appdmg ./appdmg.json ./build/TmpDisk.dmg

# Find the sparkle-project folder
#sparkle = ls -t "~/Library/Developer/Xcode/DerivedData/TmpDisk-" | head -1
sparkle=$(find ~/Library/Developer/Xcode/DerivedData -type d -maxdepth 1 -print | grep -m1 'TmpDisk-')

# Sign the dmg
"$sparkle"/SourcePackages/artifacts/sparkle/bin/generate_appcast -f ./keys/dsa_priv.pem ./build