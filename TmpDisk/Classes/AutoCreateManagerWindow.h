//
//  AutoCreateManagerWindow.h
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

#import <Foundation/Foundation.h>

@interface AutoCreateManagerWindow : NSObject <NSTableViewDataSource, NSTableViewDelegate> {
  
  IBOutlet NSTableView *autoCreateEntries;
  
  NSMutableArray *autoCreateDisks;
  
}

@property (nonatomic, strong) NSMutableArray *autoCreateDisks;

- (IBAction)removeEntry:(id)sender;

@end
