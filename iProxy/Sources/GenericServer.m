//
//  GenericServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GenericServer.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <CFNetwork/CFNetwork.h>
#include <arpa/inet.h>
#import "NSStringAdditions.h"

@implementation GenericServer

@synthesize state = _state; 
@synthesize serviceDomain;

+ (id)sharedServer
{
	static NSMutableDictionary *servers = nil;
    id server;
    
    if (!servers) {
    	servers = [[NSMutableDictionary alloc] init];
    }
    server = [servers objectForKey:[self class]];
    if (!server) {
        server = [[[self class] alloc] init];
        [servers setObject:server forKey:[self class]];
        [server autorelease];
    }
    return server;
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		_state = SERVER_STATE_STOPPED;
	}
	return self;
}

- (void)dealloc
{
	[_netService release];
	[super dealloc];
}

- (NSString *)serviceDomain
{
	return nil;
}

- (int)servicePort
{
	return 0;
}

- (BOOL)_starting
{
	return YES;
}

- (void)_started
{
    _netService = [[NSNetService alloc] initWithDomain:@"" type:self.serviceDomain name:@"" port:self.servicePort];
    _netService.delegate = self;
    [_netService publish];
    [self willChangeValueForKey:@"state"];
    _state = SERVER_STATE_RUNNING;
    [self didChangeValueForKey:@"state"];
}

- (void)_failedStarting
{
    [self willChangeValueForKey:@"state"];
    _state = SERVER_STATE_STOPPED;
    [self didChangeValueForKey:@"state"];
}

- (BOOL)start
{
    BOOL starting = NO;
	if (_state == SERVER_STATE_STOPPED) {
        [self willChangeValueForKey:@"state"];
        _state = SERVER_STATE_STARTING;
        [self didChangeValueForKey:@"state"];
        starting = [self _starting];
        if (!starting) {
        	[self _failedStarting];
        }
    }
    return starting;
}

- (void)_stopping
{
}

- (void)_stopped
{
    [_netService stop];
    [_netService release];
    _netService = nil;
    [self willChangeValueForKey:@"state"];
    _state = SERVER_STATE_STOPPED;
    [self didChangeValueForKey:@"state"];
}

- (void)stop
{
	if (_state == SERVER_STATE_RUNNING) {
        [self willChangeValueForKey:@"state"];
        _state = SERVER_STATE_STOPPING;
        [self didChangeValueForKey:@"state"];
        [self _stopping];
    }
}

@end
