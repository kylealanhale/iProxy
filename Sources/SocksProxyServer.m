//
//  SocksProxyServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SocksProxyServer.h"
#import "SharedHeader.h"
#include <unistd.h>

int proto_socks(int sock);
void relay(int cs, int ss);

@implementation SocksProxyServer

@synthesize connexionCount = _connexionCount;

+ (id)sharedSocksProxyServer
{
	static SocksProxyServer *shared = nil;
    
    if (!shared) {
    	shared = [[SocksProxyServer alloc] init];
    }
    return shared;
}

- (id)init
{
	self = [super init];
    if (self) {
    	connexions = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSString *)serviceDomaine
{
	return SOCKS_PROXY_DOMAIN;
}

- (int)servicePort
{
	return SOCKS_PROXY_PORT;
}

- (void)stop
{
    [super stop];
	for (NSFileHandle *handle in connexions) {
    	[handle closeFile];
    }
    [connexions removeAllObjects];
}

- (void)_didCloseConnexion:(NSFileHandle *)fileHandle
{
	[self willChangeValueForKey:@"connexionCount"];
    _connexionCount--;
    [self didChangeValueForKey:@"connexionCount"];
    [connexions removeObject:fileHandle];
}

- (void)processIncomingConnection:(NSFileHandle *)fileHandle
{
	NSAutoreleasePool *pool;
    int clientSocket, serverSocket;
    
    pool = [[NSAutoreleasePool alloc] init];
    clientSocket = [fileHandle fileDescriptor];
    serverSocket = proto_socks(clientSocket);
	NSLog(@"test %d %d", clientSocket, serverSocket);
    if (serverSocket != -1) {
	    relay(clientSocket, serverSocket);
	    close(serverSocket);
    }
    close(clientSocket);
    [fileHandle closeFile];
    [self performSelectorOnMainThread:@selector(_didCloseConnexion:) withObject:fileHandle waitUntilDone:NO];
    [pool drain];
}

- (void)receiveIncomingConnectionNotification:(NSNotification *)notification
{
	NSFileHandle *handle;
	[self willChangeValueForKey:@"connexionCount"];
    _connexionCount++;
    [self didChangeValueForKey:@"connexionCount"];
    handle = [[notification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];
    [connexions addObject:handle];
	[[notification object] acceptConnectionInBackgroundAndNotify];
	[NSThread detachNewThreadSelector:@selector(processIncomingConnection:) toTarget:self withObject:handle];
}

@end
