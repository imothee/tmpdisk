//
//  TmpDiskMenuItem.m
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

#import "TmpDiskMenuItem.h"

@implementation TmpDiskMenuItem

- (instancetype)initWithTitle:(NSString *)aString action:(SEL)aSelector keyEquivalent:(NSString *)charCode eject:(SEL)ejSelector {
  
  
  self = [super initWithTitle:aString action:aSelector keyEquivalent:charCode];
  
  if (self) {
    
    NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 150.0, 25.0)];
    v.autoresizingMask = NSViewWidthSizable;
    
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20.0, 2.5, 100.0, 20.0)];
    titleLabel.stringValue = aString;
    [titleLabel setBezeled:NO];
    [titleLabel setDrawsBackground:NO];
    [titleLabel setEditable:NO];
    [titleLabel setSelectable:NO];
    [v addSubview:titleLabel];
    
    NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect(120.0, 0.0, 25.0, 25.0)];
    b.image = [NSImage imageNamed:@"eject.png"];
    b.imagePosition = NSImageOnly;
    [b setBordered:NO];
    b.action = ejSelector;
    
    [v addSubview:b];
    
    self.view = v;
    
  }
  return self;
  
}

- (instancetype)initWithTitle:(NSString *)aString action:(SEL)aSelector keyEquivalent:(NSString *)charCode ejectBlock:(void (^)(NSString*))block {
  
  
  self = [super initWithTitle:aString action:aSelector keyEquivalent:charCode];
  
  if (self) {
    
    ejectBlock = [block copy];
    
    NSView *v = [[TmpDiskMenuItemView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 150.0, 25.0)];
    v.autoresizingMask = NSViewWidthSizable;
    
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20.0, 2.5, 90.0, 20.0)];
    titleLabel.stringValue = aString;
    [titleLabel setBezeled:NO];
    [titleLabel setDrawsBackground:NO];
    [titleLabel setEditable:NO];
    [titleLabel setSelectable:NO];
    [v addSubview:titleLabel];
    
    /*
     Todo Planned for future release.
     
     NSButton *settings = [[NSButton alloc] initWithFrame:NSMakeRect(115.0, 5.0, 15.0, 15.0)];
     [settings setImage:[NSImage imageNamed:@"settings.png"]];
     [settings setImagePosition:NSImageOnly];
     [settings setBordered:NO];
     [[settings cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
     [v addSubview:settings];
     */
    
    NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect(130.0, 5.0, 15.0, 15.0)];
    b.image = [NSImage imageNamed:@"eject.png"];
    b.alternateImage = [NSImage imageNamed:@"eject_a.png"];
    [b setButtonType:NSMomentaryChangeButton];
    b.imagePosition = NSImageOnly;
    [b setBordered:NO];
    b.target = self;
    b.action = @selector(runSelectBlock:);
    
    [v addSubview:b];
    
    self.view = v;
    
  }
  return self;
  
}

- (void)runSelectBlock:(id)sender {
  
  NSLog(@"Clicked eject");
  
  // Run the block passed in from AppDelegate to eject the Volume
  ejectBlock(self.title);
  
}

@end
