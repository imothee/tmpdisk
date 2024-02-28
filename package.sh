#!/bin/bash

echo "Ensure you have the latest appdmg installed"
echo "npm install -g appdmg"

npx appdmg ./appdmg.json ./TmpDisk.dmg
