//
//  HTTPProxyServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "HTTPProxyServer.h"
#import "SharedHeader.h"

int polipo_main(int argc, char **argv);
void polipo_exit();

@implementation HTTPProxyServer

+ (HTTPProxyServer *)sharedHTTPProxyServer
{
	static HTTPProxyServer *shared = nil;
    
    if (!shared) {
    	shared = [[HTTPProxyServer alloc] init];
    }
    return shared;
}

- (NSString	*)serviceDomain
{
	return HTTP_PROXY_DOMAIN;
}

- (int)servicePort
{
	return HTTP_PROXY_PORT;
}

- (void)receiveIncomingConnectionNotification:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSFileHandle *incomingFileHandle = [userInfo objectForKey:NSFileHandleNotificationFileHandleItem];
    
    [incomingFileHandle fileDescriptor];
	[[notification object] acceptConnectionInBackgroundAndNotify];
}

@end
