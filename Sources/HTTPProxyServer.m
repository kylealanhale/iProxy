//
//  HTTPProxyServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "HTTPProxyServer.h"

int polipo_main(int argc, char **argv);
void polipo_exit();

@implementation HTTPProxyServer

+ (HTTPProxyServer *)sharedHTTPProxyServer
{
	HTTPProxyServer *shared = nil;
    
    if (!shared) {
    	shared = [[HTTPProxyServer alloc] init];
    }
    return shared;
}

- (void)dealloc
{
	[httpProxyNetService release];
    [super dealloc];
}

- (void)start
{
	if (_state == SERVER_STATE_STOPPED) {
    	[self willChangeValueForKey:@"state"];
    	_state = SERVER_STATE_STARTING;
        httpProxyNetService = [[NSNetService alloc] initWithDomain:@"" type:@"_iproxyhttpproxy._tcp." name:@"" port:HTTP_PROXY_PORT];
        httpProxyNetService.delegate = self;
        [httpProxyNetService publish];
        [NSThread detachNewThreadSelector:@selector(running) toTarget:self withObject:nil];
        [self didChangeValueForKey:@"state"];
    }
}

- (void)stop
{
	if (_state == SERVER_STATE_RUNNING) {
    	[self willChangeValueForKey:@"state"];
    	_state = SERVER_STATE_STOPPING;
        [httpProxyNetService stop];
        [httpProxyNetService release];
        httpProxyNetService = nil;
        polipo_exit();
        [self didChangeValueForKey:@"state"];
    }
}

- (void)started
{
    [self willChangeValueForKey:@"state"];
    _state = SERVER_STATE_RUNNING;
    [self didChangeValueForKey:@"state"];
}

- (void)stopped
{
    [self willChangeValueForKey:@"state"];
    _state = SERVER_STATE_STOPPED;
    [self didChangeValueForKey:@"state"];
}

- (void)running
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
    [self performSelectorOnMainThread:@selector(started) withObject:nil waitUntilDone:YES];
    NSLog(@"http proxy start");

    NSString *configuration = [[NSBundle mainBundle] pathForResource:@"polipo" ofType:@"config"];

    char *args[5] = {
        "test",
        "-c",
        (char*)[configuration UTF8String],
        "proxyAddress=0.0.0.0",
        (char*)[[NSString stringWithFormat:@"proxyPort=%d", HTTP_PROXY_PORT] UTF8String],
    };

    polipo_main(5, args);

    NSLog(@"http proxy stop");

    [self performSelectorOnMainThread:@selector(stopped) withObject:nil waitUntilDone:YES];
    [pool drain];
}

@end
