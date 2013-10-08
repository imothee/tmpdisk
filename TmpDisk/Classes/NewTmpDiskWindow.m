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

- (IBAction)toggleAdvancedMode:(id)sender {
    
    if ([sender state] == NSOnState) {
        // Advanced mode enabled so change the sizeLabel to a text input box
        [sizeLabel setBezeled:YES];
        [sizeLabel setBezelStyle:NSTextFieldSquareBezel];
        [sizeLabel setDrawsBackground:YES];
        [sizeLabel setEditable:YES];
    } else {
        // Advanced mode disabled so reset to a spinner + text combo
        [[sizeLabel window] makeFirstResponder:nil];
        [sizeLabel setBezeled:NO];
        [sizeLabel setDrawsBackground:NO];
        [sizeLabel setEditable:NO];
        [sizeLabel setStringValue:[NSString stringWithFormat:@"%dMB", [diskSize intValue]]];
    }
    
}

- (IBAction)createTmpDisk:(id)sender {
    
    // We have a window to setup the various requirements of a new TmpDisk
    
    NSString *name = [diskName stringValue];
    
    int dsizeval = 0;
    if ([advancedMode state] == NSOnState) {
        // Grab disksize from the textField instead
        dsizeval = [sizeLabel intValue];
    } else {
        dsizeval = [diskSize intValue];
    }
    
    // Change to long and unsigned int to handle larger disk values without silently failing
    // Credit to Russ Nelson
    u_int64_t dsize = (((u_int64_t) dsizeval) * 1024 * 1024 / 512);
    
    [diskNameLabel setHidden:YES];
    [diskSizeLabel setHidden:YES];
    [diskName setHidden:YES];
    [diskSize setHidden:YES];
    [sizeLabel setHidden:YES];
    [diskAutoCreate setHidden:YES];
    [createDisk setHidden:YES];
    [diskIndex setHidden:YES];
    [diskHide setHidden:YES];
    [advancedMode setHidden:YES];
    
    [spinner startAnimation:self];
    
    bool created = [TmpDiskManager createTmpDiskWithName:name
                                                    size:dsize
                                              autoCreate:([diskAutoCreate state] == NSOnState)
                                                 indexed:([diskIndex state] == NSOnState)
                                                  hidden:([diskHide state] == NSOnState)
                                               onSuccess:^(void) {
        
        [self.window close];
        
        [diskNameLabel setHidden:NO];
        [diskName setStringValue:@""];
        [diskSizeLabel setHidden:NO];
        [diskName setHidden:NO];
        [diskSize setHidden:NO];
        [sizeLabel setHidden:NO];
        [diskAutoCreate setHidden:NO];
        [createDisk setHidden:NO];
        [diskIndex setHidden:NO];
        [diskHide setHidden:NO];
        [advancedMode setHidden:NO];
        
        [spinner stopAnimation:self];
        
    }];
    
    // Failure so allow to re-renter information
    if (!created) {
        
        [diskNameLabel setHidden:NO];
        [diskSizeLabel setHidden:NO];
        [diskName setHidden:NO];
        [diskSize setHidden:NO];
        [sizeLabel setHidden:NO];
        [diskAutoCreate setHidden:NO];
        [createDisk setHidden:NO];
        [diskIndex setHidden:NO];
        [diskHide setHidden:NO];
        [advancedMode setHidden:NO];
        
        [spinner stopAnimation:self];
        
    }
    
}

@end
