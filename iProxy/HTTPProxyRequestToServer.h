//
//  HTTPProxyRequestToServer.h
//  iProxy
//
//  Created by Jérôme Lebel on 20/05/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HTTPProxyRequest;

@interface HTTPProxyRequestToServer : NSObject<NSStreamDelegate>
{
    HTTPProxyRequest *_request;
    NSString *_command;
    NSURL *_requestURL;
    NSString *_httpVersion;
    NSMutableDictionary *_headers;
    NSUInteger _requestContentLength;
    NSUInteger _dataLeftToSend;
    NSUInteger _dataLeftToReceive;
    NSUInteger _port;
    BOOL _valid;
    BOOL _receiveData;
    BOOL _receivedComplete;
    
    CFReadStreamRef _readStream;
    CFWriteStreamRef _writeStream;
}

@property(nonatomic, readonly) NSUInteger requestContentLength;
@property(nonatomic, readonly) NSUInteger dataLeftToSend;
@property(nonatomic, readonly) NSString *command;
@property(nonatomic, readonly) NSUInteger port;
@property(nonatomic, readonly) NSURL *requestURL;
@property(nonatomic, readwrite, retain) NSMutableDictionary *headers;
@property(nonatomic, readonly) BOOL isValid;
@property(nonatomic, readonly) BOOL isHeaderComplete;
@property(nonatomic, readonly) NSUInteger dataLeftToReceive;
@property(nonatomic, readonly) BOOL receivedComplete;

- (id)initWithHTTProxyRequest:(HTTPProxyRequest *)request;
- (NSUInteger)dataReceivedByClient:(NSData *)data;
- (void)startReceivingData;
- (void)closeRequest;

@end
