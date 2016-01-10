//
//  TmpDiskMenuItem.h
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

#import <AppKit/AppKit.h>
#import "TmpDiskMenuItemView.h"

typedef void (^EjectBlock)(NSString*);

@interface TmpDiskMenuItem : NSMenuItem {
  
  EjectBlock ejectBlock;
  
}


- (instancetype)initWithTitle:(NSString *)aString action:(SEL)aSelector keyEquivalent:(NSString *)charCode eject:(SEL)ejSelector NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithTitle:(NSString *)aString action:(SEL)aSelector keyEquivalent:(NSString *)charCode ejectBlock:(void (^)(NSString*))block NS_DESIGNATED_INITIALIZER;

- (void)runSelectBlock:(id)sender;

@end
