#!/bin/sh

#  build.sh
#  TmpDisk
#
#  Created by Tim on 7/21/24.
#  

MAIN="com.imothee.TmpDisk"
HELPER="com.imothee.TmpDiskHelper"
GENERIC="anchor apple generic"

echo "Running build script for $PRODUCT_BUNDLE_IDENTIFIER"

if [ "$PRODUCT_BUNDLE_IDENTIFIER" == "$MAIN" ]; then
    echo "Building main target"
    
    # Bump build number
    #buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PROJECT_DIR}/${INFOPLIST_FILE}")
    #buildNumber=$(($buildNumber + 1))
    #/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "${PROJECT_DIR}/${INFOPLIST_FILE}"
    
    # Sync Developer Account
    
    IDENTIFIER="identifier \"$HELPER\""
    ORG_UNIT="certificate leaf[subject.OU] = \"$DEVELOPMENT_TEAM\""
    REQUIREMENTS="$GENERIC and $IDENTIFIER and $ORG_UNIT"
    
    echo "Set :SMPrivilegedExecutables:$HELPER \"$REQUIREMENTS\""
    echo "$PROJECT_DIR/$INFOPLIST_FILE"
    
    /usr/libexec/PlistBuddy -c "Set :SMPrivilegedExecutables:$HELPER \"$REQUIREMENTS\"" "$PROJECT_DIR/$INFOPLIST_FILE"
fi

if [ "$PRODUCT_BUNDLE_IDENTIFIER" == "$HELPER" ]; then
    echo "Building helper target"
    
    # Set the helper versions to be the latest version
    /usr/libexec/PlistBuddy -c "Set :TmpDiskHelperVersion $CURRENT_PROJECT_VERSION" "${PROJECT_DIR}/TmpDisk/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :Build $CURRENT_PROJECT_VERSION" "${PROJECT_DIR}/com.imothee.TmpDiskHelper/launchd.plist"
    
    # Sync Developer Account
    
    IDENTIFIER="identifier \"$MAIN\""
    ORG_UNIT="certificate leaf[subject.OU] = \"$DEVELOPMENT_TEAM\""
    REQUIREMENTS="$GENERIC and $IDENTIFIER and $ORG_UNIT"
    
    /usr/libexec/PlistBuddy -c "Set :SMAuthorizedClients:0 \"$REQUIREMENTS\"" "$INFOPLIST_FILE"
fi
