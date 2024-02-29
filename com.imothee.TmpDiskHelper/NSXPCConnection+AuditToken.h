//
//  NSXPCConnection+AuditToken.h
//  TmpDisk
//
//  Created by Tim on 2/28/24.
//

@import Foundation;

@interface NSXPCConnection (AuditToken)

// Apple uses this property internally to verify XPC connections.
// There is no safe pulicly available alternative (check by client pid, for example, is racy)
@property (nonatomic, readonly) audit_token_t auditToken;

@end
