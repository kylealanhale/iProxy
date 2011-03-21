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

- (void)processIncomingConnection:(NSDictionary *)info
{
	NSAutoreleasePool *pool;
    SOCKS_STATE state;
    loginfo li;
    NSValue *loginfoValue;
    NSFileHandle *fileHandle = [info objectForKey:@"handle"];
    
    pool = [[NSAutoreleasePool alloc] init];
	memset(&state, 0, sizeof(state));
	memset(&li, 0, sizeof(li));
    loginfoValue = [NSValue valueWithPointer:&li];
    @synchronized (_logInfoValues) {
    	[_logInfoValues addObject:loginfoValue];
    }
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
    @synchronized (_logInfoValues) {
    	[_logInfoValues removeObject:loginfoValue];
    }
    [fileHandle closeFile];
    [self performSelectorOnMainThread:@selector(_closeConnexion:) withObject:info waitUntilDone:NO];
    [pool drain];
}

- (void)_receiveIncomingConnectionWithInfo:(NSDictionary *)info
{
	[NSThread detachNewThreadSelector:@selector(processIncomingConnection:) toTarget:self withObject:info];
}

- (void)getBandwidthStatWithUpload:(UInt64 *)upload download:(UInt64 *)download
{
	@synchronized (_logInfoValues) {
    	for (NSValue *value in _logInfoValues) {
        	loginfo *li = [value pointerValue];
            
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
