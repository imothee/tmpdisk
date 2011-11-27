//
//  TmpDiskManager.h
//  TmpDisk
//
//  Created by Timothy Marks on 22/11/11.
//  Copyright (c) 2011 Ink Scribbles Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TmpDiskManager : NSObject

+ (bool)createTmpDiskWithName:(NSString*)name size:(int)size autoCreate:(bool)autoCreate onSuccess:(void (^)())success;

@end
