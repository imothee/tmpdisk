#!/bin/sh

# Roll a release: bump the build number, set the marketing version, and sync
# the appcast manifests so the feed can never disagree with the binary again.
#
#   sh BuildScripts/release.sh 2.3.1          # auto-increment build number
#   sh BuildScripts/release.sh 2.3.1 1021     # explicit build number
#
# Only the TmpDisk target rides the shared 10xx build sequence; the helper,
# launcher and test targets keep their own. MARKETING_VERSION is bumped on
# every target that tracked the previous app version (TmpDisk + Launcher),
# never on the helper, which is versioned independently.

set -eu

marketing=${1:-}
build=${2:-}

if [ -z "$marketing" ]; then
  echo "usage: $0 <marketing-version> [build-number]" >&2
  exit 2
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
pbxproj="$project_dir/TmpDisk.xcodeproj/project.pbxproj"

# The TmpDisk target holds the largest CURRENT_PROJECT_VERSION in the file.
old_build=$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9][0-9]*\);/\1/p' "$pbxproj" | sort -rn | head -1)
occurrences=$(grep -c "CURRENT_PROJECT_VERSION = $old_build;" "$pbxproj")
if [ "$occurrences" -ne 2 ]; then
  echo "expected $old_build on exactly the TmpDisk Debug+Release configs, found $occurrences" >&2
  exit 1
fi
new_build=${build:-$((old_build + 1))}

old_marketing=$(sed -n 's/.*MARKETING_VERSION = \([0-9][0-9.]*\);/\1/p' "$pbxproj" | sort -rV | head -1)

sed -i '' "s/CURRENT_PROJECT_VERSION = $old_build;/CURRENT_PROJECT_VERSION = $new_build;/g" "$pbxproj"
sed -i '' "s/MARKETING_VERSION = $old_marketing;/MARKETING_VERSION = $marketing;/g" "$pbxproj"

published_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for manifest in "$project_dir"/appcast/current.json "$project_dir"/appcast/legacy.json; do
  sed -i '' \
    -e "s/\"version\": \"[0-9]*\"/\"version\": \"$new_build\"/" \
    -e "s/\"shortVersion\": \"[^\"]*\"/\"shortVersion\": \"$marketing\"/" \
    -e "s|\"publishedAt\": \"[^\"]*\"|\"publishedAt\": \"$published_at\"|" \
    -e "s|/releases/tag/v[^\"]*|/releases/tag/v$marketing|" \
    "$manifest"
done

echo "TmpDisk $marketing ($new_build), was $old_marketing ($old_build)"
echo "Review: git diff; render check: npm run appcast:render"
