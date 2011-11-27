//
//  AppDelegate.m
//  TmpDisk
//
//  Created by Timothy Marks on 10/10/11.
//  Copyright (c) 2011 Ink Scribbles Pty Ltd.
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

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"]) {
    
        NSArray *autoCreateArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"];
        
        for (NSDictionary *d in autoCreateArray) {
            
            NSString *name = [d objectForKey:@"name"];
            NSNumber *size = [d objectForKey:@"size"];
            
            if (name && size) {
                
                if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/Volumes/%@", name] isDirectory:nil]) {
                    continue;
                }
                
                [TmpDiskManager createTmpDiskWithName:name size:[size intValue] autoCreate:NO onSuccess:nil];
                
            }
            
        }
        
    }
}

- (void)awakeFromNib {
    
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:[NSImage imageNamed:@"status.png"]];
    [statusItem setHighlightMode:YES];
    
    [self newTmpDiskCreated:nil];
    
    
    // Add a notification watcher to watch for disks added to refresh the menu
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newTmpDiskCreated:) name:@"TmpDiskCreated" object:nil];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(diskUnmounted:) name:NSWorkspaceDidUnmountNotification object:nil];
    
}

- (void)diskUnmounted:(NSNotification *)notification {
    
    // Piggyback off a new disk created call when we hear the system unmounted a disk
    // Clear the menu and redraw with al the valid volumes, sans any that were removed in finder or another app
    [self newTmpDiskCreated:notification];
    
}

- (void)newTmpDiskCreated:(NSNotification *)notification {
    
    NSError *e = nil;
    NSArray *volumes = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Volumes" error:&e];
    
    if (e != nil) {
        NSAlert *a = [NSAlert alertWithError:e];
        [a runModal];
        return;
    }
    
    // We have a new disk so remove all the old ones and rebuild the menu
    [diskMenu removeAllItems];
    
    for (NSString *s in volumes) {
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/Volumes/%@/.tmpdisk", s]]) {
            continue;
        }
        
        NSMenuItem *mi = [[TmpDiskMenuItem alloc] initWithTitle:s action:@selector(tmpDiskSelected:) keyEquivalent:@"" ejectBlock:^(NSString* s){
            
            // Eject Block passed to menu to run when the eject button is clicked for a TmpDisk
            
            [statusMenu cancelTrackingWithoutAnimation];
            
            
            NSString *volumePath = [NSString stringWithFormat:@"/Volumes/%@", s];
            
            BOOL isRemovable, isWritable, isUnmountable;
            NSString *description, *type;
            
            NSWorkspace *ws = [[NSWorkspace alloc] init];

            // Make sure the Volume is inmountable first
            [ws getFileSystemInfoForPath:volumePath
                                         isRemovable:&isRemovable
                                          isWritable:&isWritable
                                       isUnmountable:&isUnmountable
                                         description:&description
                                                type:&type];
            if (isUnmountable) {
                [ws unmountAndEjectDeviceAtPath:volumePath];
            }
            
            [ws release];
            
            return;
            
        }];
        
        [diskMenu addItem:mi];
        
    }
    
}

- (void)tmpDiskSelected:(id)sender {
    
    // When a tmpDisk menu option is selected, we open the volume in Finder
    
    NSString *s = [sender title];
    
    NSString *volumePath = [NSString stringWithFormat:@"/Volumes/%@", s];
    
    NSWorkspace *ws = [[NSWorkspace alloc] init];
    
    [ws openFile:volumePath];
    
    [ws release];
    
}

@end
