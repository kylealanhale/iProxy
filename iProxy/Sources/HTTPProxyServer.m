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

+ (NSString *)pacFilePath
{
    return @"/http.pac";
}

- (NSString *)serviceDomain
{
	return HTTP_PROXY_DOMAIN;
}

- (int)servicePort
{
	return HTTP_PROXY_PORT;
}

- (NSString *)pacFileContentWithCurrentIP:(NSString *)ip
{
    return [NSString stringWithFormat:@"function FindProxyForURL(url, host) { return \"PROXY %@:%d\"; }", ip, self.servicePort];
}

- (BOOL)_starting
{
    [NSThread detachNewThreadSelector:@selector(proxyHttpRun) toTarget:self withObject:nil];
    return YES;
}

- (void)_stopping
{
    polipo_exit();
}

- (void) proxyHttpRun
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSString *configuration = [[NSBundle mainBundle] pathForResource:@"polipo" ofType:@"config"];
	[self performSelectorOnMainThread:@selector(_started) withObject:nil waitUntilDone:YES];
    char *args[5] = {
        "test",
        "-c",
        (char*)[configuration UTF8String],
        "proxyAddress=0.0.0.0",
        (char*)[[NSString stringWithFormat:@"proxyPort=%d", HTTP_PROXY_PORT] UTF8String],
    };

    polipo_main(5, args);
	
    [self performSelectorOnMainThread:@selector(_stopped) withObject:nil waitUntilDone:NO];
    [pool drain];
}

@end
