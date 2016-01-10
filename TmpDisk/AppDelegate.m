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


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Insert code here to initialize your application
  
  // Check if TmpDisk was launched with command line args
  NSArray *arguments = [NSProcessInfo processInfo].arguments;
  
  NSString *argName = nil;
  NSString *argSize = nil;
  // TODO: There's likely a better way to parse command line args
  for (NSUInteger i=0, n=arguments.count; i<n; i++) {
    NSString *s = arguments[i];
    
    // We expect args in the format -argname=argval
    
    NSArray *arg = [s componentsSeparatedByString:@"="];
    if (arg.count == 2) {
      if ([arg[0] isEqualToString:@"-name"]) {
        argName = [NSString stringWithString:arg[1]];
      } else if ([arg[0] isEqualToString:@"-size"]) {
        argSize = [NSString stringWithString:arg[1]];
      }
    }
  }
  
  if (argName != nil && argSize != nil) {
    
    int dsize = argSize.intValue;
    u_int64_t size = (((u_int64_t) dsize) * 1024 * 1024 / 512);
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/Volumes/%@", argName] isDirectory:nil]) {
      [TmpDiskManager createTmpDiskWithName:argName size:size autoCreate:NO indexed:NO hidden:NO folders:[[NSArray alloc] init] onSuccess:nil];
    }
    
  }
  
  
  if ([[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"]) {
    
    NSArray *autoCreateArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"];
    
    for (NSDictionary *d in autoCreateArray) {
      
      NSString *name = d[@"name"];
      NSNumber *size = d[@"size"];
      NSNumber *indexed = d[@"indexed"];
      NSNumber *hidden = d[@"hidden"];
      NSArray *folders = nil;
      
      if ([d objectForKey:@"folders"]) {
        folders = [d objectForKey:@"folders"];
      }else {
        folders = [[NSArray alloc] init];
      }
      
      if (name && size) {
        
        if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/Volumes/%@", name] isDirectory:nil]) {
          continue;
        }
        
        [TmpDiskManager createTmpDiskWithName:name size:size.unsignedLongLongValue autoCreate:NO indexed:indexed.boolValue hidden:hidden.boolValue folders:folders onSuccess:nil];
        
      }
      
    }
    
  }
}

- (void)awakeFromNib {
  
  statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
  statusItem.menu = statusMenu;
  statusItem.image = [NSImage imageNamed:@"status.png"];
  [statusItem setHighlightMode:YES];
  
  [self newTmpDiskCreated:nil];
  
  
  // Add a notification watcher to watch for disks added to refresh the menu
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newTmpDiskCreated:) name:@"TmpDiskCreated" object:nil];
  
  [[NSWorkspace sharedWorkspace].notificationCenter addObserver:self selector:@selector(diskUnmounted:) name:NSWorkspaceDidUnmountNotification object:nil];
  
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
  
}

@end
