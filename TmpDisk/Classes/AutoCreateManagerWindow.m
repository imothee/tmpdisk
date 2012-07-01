//
//  AutoCreateManagerWindow.m
//  TmpDisk
//
//  Created by Timothy Marks on 24/11/11.
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

#import "AutoCreateManagerWindow.h"

@implementation AutoCreateManagerWindow

@synthesize autoCreateDisks;

- (void)awakeFromNib {
    
    autoCreateDisks = [[NSMutableArray alloc] init];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"]) {
        
        NSArray *autoCreateArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"autoCreate"];
        
        for (NSDictionary *d in autoCreateArray) {
            
            NSString *name = [d objectForKey:@"name"];
            NSNumber *size = [d objectForKey:@"size"];
            
            if (name && size) {
                // Only add valid entries
                [autoCreateDisks addObject:d];
                
            }
            
        }
        
    }
    
}

- (void)dealloc {
    [super dealloc];
    [autoCreateDisks release], autoCreateDisks = nil;
}

#pragma mark -
#pragma mark NSTableViewDataSourceDelegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    
    return [autoCreateDisks count];    
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    
    if ([[aTableColumn identifier] isEqualToString:@"name"]) {
        return [[autoCreateDisks objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
    }else {
        int size = [[[autoCreateDisks objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]] intValue];        
        return [NSString stringWithFormat:@"%d MB", ((size * 512)/(1024*1000))];
    }
    
}

#pragma mark -
#pragma mark Remove

- (IBAction)removeEntry:(id)sender {
    
    NSInteger selected = [autoCreateEntries selectedRow];
    
    if (selected == -1) {
        return;
    }
    
    [autoCreateDisks removeObjectAtIndex:selected];
    
    [[NSUserDefaults standardUserDefaults] setObject:autoCreateDisks forKey:@"autoCreate"];
    
    [autoCreateEntries reloadData];
    
}

@end
