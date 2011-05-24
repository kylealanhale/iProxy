//
//  HTTPProxyRequest.m
//  iProxy
//
//  Created by Jérôme Lebel on 17/05/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "HTTPProxyRequest.h"
#import "HTTPProxyServer.h"
#import "HTTPProxyRequestToServer.h"


@implementation HTTPProxyRequest

- (id)initWithFileHandle:(NSFileHandle *)fileHandle httpProxyServer:(HTTPProxyServer *)server;
{
    self = [self init];
    if (self) {
        _httpProxyServer = server;
        _incomingFileHandle = [fileHandle retain];
        _requests = [[NSMutableArray alloc] init];
        [_incomingFileHandle waitForDataInBackgroundAndNotify];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receiveIncomingHeaderNotification:) name:NSFileHandleDataAvailableNotification object:_incomingFileHandle];
    }
    
    return self;
}

- (void)dealloc
{
    [_incomingFileHandle release];
    [_incomingData release];
    [_incomingRequest release];
    [_requests release];
    [super dealloc];
}

- (void)_closing
{
    [_httpProxyServer closingRequest:self fileHandle:_incomingFileHandle];
}

- (void)_createIncomingRequestWithData:(NSData *)data;
{
    _incomingData = [[NSMutableData alloc] initWithData:data];
    _incomingRequest = [[HTTPProxyRequestToServer alloc] initWithHTTProxyRequest:self];
    [_requests addObject:_incomingRequest];
    if ([_requests count] > 0) {
        [[_requests objectAtIndex:0] startReceivingData];
    }
}

- (void)_receiveIncomingHeaderNotification:(NSNotification *)notification
{
	NSData *data = [_incomingFileHandle availableData];
    NSUInteger dataUsed;
	
	if ([data length] == 0) {
        [self _closing];
		return;
	}
    
	if (!_incomingRequest) {
        [self _createIncomingRequestWithData:nil];
	}
    [_incomingData appendData:data];
    dataUsed = [_incomingRequest dataReceivedByClient:_incomingData];
    [_incomingData replaceBytesInRange:NSMakeRange(0, dataUsed) withBytes:NULL length:0];
    if (_incomingRequest.dataLeftToSend == 0) {
        [_incomingRequest release];
        _incomingRequest = NULL;
    }
    
	[_incomingFileHandle waitForDataInBackgroundAndNotify];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    
}

- (void)sendDataToClient:(NSData *)data fromRequest:(HTTPProxyRequestToServer *)request
{
    NSAssert(request == [_requests objectAtIndex:0], @"wrong request");
    [_incomingFileHandle writeData:data];
    if (request.dataLeftToReceive == 0) {
        [_requests removeObjectAtIndex:0];
        if ([_requests count] > 0) {
            [[_requests objectAtIndex:0] startReceivingData];
        }
    }
}

- (void)serverRequestClosed:(HTTPProxyRequestToServer *)serverRequest
{
    NSUInteger index;
    
    index = [_requests indexOfObject:serverRequest];
    NSAssert(index != NSNotFound, @"unknown request");
    if (serverRequest.receivedComplete) {
        NSAssert(index == 0, @"should be the first request");
        [_requests removeObjectAtIndex:0];
    } else {
        for (; index < [_requests count];) {
            HTTPProxyRequestToServer *request;
            
            request = [_requests objectAtIndex:index];
            [request closeRequest];
            [_requests removeObjectAtIndex:index];
        }
    }
}

@end
