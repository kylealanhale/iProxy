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
@synthesize headers = _headers;
@synthesize command = _command;
@synthesize dataLeftToSend = _dataLeftToSend;
@synthesize isHeaderComplete = _isHeaderComplete;
@synthesize dataLeftToReceive = _dataLeftToReceive;
@synthesize receivedComplete = _receivedComplete;

- (id)initWithHTTProxyRequest:(HTTPProxyRequest *)request;
{
    self = [self init];
    if (self) {
        _headers = [[NSMutableDictionary alloc] init];
        _isValid = YES;
        _isHeaderComplete = NO;
        _request = request;
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"%@ dealloc", [self class]);
    [_command release];
    [_headers release];
    [super dealloc];
}

- (void)_parseCommand:(NSString *)command
{
    NSArray *list;
    NSString *contentLengthString;
    
    list = [command componentsSeparatedByString:@" "];
    if ([list count] == 3) {
        _command = [[list objectAtIndex:0] retain];
        _requestURL = [[NSURL alloc] initWithString:[list objectAtIndex:1]];
        _httpVersion = [[list objectAtIndex:2] retain];
    } else {
        _isValid = NO;
    }
    contentLengthString = [_headers objectForKey:@"Content-Length"];
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
}

- (void)_parseCommand:(NSString *)string command:(NSString **)command url:(NSURL **)url httpVersion:(NSString **)httpVersion
{
    NSArray *list;
    NSString *contentLengthString;
    
    list = [string componentsSeparatedByString:@" "];
    if ([list count] == 3) {
        *command = [[list objectAtIndex:0] retain];
        *url = [[NSURL alloc] initWithString:[list objectAtIndex:1]];
        *httpVersion = [[list objectAtIndex:2] retain];
    } else {
        _isValid = NO;
    }
    contentLengthString = [_headers objectForKey:@"Content-Length"];
    _dataLeftToSend = _requestContentLength = [contentLengthString intValue];
    if (!contentLengthString && [*command isEqualToString:@"CONNECT"]) {
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
        for (NSString *key in _headers) {
            cString = [key UTF8String];
            [request appendBytes:cString length:strlen(cString)];
            [request appendBytes:": " length:2];
            cString = [[_headers objectForKey:key] UTF8String];
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
                if (available) {
                    NSData * data;
                    
                    data = [[NSData alloc] initWithBytesNoCopy:buffer length:available freeWhenDone:NO];
                    [_request sendDataToClient:data fromRequest:self];
                    [data release];
                }
                NSLog(@"available %d", available);
                break;
            case NSStreamEventErrorOccurred:
            case NSStreamEventEndEncountered:
                if ([stream streamStatus] == NSStreamStatusClosed) {
                    [_request serverRequestClosed:self];
                }
                break;
            default:
                break;
        }
    } else if ((NSStream *)_writeStream == stream) {
    }
}

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

- (NSUInteger)_processDataForHeader:(NSData *)data
{
    const char *bytes;
    NSUInteger length;
    NSUInteger cursor;
    NSUInteger column = 0;
    NSUInteger begin = 0;
    
    bytes = [data bytes];
    length = [data length];
    cursor = 0;
    while (cursor < length - 1 && !_isHeaderComplete) {
        if (bytes[cursor] == ':' && column == begin) {
            column = cursor;
        }
        if (bytes[cursor] == '\r' && bytes[cursor + 1] == '\n') {
            if (!self.command) {
                NSString *string;
                
                NSAssert(begin == 0, @"Should be at the beginning");
                NSAssert(cursor > 0, @"Should not be empty");
                string = [[NSString alloc] initWithBytes:bytes length:cursor encoding:NSUTF8StringEncoding];
                [self _parseCommand:string];
                [string release];
            } else if (cursor == begin) {
                _isHeaderComplete = YES;
            } else {
                NSString *key;
                NSString *value;
                
                key = [[NSString alloc] initWithBytes:bytes + begin length:column - begin encoding:NSUTF8StringEncoding];
                if (bytes[column + 1] == ' ') {
                    column++;
                }
                value = [[NSString alloc] initWithBytes:bytes + column + 1 length:cursor - column - 1 encoding:NSUTF8StringEncoding];
                [self.headers setValue:value forKey:key];
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
    
    if (!self.isHeaderComplete) {
        result = [[self class] _processDataForHeader:data headers:_headers headerComplete:&_isHeaderComplete command:&_command url:&_requestURL httpVersion:&_httpVersion];
        if (_isHeaderComplete) {
            NSString *contentLengthString;
            
            contentLengthString = [_headers objectForKey:@"Content-Length"];
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
