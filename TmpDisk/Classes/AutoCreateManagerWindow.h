//
//  AutoCreateManagerWindow.h
//  TmpDisk
//
//  Created by Timothy Marks on 24/11/11.
//  Copyright (c) 2011 Ink Scribbles Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AutoCreateManagerWindow : NSObject <NSTableViewDataSource, NSTableViewDelegate> {
    
    IBOutlet NSTableView *autoCreateEntries;
    
    NSMutableArray *autoCreateDisks;
    
}

@property (nonatomic, retain) NSMutableArray *autoCreateDisks;

- (IBAction)removeEntry:(id)sender;

@end
