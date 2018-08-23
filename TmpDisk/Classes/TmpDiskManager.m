//
//  TmpDiskManager.m
//  TmpDisk
//
//  Created by Timothy Marks on 22/11/11.
//  Copyright (c) 2011 Ink Scribbles Pty Ltd. All rights reserved.
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

#import "TmpDiskManager.h"

@implementation TmpDiskFile

- (BOOL)exists {
    return [[NSFileManager defaultManager]
            fileExistsAtPath:[TmpDiskManager pathForName:self.name]
            isDirectory:nil];
}

@end

@implementation TmpDiskManager

+ (NSString *)pathForName:(NSString *)name {
    return [NSString stringWithFormat:@"/Volumes/%@", name];
}

+ (void)autoCreateVolumesWithNames:(NSSet<NSString *> *)names {

    for (TmpDiskFile *disk in [self knownVolumesWithNames:names]) {
        if (disk.exists) {
            continue;
        }

        [self createTmpDiskWithName:disk.name
                               size:disk.size
                         autoCreate:NO
                            indexed:disk.indexed
                             hidden:disk.hidden
                            folders:disk.folders
                          onSuccess:nil];
    }
}

+ (NSArray<TmpDiskFile *> *)knownVolumesWithNames:(NSSet<NSString *> *)names {

    NSMutableArray *results = [[NSMutableArray alloc] init];

    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"]) {

        NSArray *autoCreateArray =
        [[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"];

        for (NSDictionary *d in autoCreateArray) {

            NSString *name = d[@"name"];

            if (names.count && ![names containsObject:name]) {
                continue;
            }

            NSNumber *size = d[@"size"];

            if (name && size) {
                TmpDiskFile *disk = [[TmpDiskFile alloc] init];
                disk.name = name;
                disk.size = size.unsignedLongLongValue;
                disk.indexed = [d[@"indexed"] boolValue];
                disk.hidden = [d[@"hidden"] boolValue];
                disk.folders = [d objectForKey:@"folders"] ?: @[];
                [results addObject:disk];
            }
        }
    }

    return results;
}

+ (void)ejectVolumesWithNames:(NSSet<NSString *> *)names
                     recreate:(BOOL)recreate {
    dispatch_group_t group = dispatch_group_create();

    for (TmpDiskFile *disk in [self knownVolumesWithNames:names]) {
        dispatch_group_enter(group);
        NSString *volumePath = [self pathForName:disk.name];

        BOOL isRemovable, isWritable, isUnmountable;
        NSString *description, *type;

        NSWorkspace *ws = [[NSWorkspace alloc] init];

        // Make sure the Volume is unmountable first
        [ws getFileSystemInfoForPath:volumePath
                         isRemovable:&isRemovable
                          isWritable:&isWritable
                       isUnmountable:&isUnmountable
                         description:&description
                                type:&type];
        if (isUnmountable) {
            [ws unmountAndEjectDeviceAtPath:volumePath];

            if (recreate) {
                [self autoCreateVolumesWithNames:[NSSet setWithObject:disk.name]];
            }
        }
        dispatch_group_leave(group);
    }
}

+ (void)openVolumeWithName:(NSString *)name {

    NSString *volumePath = [self pathForName:name];

    NSWorkspace *ws = [[NSWorkspace alloc] init];

    [ws openFile:volumePath];
}

+ (bool)createTmpDiskWithName:(NSString*)name size:(u_int64_t)size autoCreate:(bool)autoCreate indexed:(bool)indexed hidden:(bool)hidden folders:(NSArray*)folders onSuccess:(void (^)())success {

    if (name.length == 0) {
        NSAlert *a = [NSAlert alertWithMessageText:@"Error Creating TmpDisk" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"You must provide a Disk Name"];
        [a runModal];

        return NO;
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:[self pathForName:name] isDirectory:nil]) {
        NSAlert *a = [NSAlert alertWithMessageText:@"Error Creating TmpDisk" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"A Volume named %@ already exists.", name];
        [a runModal];

        return NO;
    }

    // Check if the disk has been set to auto-create on startup
    if (autoCreate) {

        // Add the volume to autoCreate if it doesn't already exist in there

        NSMutableArray *autoCreateArray;

        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"]) {
            // Existing copy in user defaults

            autoCreateArray = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"]];

        } else {
            autoCreateArray = [NSMutableArray array];
        }

        // Holds the current disk values to replicate
        NSMutableDictionary *curDisk = [NSMutableDictionary dictionary];
        curDisk[@"name"] = name;
        curDisk[@"size"] = @(size);
        curDisk[@"indexed"] = @(indexed);
        curDisk[@"hidden"] = @(hidden);
        curDisk[@"folders"] = folders;

        // Check whether same name exists in autoCreate already
        bool exists = false;
        for (NSDictionary *d in autoCreateArray) {
            if ([d[@"name"] compare:name options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                exists = true;
                break;
            }
        }

        if (!exists) {
            // Doesn't exist so we're safe to add it to the list
            [autoCreateArray addObject:curDisk];

            [[NSUserDefaults standardUserDefaults] setObject:autoCreateArray forKey:@"autoCreate"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

    }

    // We need a task to run the sys call to create a new tmpdisk volume

    NSTask *task;
    task = [[NSTask alloc] init];
    task.launchPath = @"/bin/sh";

    NSString *command;
    if (hidden) {
        NSString *pattern = @"d=$(hdiutil attach -nomount ram://%llu) && diskutil eraseDisk HFS+ %%noformat%% $d && "
        @"newfs_hfs -v \"%@\" \"$(echo $d | tr -d ' ')s1\" && hdiutil attach -nomount $d && "
        @"hdiutil attach -nobrowse \"$(echo $d | tr -d ' ')s1\"";

        command = [NSString stringWithFormat:pattern, size, name];
    } else {
        command = [NSString stringWithFormat:@"diskutil erasevolume HFS+ \"%@\" `hdiutil attach -nomount ram://%llu`", name, size];
    }

    NSArray *arguments = @[@"-c", command];

    task.arguments = arguments;

    NSTask *indexTask = nil;
    if (indexed) {
        // If the indexed flag was set we need to run another task to index the drive
        indexTask = [[NSTask alloc] init];
        indexTask.launchPath = @"/bin/sh";

        NSArray *arguments;
        arguments = @[@"-c",
                      [NSString stringWithFormat:@"mdutil -i on %@", [self pathForName:name]]];

        indexTask.arguments = arguments;
    }

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_7
    // Check for termination handler existences

    [task setTerminationHandler:^(NSTask* task) {


        NSDictionary *tmpProps = [NSDictionary dictionaryWithObjects:
                                  [NSArray arrayWithObjects:[NSNumber numberWithBool:NO], nil] forKeys:
                                  [NSArray arrayWithObjects:@"backup", nil]];

        [tmpProps writeToFile:[NSString stringWithFormat:@"/Volumes/%@/.tmpdisk", name] atomically:YES];

        if (indexTask != nil) {
            [indexTask launch];
        }

        [self createFolders:name folders:folders];

        if (success != nil) {
            success();
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TmpDiskCreated" object:name];
        });

    }];

    [task launch];

#else

    [task launch];
    [task waitUntilExit];

    NSDictionary *tmpProps = @{@"backup": @NO};

    [tmpProps writeToFile:[NSString stringWithFormat:@"/Volumes/%@/.tmpdisk", name] atomically:YES];

    if (indexTask != nil) {
        [indexTask launch];
    }

    [self createFolders:name folders:folders];

    if (success != nil) {
        success();
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"TmpDiskCreated" object:name];

#endif

    return YES;
}

+ (void)createFolders:(NSString*)name folders:(NSArray*)folders {
    // Handle the folder creation

    for(id f in folders) {
        NSString *folder = (NSString*)f;
        NSString *dir = [NSString stringWithFormat:@"/Volumes/%@/%@", name, folder];

        NSError *error = nil;
        BOOL isDir = YES;
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error];
            if (error != nil) {
                NSLog(@"%@", error);
            }
        }
    }
}

@end
