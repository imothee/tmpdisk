//
//  TmpDiskManager.h
//  TmpDisk
//
//  Created by Timothy Marks on 22/11/11.
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

@interface TmpDiskFile : NSObject

@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) uint64_t size;
@property(nonatomic, assign) BOOL hidden;
@property(nonatomic, assign) BOOL indexed;
@property(nonatomic, strong) id folders;

@property(readonly) BOOL exists;

@end

@interface TmpDiskManager : NSObject

+ (NSString *)pathForName:(NSString *)name;

+ (void)autoCreateVolumesWithNames:(NSSet<NSString *> *)names;
+ (NSArray<TmpDiskFile *> *)knownVolumesWithNames:(NSSet<NSString *> *)names;

+ (void)ejectVolumesWithNames:(NSSet<NSString *> *)names recreate:(BOOL)recreate;
+ (void)openVolumeWithName:(NSString *)name;

+ (bool)createTmpDiskWithName:(NSString*)name size:(u_int64_t)size autoCreate:(bool)autoCreate indexed:(bool)indexed hidden:(bool)hidden folders:(NSArray*)folders onSuccess:(void (^)())success;

@end
