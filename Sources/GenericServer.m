//
//  GenericServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GenericServer.h"


@implementation GenericServer

@synthesize state = _state; 

- (void)dealloc
{
	[_netService release];
	[super dealloc];
}

- (NSString *)serviceDomaine
{
	return nil;
}

- (int)servicePort
{
	return 0;
}

- (void)start
{
    _netService = [[NSNetService alloc] initWithDomain:@"" type:self.serviceDomaine name:@"" port:self.servicePort];
    _netService.delegate = self;
    [_netService publish];
}

- (void)stop
{
    [_netService stop];
    [_netService release];
    _netService = nil;
}

@end
