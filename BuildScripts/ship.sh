#!/bin/sh

# Ship a TmpDisk release end to end:
#   roll versions -> archive -> export (Developer ID) -> dmg -> notarize ->
#   sign for Sparkle -> commit+tag+push -> GitHub release -> publish appcasts
#
#   sh BuildScripts/ship.sh 2.3.1
#
# Re-runnable: finished phases are skipped when their artifacts exist.
#   SKIP_BUILD=1     reuse ./TmpDisk.app
#   SKIP_DMG=1       reuse build/TmpDisk.dmg
#   SKIP_NOTARIZE=1  app was already notarized (e.g. Xcode export)
#
# One-time machine setup the script cannot do for you:
#   1. Developer ID Application cert in the login keychain
#   2. xcrun notarytool store-credentials tmpdisk \
#        --apple-id <you@example.com> --team-id AGZ3AP53DM \
#        --password <app-specific-password>
#   3. keys/sparkle-keys.sh import '<eddsa private key from 1Password>'
#   4. gh auth login
# Per run: aws sso login --profile cg-prod (or set AWS_PROFILE).

set -eu

marketing=${1:-}
if [ -z "$marketing" ]; then
  echo "usage: $0 <marketing-version>   e.g. $0 2.3.1" >&2
  exit 2
fi
tag="v$marketing"
notary_profile=${NOTARY_PROFILE:-tmpdisk}
aws_profile=${AWS_PROFILE:-cg-prod}

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

info_plist="TmpDisk/Info.plist"
expected_edkey=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$info_plist")

die() { echo "ship: $*" >&2; exit 1; }

# --- preflight ---------------------------------------------------------------
echo "== preflight =="

[ "$(git branch --show-current)" = "main" ] || die "not on main"
# pbxproj/appcast may be dirty — the roll phase commits them. Anything else must be clean.
dirty=$(git status --porcelain | grep -v 'TmpDisk.xcodeproj/project.pbxproj\|appcast/' || true)
[ -z "$dirty" ] || die "uncommitted changes outside the release files:\n$dirty"
git fetch origin --tags --quiet
! git ls-remote --tags origin "$tag" | grep -q . || die "$tag already exists on origin"

security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || die "no Developer ID Application cert in keychain"

if [ -z "${SKIP_NOTARIZE:-}" ]; then
  xcrun notarytool history --keychain-profile "$notary_profile" >/dev/null 2>&1 \
    || die "no notarytool profile '$notary_profile' — run:
  xcrun notarytool store-credentials $notary_profile --apple-id <you> --team-id AGZ3AP53DM --password <app-specific-password>
  or export notarized via Xcode and set SKIP_NOTARIZE=1"
fi

sparkle_dir=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -type d -name 'TmpDisk-*' 2>/dev/null | head -1)
[ -n "$sparkle_dir" ] || die "no Sparkle tools — build once in Xcode first"
sparkle_bin="$sparkle_dir/SourcePackages/artifacts/sparkle/Sparkle/bin"
actual_edkey=$("$sparkle_bin/generate_keys" -p)
[ "$actual_edkey" = "$expected_edkey" ] \
  || die "keychain EdDSA key does not match SUPublicEDKey — run keys/sparkle-keys.sh import"

gh auth status >/dev/null 2>&1 || die "gh not authenticated"
aws sts get-caller-identity --profile "$aws_profile" >/dev/null 2>&1 \
  || die "AWS session expired — run: aws sso login --profile $aws_profile"

echo "all credentials present"

# --- roll versions -----------------------------------------------------------
current_marketing=$(sed -n 's/.*MARKETING_VERSION = \([0-9][0-9.]*\);/\1/p' TmpDisk.xcodeproj/project.pbxproj | sort -rV | head -1)
if [ "$current_marketing" != "$marketing" ]; then
  echo "== roll: $current_marketing -> $marketing =="
  sh BuildScripts/release.sh "$marketing"
fi
git add TmpDisk.xcodeproj/project.pbxproj appcast/*.json
if ! git diff --cached --quiet -- TmpDisk.xcodeproj/project.pbxproj appcast; then
  git commit -m "chore: roll $tag" -- TmpDisk.xcodeproj/project.pbxproj appcast
else
  echo "== roll: already at $marketing =="
fi

# --- build -------------------------------------------------------------------
if [ -n "${SKIP_BUILD:-}" ] && [ -d "TmpDisk.app" ]; then
  echo "== archive: reusing ./TmpDisk.app =="
else
  echo "== archive =="
  rm -rf build/TmpDisk.xcarchive build/export
  xcodebuild -project TmpDisk.xcodeproj -scheme TmpDisk -configuration Release \
    -archivePath build/TmpDisk.xcarchive -allowProvisioningUpdates archive
  xcodebuild -exportArchive -archivePath build/TmpDisk.xcarchive \
    -exportOptionsPlist BuildScripts/ExportOptions.plist -exportPath build/export
  rm -rf TmpDisk.app
  mv build/export/TmpDisk.app .
fi

# --- dmg + notarize ----------------------------------------------------------
if [ -n "${SKIP_DMG:-}" ] && [ -f build/TmpDisk.dmg ]; then
  echo "== dmg: reusing build/TmpDisk.dmg =="
else
  echo "== dmg =="
  npx appdmg@latest ./appdmg.json ./build/TmpDisk.dmg
  if [ -n "${SKIP_NOTARIZE:-}" ]; then
    echo "== notarize: skipped (app exported notarized) =="
  else
    echo "== notarize =="
    xcrun notarytool submit build/TmpDisk.dmg \
      --keychain-profile "$notary_profile" --wait
    xcrun stapler staple build/TmpDisk.dmg
  fi
fi

# --- sparkle signature -> current feed enclosure -----------------------------
if ! grep -q '"edSignature"' appcast/current.json; then
  echo "== sign for sparkle =="
  sig_out=$("$sparkle_bin/sign_update" build/TmpDisk.dmg)
  ed_sig=$(echo "$sig_out" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
  length=$(echo "$sig_out" | sed -n 's/.*length="\([0-9]*\)".*/\1/p')
  [ -n "$ed_sig" ] && [ -n "$length" ] || die "could not parse sign_update output"
  dmg_url="https://github.com/imothee/tmpdisk/releases/download/$tag/TmpDisk.dmg"
  python3 - "$dmg_url" "$length" "$ed_sig" <<'EOF'
import json, sys
url, length, sig = sys.argv[1:4]
path = "appcast/current.json"
data = json.load(open(path))
rel = data["releases"][0]
rel.pop("downloadPageUrl", None)
rel.update(url=url, length=int(length),
           mimeType="application/octet-stream", edSignature=sig)
json.dump(data, open(path, "w"), indent=2)
EOF
  git add appcast/current.json
  git commit -m "chore: $tag sparkle enclosure" -- appcast/current.json 2>/dev/null || true
fi

# --- tag, push, github release ----------------------------------------------
git tag -f "$tag" >/dev/null
echo "== push =="
git push origin main
git push origin "$tag"
if ! gh release view "$tag" >/dev/null 2>&1; then
  echo "== github release =="
  gh release create "$tag" build/TmpDisk.dmg \
    --title "TmpDisk $marketing" --generate-notes --latest
fi

# --- publish appcasts --------------------------------------------------------
echo "== publish appcasts =="
npm run appcast:render
AWS_PROFILE="$aws_profile" npm run appcast:publish -- all

# --- verify ------------------------------------------------------------------
echo "== verify =="
curl -fsSL https://appable.xyz/updates/tmpdisk.xml | grep -o 'sparkle:version>[0-9]*' | head -1
curl -fsSL https://appcast.cosmicglue.io/tmpdisk.xml | grep -o 'sparkle:version>[0-9]*' | head -1
echo "done — check a pre-2.3.0 install offers the informational update"
