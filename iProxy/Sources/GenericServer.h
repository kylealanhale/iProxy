//
//  GenericServer.h
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#define CONNECTION_COUNT_MAX 50

typedef enum
{
	SERVER_STATE_STOPPED,
	SERVER_STATE_STARTING,
	SERVER_STATE_RUNNING,
	SERVER_STATE_STOPPING
} ServerState;


@interface GenericServer : NSObject <NSNetServiceDelegate>
{
	ServerState _state;
    NSNetService *_netService;
}

@property (readonly, assign) ServerState state;
@property (readonly, getter = serviceDomain) NSString *serviceDomain;
@property (readonly, getter = servicePort) int servicePort;

+ (id)sharedServer;
+ (NSString *)pacFilePath;

- (BOOL)start;
- (void)stop;
- (NSString *)pacFileContentWithCurrentIP:(NSString *)ip;

- (void)_started;
- (void)_failedStarting;
- (void)_stopping;
- (void)_stopped;

@end


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
- (void)closeConnection:(NSDictionary  *)handle;
- (void)newReceiveIncomingConnectionWithInfo:(NSDictionary *)info;
- (void)socketCallbackWithSocket:(CFSocketRef)sock type:(CFSocketCallBackType)type address:(CFDataRef)address data:(const void *)data;

@end