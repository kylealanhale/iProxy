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
	[[SocksProxyServer sharedSocksProxyServer] _addBandwidthStatWithUpload:upload download:download];
}

@implementation SocksProxyServer

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
//        idle_timeout = 0; // set a socket timeout of 1 minutes
        _upload = 0;
        _download = 0;
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

- (void)processIncomingConnection:(NSFileHandle *)fileHandle
{
	NSAutoreleasePool *pool;
    SOCKS_STATE state;
    loginfo li;
    
    pool = [[NSAutoreleasePool alloc] init];
	memset(&state, 0, sizeof(state));
	memset(&li, 0, sizeof(li));
	state.li = &li;
    state.s = [fileHandle fileDescriptor];
    if (proto_socks(&state) == 0) {
		if (state.req == S5REQ_UDPA) {
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

- (void)getBandwidthStatWithUpload:(float *)upload download:(float *)download
{
	return;
	@synchronized (self) {
		*upload = _upload;
    	*download = _download;
        _upload = 0;
        _download = 0;
    }
}

- (void)_sendBandwidthStatNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:HTTPProxyServerNewBandwidthStatNotification object:nil];
}

- (void)_addBandwidthStatWithUpload:(UInt64)upload download:(UInt64)download
{
	return;
	@synchronized (self) {
        _upload += upload;
        _download += download;
    }
//    [self performSelectorOnMainThread:@selector(_sendBandwidthStatNotification) withObject:nil waitUntilDone:NO];
}

@end
