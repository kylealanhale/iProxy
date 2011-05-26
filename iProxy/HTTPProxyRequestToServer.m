//
//  HTTPProxyRequestToServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 20/05/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "HTTPProxyRequestToServer.h"
#import "HTTPProxyRequest.h"

@interface HTTPProxyRequestToServer()
@end

@implementation HTTPProxyRequestToServer

@synthesize requestContentLength = _requestContentLength;
@synthesize port = _port;
@synthesize requestURL = _requestURL;
@synthesize isValid = _isValid;
@synthesize headersFromClient = _headersFromClient;
@synthesize command = _command;
@synthesize dataLeftToSend = _dataLeftToSend;
@synthesize isHeaderComplete = _isHeaderComplete;
@synthesize receivedComplete = _receivedComplete;

+ (NSUInteger)_processDataForHeader:(NSData *)data headers:(NSMutableDictionary *)headers headerComplete:(BOOL *)headerComplete command:(NSString **)command url:(NSURL **)url httpVersion:(NSString **)httpVersion
{
    const char *bytes;
    NSUInteger length;
    NSUInteger cursor;
    NSUInteger column = 0;
    NSUInteger begin = 0;
    
    bytes = [data bytes];
    length = [data length];
    cursor = 0;
    if (command) {
        *command = nil;
        *url = nil;
        *httpVersion = nil;
    }
    while (cursor < length - 1 && !*headerComplete) {
        if (bytes[cursor] == ':' && column == begin) {
            column = cursor;
        }
        if (bytes[cursor] == '\r' && bytes[cursor + 1] == '\n') {
            if (command && !*command) {
                NSUInteger commandCursor = 0;
                NSUInteger wordBeginning = 0;
                
                NSAssert(begin == 0, @"Should be at the beginning");
                NSAssert(cursor > 0, @"Should not be empty");
                while (YES) {
                    if (bytes[commandCursor] == ' ' || bytes[commandCursor] == '\r') {
                        NSString *string;
                        
                        string = [[NSString alloc] initWithBytes:bytes + wordBeginning length:commandCursor - wordBeginning encoding:NSUTF8StringEncoding];
                        if (!*command) {
                            *command = [[string retain] autorelease];
                        } else if (!*url) {
                            *url = [NSURL URLWithString:string];
                        } else if (!*httpVersion) {
                            *httpVersion = [[string retain] autorelease];
                        }
                        [string release];
                        while (bytes[commandCursor] == ' ') {
                            commandCursor++;
                        }
                        wordBeginning = commandCursor;
                        if (bytes[commandCursor] == '\r') {
                            break;
                        }
                    } else {
                        commandCursor++;
                    }
                }
            } else if (cursor == begin) {
                *headerComplete = YES;
            } else {
                NSString *key;
                NSString *value;
                
                key = [[NSString alloc] initWithBytes:bytes + begin length:column - begin encoding:NSUTF8StringEncoding];
                if (bytes[column + 1] == ' ') {
                    column++;
                }
                value = [[NSString alloc] initWithBytes:bytes + column + 1 length:cursor - column - 1 encoding:NSUTF8StringEncoding];
                [headers setValue:value forKey:key];
                [key release];
                [value release];
            }
            begin = cursor + 2;
            cursor++;
            column = begin;
        }
        cursor++;
    }
    return begin;
}

- (id)initWithHTTProxyRequest:(HTTPProxyRequest *)request;
{
    self = [self init];
    if (self) {
        _headersFromClient = [[NSMutableDictionary alloc] init];
        _headersFromServer = [[NSMutableDictionary alloc] init];
        _isValid = YES;
        _isHeaderComplete = NO;
        _request = request;
        _dataFromServer = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_dataFromServer release];
    [_command release];
    [_headersFromClient release];
    [_headersFromServer release];
    [super dealloc];
}

- (void)_sendHeadersToServer
{
    const char *cString;
    
    if (![_command isEqualToString:@"CONNECT"]) {
        NSMutableData *request;
        
        request = [[NSMutableData alloc] init];
        cString = [_command UTF8String];
        [request appendBytes:cString length:strlen(cString)];
        [request appendBytes:" " length:1];
        cString = [[_requestURL relativePath] UTF8String];
        if (cString[0] == 0) {
            cString = "/";
        }
        [request appendBytes:cString length:strlen(cString)];
        [request appendBytes:" " length:1];
        cString = [_httpVersion UTF8String];
        [request appendBytes:cString length:strlen(cString)];
        [request appendBytes:"\r\n" length:2];
        for (NSString *key in _headersFromClient) {
            cString = [key UTF8String];
            [request appendBytes:cString length:strlen(cString)];
            [request appendBytes:": " length:2];
            cString = [[_headersFromClient objectForKey:key] UTF8String];
            [request appendBytes:cString length:strlen(cString)];
            [request appendBytes:"\r\n" length:2];
        }
        [request appendBytes:"\r\n" length:2];
        CFWriteStreamWrite(_writeStream, [request bytes], [request length]);
    }
}

- (void)_processRequest
{
    NSLog(@"url %@:%d", [_requestURL host], _port);
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)[_requestURL host], _port, &_readStream, &_writeStream);
    
    NSInputStream *inputStream = (NSInputStream *)_readStream;
    NSOutputStream *outputStream = (NSOutputStream *)_writeStream;
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [inputStream open];
    [outputStream open];
    [self _sendHeadersToServer];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    if (1) {
        NSLog(@"%@ streamStatus %d", ((NSStream *)_readStream == stream)?@"read":@"write", [stream streamStatus]);
        switch (eventCode) {
            case NSStreamEventNone:
                NSLog(@"NSStreamEventNone");
                break;
            case NSStreamEventOpenCompleted:
                NSLog(@"NSStreamEventOpenCompleted");
                break;
            case NSStreamEventHasBytesAvailable:
                NSLog(@"NSStreamEventHasBytesAvailable");
                break;
            case NSStreamEventHasSpaceAvailable:
                NSLog(@"NSStreamEventHasSpaceAvailable");
                break;
            case NSStreamEventErrorOccurred:
                NSLog(@"NSStreamEventErrorOccurred");
                NSLog(@"%@", [stream streamError]);
                break;
            case NSStreamEventEndEncountered:
                NSLog(@"NSStreamEventEndEncountered");
                break;
                
            default:
                break;
        }
    }
    if ((NSStream *)_readStream == stream) {
        uint8_t buffer[1024];
        NSUInteger available = 0;
        
        switch (eventCode) {
            case NSStreamEventOpenCompleted:
                break;
            case NSStreamEventHasBytesAvailable:
                available = [(NSInputStream *)stream read:buffer maxLength:sizeof(buffer)];
                NSLog(@"available %d", available);
                if (available) {
                    NSData * data;
                    
                    if (![_command isEqualToString:@"CONNECT"] && !_serverHeadersReceived) {
                        NSUInteger dataParsed;
                        
                        [_dataFromServer appendBytes:buffer length:available];
                        dataParsed = [[self class] _processDataForHeader:_dataFromServer headers:_headersFromServer headerComplete:&_serverHeadersReceived command:NULL url:NULL httpVersion:NULL];
                        [_dataFromServer replaceBytesInRange:NSMakeRange(0, dataParsed) withBytes:NULL length:0];
                        if (_serverHeadersReceived) {
                            NSString *contentLengthString;
                            
                            contentLengthString = [_headersFromServer objectForKey:@"Content-Length"];
                            _chunkEncoding = [[_headersFromServer objectForKey:@"Transfer-Encoding"] isEqualToString:@"chunked"];
                            if (contentLengthString) {
                                _dataLeftToReceive = [contentLengthString integerValue] - [_dataFromServer length];
                            } else {
                                _dataLeftToReceive = -1;
                            }
                        }
                    } else if (_serverHeadersReceived && _dataLeftToReceive > 0) {
                        _dataLeftToReceive -= available;
                    }
                    data = [[NSData alloc] initWithBytesNoCopy:buffer length:available freeWhenDone:NO];
                    [_request sendDataToClient:data fromRequest:self];
                    [data release];
                }
                break;
            case NSStreamEventErrorOccurred:
            case NSStreamEventEndEncountered:
                if ([stream streamStatus] == NSStreamStatusClosed || [stream streamStatus] == NSStreamStatusAtEnd) {
                    [_request serverRequestClosed:self];
                }
                break;
            default:
                break;
        }
    } else if ((NSStream *)_writeStream == stream) {
    }
}

- (NSUInteger)_sendDataToServer:(NSData *)data
{
    NSUInteger dataToSend;
    
    if ([data length] > _dataLeftToSend && _dataLeftToSend != -1) {
        dataToSend = _dataLeftToSend;
    } else {
        dataToSend = [data length];
    }
    CFWriteStreamWrite((CFWriteStreamRef)_writeStream, [data bytes], [data length]);
    if (_dataLeftToSend > 0) {
        _dataLeftToSend -= dataToSend;
    }
    return dataToSend;
}

- (NSUInteger)dataReceivedByClient:(NSData *)data
{
    NSUInteger result;
    
    if (!_isHeaderComplete) {
        result = [[self class] _processDataForHeader:data headers:_headersFromClient headerComplete:&_isHeaderComplete command:&_command url:&_requestURL httpVersion:&_httpVersion];
        [_command retain];
        [_requestURL retain];
        [_httpVersion retain];
        if (_isHeaderComplete) {
            NSString *contentLengthString;
            
            contentLengthString = [_headersFromClient objectForKey:@"Content-Length"];
            _dataLeftToSend = _requestContentLength = [contentLengthString intValue];
            if (!contentLengthString && [_command isEqualToString:@"CONNECT"]) {
                _dataLeftToSend = -1;
            }
            _port = [[_requestURL port] integerValue];
            if (!_port) {
                if ([[_requestURL scheme] isEqualToString:@"http"]) {
                    _port = 80;
                } else if ([[_requestURL scheme] isEqualToString:@"https"]) {
                    _port = 443;
                }
            }
            [self _processRequest];
        }
    } else {
        result = [self _sendDataToServer:data];
    }
    return result;
}

- (void)startReceivingData
{
    _receiveData = YES;
    [(NSInputStream *)_readStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
}

- (void)closeRequest
{
    CFReadStreamClose(_readStream);
    CFWriteStreamClose(_writeStream);
}

@end
