//
//  SocksProxyServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SocksProxyServer.h"
#import "SharedHeader.h"
#include "srelay.h"

int proto_socks(SOCKS_STATE *state);
void relay(SOCKS_STATE *state);
extern u_long idle_timeout;

void socks_proxy_bandwidth_stat(u_long upload, u_long download)
{
//	[[SocksProxyServer sharedSocksProxyServer] _addBandwidthStatWithUpload:upload download:download];
}

@implementation SocksProxyServer

+ (NSString *)pacFilePath
{
    return @"/socks.pac";
}

- (id)init
{
	self = [super init];
    if (self) {
        _logInfoValues = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
	[_logInfoValues release];
	[super dealloc];
}

- (NSString *)serviceDomaine
{
	return SOCKS_PROXY_DOMAIN;
}

- (int)servicePort
{
	return SOCKS_PROXY_PORT;
}

- (void)processIncomingConnection:(NSFileHandle *)fileHandle
{
	NSAutoreleasePool *pool;
    SOCKS_STATE state;
    SOCK_INFO si;
    
    pool = [[NSAutoreleasePool alloc] init];
	memset(&state, 0, sizeof(state));
    memset(&si, 0, sizeof(si));
    state.si = &si;
    state.s = [fileHandle fileDescriptor];
    if (proto_socks(&state) == 0) {
		if (state.sr.req == S5REQ_UDPA) {
			relay_udp(&state);
		} else {
			relay(&state);
		}
	    close(state.r);
    }
    [fileHandle closeFile];
    [self performSelectorOnMainThread:@selector(_closeConnexion:) withObject:fileHandle waitUntilDone:NO];
    [pool drain];
}

- (void)_receiveIncomingConnection:(NSFileHandle *)handle
{
	[NSThread detachNewThreadSelector:@selector(processIncomingConnection:) toTarget:self withObject:handle];
}

- (void)getBandwidthStatWithUpload:(UInt64 *)upload download:(UInt64 *)download
{
	@synchronized (_logInfoValues) {
    	for (NSValue *value in _logInfoValues) {
        	LOGINFO *li = [value pointerValue];
            
            *upload += li->upl;
            *download += li->dnl;
        }
    }
}

- (void)_sendBandwidthStatNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:HTTPProxyServerNewBandwidthStatNotification object:nil];
}

@end
