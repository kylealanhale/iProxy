//
//  SocketServer.h
//  iProxy
//
//  Created by Jérôme Lebel on 03/06/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GenericServer.h"


@interface SocketServer : GenericServer
{
	NSError *_lastError;
	CFSocketRef _sockets[2];
    CFRunLoopSourceRef _runLoopSource[2];
    NSMutableDictionary *_connectionPerIP;
    NSUInteger _connectionCount;
}

@property(readonly) NSUInteger connectionCount;
@property(readonly) NSUInteger ipCount;

- (NSError *)lastError;
- (void)_setLastErrorWithMessage:(NSString *)message;
- (void)_closeSocket;
- (void)didOpenConnection:(NSDictionary *)info;
- (void)didCloseConnection:(NSDictionary *)info;
- (void)closeConnection:(NSDictionary *)handle;
- (void)newReceiveIncomingConnectionWithInfo:(NSDictionary *)info;
- (void)socketCallbackWithSocket:(CFSocketRef)sock type:(CFSocketCallBackType)type address:(CFDataRef)address data:(const void *)data;

@end
