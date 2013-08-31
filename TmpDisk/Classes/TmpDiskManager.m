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

@implementation TmpDiskManager

+ (bool)createTmpDiskWithName:(NSString*)name size:(int)size autoCreate:(bool)autoCreate indexed:(bool)indexed onSuccess:(void (^)())success {
    
    if ([name length] == 0) {
        NSAlert *a = [NSAlert alertWithMessageText:@"Error Creating TmpDisk" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"You must provide a Disk Name"];
        [a runModal];
        
        return NO;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/Volumes/%@", name] isDirectory:nil]) {
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
        [curDisk setObject:name forKey:@"name"];
        [curDisk setObject:[NSNumber numberWithInt:size] forKey:@"size"];
        [curDisk setObject:[NSNumber numberWithBool:indexed] forKey:@"indexed"];
        
        // Check whether same name exists in autoCreate already
        bool exists = false;
        for (NSDictionary *d in autoCreateArray) {
            if ([[d objectForKey:@"name"] compare:name options:NSCaseInsensitiveSearch] == NSOrderedSame) {
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
    task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath: @"/bin/sh"];
    
    NSArray *arguments;
    arguments = [NSArray arrayWithObjects: @"-c",
                 [NSString stringWithFormat:@"diskutil erasevolume HFS+ \"%@\" `hdiutil attach -nomount ram://%d`", name, size], nil];
    
    [task setArguments:arguments];
    
    NSTask *indexTask = nil;
    if (indexed) {
        // If the indexed flag was set we need to run another task to index the drive
        indexTask = [[[NSTask alloc] init] autorelease];
        [indexTask setLaunchPath: @"/bin/sh"];
        
        NSArray *arguments;
        arguments = [NSArray arrayWithObjects: @"-c",
                     [NSString stringWithFormat:@"mdutil -i on /Volumes/%@", name], nil];
        
        [indexTask setArguments:arguments];
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
        
        if (success != nil) {
            success();
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TmpDiskCreated" object:name];
        
        
    }];
    
    [task launch];
    
#else

    [task launch];
    [task waitUntilExit];
    
    NSDictionary *tmpProps = [NSDictionary dictionaryWithObjects:
                              [NSArray arrayWithObjects:[NSNumber numberWithBool:NO], nil] forKeys:
                              [NSArray arrayWithObjects:@"backup", nil]];
    
    [tmpProps writeToFile:[NSString stringWithFormat:@"/Volumes/%@/.tmpdisk", name] atomically:YES];
    
    if (indexTask != nil) {
        [indexTask launch];
    }
    
    if (success != nil) {
        success();
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TmpDiskCreated" object:name];
    
#endif
    
    return YES;
}

@end
