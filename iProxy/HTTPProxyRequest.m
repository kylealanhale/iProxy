//
//  HTTPProxyRequest.m
//  iProxy
//
//  Created by Jérôme Lebel on 17/05/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "HTTPProxyRequest.h"
#import "HTTPProxyServer.h"


@implementation HTTPProxyRequest

- (id)initWithFileHandle:(NSFileHandle *)fileHandle httpProxyServer:(HTTPProxyServer *)server;
{
    self = [self init];
    if (self) {
        _httpProxyServer = server;
        _incomingFileHandle = [fileHandle retain];
        [_incomingFileHandle waitForDataInBackgroundAndNotify];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receiveIncomingHeaderNotification:) name:NSFileHandleDataAvailableNotification object:_incomingFileHandle];
    }
    
    return self;
}

- (void)dealloc
{
    [_incomingFileHandle release];
    CFRelease(_incomingMessage);
    [super dealloc];
}

- (void)_closing
{
    [_httpProxyServer closingRequest:self];
}

- (void)_createIncomingMessageWithData:(NSData *)data;
{
    _incomingMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
}

- (void)_processIncomingMessage
{
    CFDataRef data;
    CFStringRef stringContentLength;
    int length;
    
    stringContentLength = CFHTTPMessageCopyHeaderFieldValue(_incomingMessage, (CFStringRef)@"Content-Length");
    data = CFHTTPMessageCopyBody(_incomingMessage);
    length = [(NSString *)stringContentLength intValue];
    if (length <= [(NSData *)data length]) {
        CFHTTPMessageRef requestForServer;
        CFURLRef url;
        CFStringRef method;
        CFStringRef hostName;
        
        url = CFHTTPMessageCopyRequestURL(_incomingMessage);
        hostName = CFURLCopyHostName(url);
        method = CFHTTPMessageCopyRequestMethod(_incomingMessage);
        requestForServer = CFHTTPMessageCreateRequest(NULL, method, url, kCFHTTPVersion1_1);
        if (length < [(NSData *)data length]) {
            NSData *otherData;
            NSData *realData;
            
            realData = [[NSData alloc] initWithBytes:[(NSData *)data bytes] length:length];
            otherData = [[NSData alloc] initWithBytes:[(NSData *)data bytes] + length length:[(NSData *)data length] - length];
            [self _createIncomingMessageWithData:otherData];
            CFHTTPMessageSetBody(requestForServer, (CFDataRef)realData);
            [otherData release];
            [realData release];
        } else {
            [self _createIncomingMessageWithData:nil];
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
	NSData *data = [_incomingFileHandle availableData];
	
	if ([data length] == 0) {
        [self _closing];
		return;
	}
    
	if (!_incomingMessage) {
        [self _createIncomingMessageWithData:nil];
	}
	
	if (!CFHTTPMessageAppendBytes(_incomingMessage, [data bytes], [data length])) {
        [self _closing];
		return;
	}
    
	if(CFHTTPMessageIsHeaderComplete(_incomingMessage)) {
        [self _processIncomingMessage];
	}
    
	[_incomingFileHandle waitForDataInBackgroundAndNotify];
}

@end
