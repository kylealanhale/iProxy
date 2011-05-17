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

- (id)init
{
    self = [super init];
    if (self) {
        _waitingForCommand = [[NSMutableArray alloc] init];
        _pendingData = [[NSMutableDictionary alloc] init];
        _incomingHeaderRequest = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_waitingForCommand release];
    [_pendingData release];
    [_incomingHeaderRequest release];
    [super dealloc];
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

- (void)_monitorFileHandle:(NSFileHandle *)fileHandle withData:(NSData *)data
{
    CFHTTPMessageRef message;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receiveIncomingHeaderNotification:) name:NSFileHandleDataAvailableNotification object:fileHandle];
    message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
    if (data) {
        CFHTTPMessageAppendBytes(message, [data bytes], [data length]);
    }
    [_incomingHeaderRequest setObject:(id)message forKey:fileHandle];
    CFRelease(message);
}

- (void)didOpenConnection:(NSDictionary *)info
{
    if(info) {
        [self _monitorFileHandle:[info objectForKey:@"handle"] withData:nil];
        [[info objectForKey:@"handle"] waitForDataInBackgroundAndNotify];
    }
}

- (void)didCloseConnection:(NSDictionary *)info
{
}

- (void)_stopReceivingForFileHandle:(NSFileHandle *)incomingFileHandle close:(BOOL)closeFileHandle
{
	if (closeFileHandle) {
		[incomingFileHandle closeFile];
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:incomingFileHandle];
	[_incomingHeaderRequest removeObjectForKey:incomingFileHandle];
}

- (void)_processProxyRequest:(CFHTTPMessageRef)request fileHandle:(NSFileHandle *)fileHandle
{
    CFDataRef data;
    CFStringRef stringContentLength;
    int length;
    
    stringContentLength = CFHTTPMessageCopyHeaderFieldValue(request, (CFStringRef)@"Content-Length");
    data = CFHTTPMessageCopyBody(request);
    length = [(NSString *)stringContentLength intValue];
    if (length <= [(NSData *)data length]) {
        CFHTTPMessageRef requestForServer;
        CFURLRef url;
        CFStringRef method;
        CFStringRef hostName;
        
        url = CFHTTPMessageCopyRequestURL(request);
        hostName = CFURLCopyHostName(url);
        method = CFHTTPMessageCopyRequestMethod(request);
        requestForServer = CFHTTPMessageCreateRequest(NULL, method, url, kCFHTTPVersion1_1);
        if (length < [(NSData *)data length]) {
            NSData *otherData;
            NSData *realData;
            
            realData = [[NSData alloc] initWithBytes:[(NSData *)data bytes] length:length];
            otherData = [[NSData alloc] initWithBytes:[(NSData *)data bytes] + length length:[(NSData *)data length] - length];
            [self _monitorFileHandle:fileHandle withData:otherData];
            [otherData release];
            CFHTTPMessageSetBody(requestForServer, (CFDataRef)realData);
            [realData release];
        } else {
            [self _monitorFileHandle:fileHandle withData:nil];
            if (data) {
                CFHTTPMessageSetBody(requestForServer, data);
            }
        }
        CFRelease(url);
        CFRelease(method);
        CFRelease(hostName);
    }
    CFRelease(data);
    CFRelease(stringContentLength);
}

- (void)_receiveIncomingHeaderNotification:(NSNotification *)notification
{
	NSFileHandle *incomingFileHandle = [notification object];
	NSData *data = [incomingFileHandle availableData];
	
	if ([data length] == 0) {
		[self _stopReceivingForFileHandle:incomingFileHandle close:YES];
		return;
	}
    
    NSLog(@"%@", [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding]);
	CFHTTPMessageRef incomingRequest = (CFHTTPMessageRef)[_incomingHeaderRequest objectForKey:incomingFileHandle];
	if (!incomingRequest) {
		[self _stopReceivingForFileHandle:incomingFileHandle close:YES];
        return;
	}
	
	if (!CFHTTPMessageAppendBytes(incomingRequest, [data bytes], [data length])) {
		[self _stopReceivingForFileHandle:incomingFileHandle close:YES];
		return;
	}
    
    NSLog(@"read %d", [data length]);
	if(CFHTTPMessageIsHeaderComplete(incomingRequest)) {
        [self _processProxyRequest:incomingRequest fileHandle:incomingFileHandle];
	}
    
	[incomingFileHandle waitForDataInBackgroundAndNotify];
}

@end
