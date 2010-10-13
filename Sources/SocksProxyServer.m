//
//  SocksProxyServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SocksProxyServer.h"

int srelay_main(int ac, char **av);
void srelay_exit();

@implementation SocksProxyServer

+ (id)sharedSocksProxyServer
{
	static SocksProxyServer *shared = nil;
    
    if (!shared) {
    	shared = [[SocksProxyServer alloc] init];
    }
    return shared;
}

- (NSString *)serviceDomaine
{
	return @"_iproxysocksproxy._tcp.";
}

- (int)servicePort
{
	return SOCKS_PROXY_PORT;
}

- (void)start
{
	if (_state == SERVER_STATE_STOPPED) {
	    NSString *connect = [NSString stringWithFormat:@":%d", self.servicePort];
        
        char *args[4] = {
            "srelay",
            "-i",
            (char*)[connect UTF8String],
            "-f",
        };

        srelay_main(4, args);
        
        [self willChangeValueForKey:@"state"];
        _state = SERVER_STATE_RUNNING;
        [self didChangeValueForKey:@"state"];
        [super start];
    }
}

- (void)stop
{
	if (_state == SERVER_STATE_RUNNING) {
        srelay_exit();
        [self willChangeValueForKey:@"state"];
        _state = SERVER_STATE_STOPPED;
        [self didChangeValueForKey:@"state"];
        [super stop];
    }
}

@end
