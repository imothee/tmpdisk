//
//  NewTmpDiskWindow.m
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

#import "NewTmpDiskWindow.h"

@implementation NewTmpDiskWindow

@synthesize window = _window;

- (void)awakeFromNib {
    
    [sizeLabel setStringValue:@"16MB"];
    
}

- (IBAction)sizeDidChange:(id)sender {
    
    // Have a +/- size set
    [sizeLabel setStringValue:[NSString stringWithFormat:@"%dMB", [diskSize intValue]]];
    
}

- (IBAction)createTmpDisk:(id)sender {
    
    // We have a window to setup the various requirements of a new TmpDisk
    
    NSString *name = [diskName stringValue];
    
    int dsizeval = [diskSize intValue];
    int dsize = (dsizeval * 1024 * 1000) / 512;
    
    if ([name length] == 0) {
        NSAlert *a = [NSAlert alertWithMessageText:@"Error Creating TmpDisk" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"You must provide a Disk Name"];
        [a runModal];
        return;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/Volumes/%@", name] isDirectory:nil]) {
        NSAlert *a = [NSAlert alertWithMessageText:@"Error Creating TmpDisk" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"A Volume named %@ already exists.", name];
        [a runModal];
        return;
    }
    
    
    // We need a task to run the sys call to create a new tmpdisk volume
    
    NSTask *task;
    task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath: @"/bin/sh"];
    
    NSArray *arguments;
    arguments = [NSArray arrayWithObjects: @"-c",
                 [NSString stringWithFormat:@"diskutil erasevolume HFS+ \"%@\" `hdiutil attach -nomount ram://%d`", name, dsize], nil];
    
    [task setArguments:arguments];
    
    [task setTerminationHandler:^(NSTask* task) {
        
        
        NSDictionary *tmpProps = [NSDictionary dictionaryWithObjects:
                                  [NSArray arrayWithObjects:[NSNumber numberWithBool:NO], nil] forKeys:
                                  [NSArray arrayWithObjects:@"backup", nil]];
        
        [tmpProps writeToFile:[NSString stringWithFormat:@"/Volumes/%@/.tmpdisk", name] atomically:YES];
        
        [self.window close];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TmpDiskCreated" object:name];
        
        
        
    }];
    
    [diskNameLabel setHidden:YES];
    [diskSizeLabel setHidden:YES];
    [diskName setHidden:YES];
    [diskSize setHidden:YES];
    [sizeLabel setHidden:YES];
    
    [spinner startAnimation:self];
    
    [task launch];
    
}

@end
