//
//  HTTPProxySocketWrapper.m
//  iProxy
//
//  Created by Jérôme Lebel on 24/07/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "HTTPProxySocketWrapper.h"
#include <sys/socket.h>

@interface HTTPProxySocketWrapper()

- (void)open;
- (void)close;

@end

size_t iproxyWrite(int nativeSocket, void *bytes, size_t length)
{
    HTTPProxySocketWrapper *wrapper;
    
    wrapper = [HTTPProxySocketWrapper httpProxySocketWrapperForNativeSocket:nativeSocket];
    return [wrapper writeData:bytes length:length];
}

size_t iproxyRead(int nativeSocket, void *bytes, size_t length)
{
    HTTPProxySocketWrapper *wrapper;
    
    wrapper = [HTTPProxySocketWrapper httpProxySocketWrapperForNativeSocket:nativeSocket];
    return [wrapper readData:bytes length:length];
}

size_t iproxyWritev(int nativeSocket, const struct iovec *iov, int iovcnt)
{
    size_t result;
    int ii;
    
    for (ii = 0; ii < iovcnt; ii++) {
        result += iproxyWrite(nativeSocket, iov[ii].iov_base, iov[ii].iov_len);
    }
    return result;
}

size_t iproxyReadv(int nativeSocket, const struct iovec *iov, int iovcnt)
{
    size_t result;
    int ii;
    
    for (ii = 0; ii < iovcnt; ii++) {
        result += iproxyRead(nativeSocket, iov[ii].iov_base, iov[ii].iov_len);
    }
    return result;
}

void iproxyClose(int nativeSocket)
{
    NSLog(@"------------ close");
    [HTTPProxySocketWrapper closeHTTPProxySocketWrapperForNativeSocket:nativeSocket];
    close(nativeSocket);
}

static void readStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
    printf("read %d\n", (int)type);
    [(id)clientCallBackInfo readStreamCallbackWithType:type];
}

static void writeStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
    printf("write %d\n", (int)type);
    [(id)clientCallBackInfo writeStreamCallbackWithType:type];
}

@implementation HTTPProxySocketWrapper

NSMutableDictionary *wrappers = NULL;

+ (HTTPProxySocketWrapper *)httpProxySocketWrapperForNativeSocket:(int)nativeSocket
{
    HTTPProxySocketWrapper *wrapper;
    NSNumber *key;
    
    key = [[NSNumber alloc] initWithInt:nativeSocket];
    wrapper = [wrappers objectForKey:key];
    [key release];
    return wrapper;
}

+ (HTTPProxySocketWrapper *)createHTTPProxySocketWrapperForNativeSocket:(int)nativeSocket
{
    HTTPProxySocketWrapper *wrapper;
    NSNumber *key;
    
    wrapper = [[HTTPProxySocketWrapper alloc] initWithNativeSocket:nativeSocket];
    [wrapper open];
    if (!wrappers) {
        wrappers = [[NSMutableDictionary alloc] init];
    }
    key = [[NSNumber alloc] initWithInt:nativeSocket];
    [wrappers setObject:wrapper forKey:key];
    [key release];
    [wrapper release];
    return wrapper;
}

+ (void)closeHTTPProxySocketWrapperForNativeSocket:(int)nativeSocket
{
    HTTPProxySocketWrapper *wrapper;
    NSNumber *key;
    
    key = [[NSNumber alloc] initWithInt:nativeSocket];
    wrapper = [wrappers objectForKey:key];
    [wrapper close];
    [wrappers removeObjectForKey:key];
    [key release];
}

- (id)initWithNativeSocket:(int)nativeSocket
{
    self = [self init];
    if (self) {
        _nativeSocket = nativeSocket;
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"dealloc wrapper for native socket %d", _nativeSocket);
    [super dealloc];
}

- (void)readStreamCallbackWithType:(CFStreamEventType)type
{
    printf("read from %d type %d\n", _nativeSocket, (int)type);
    [[NSNotificationCenter defaultCenter] postNotificationName:HTTPProxySocketWrapperReadStreamNotification object:self];
}

- (void)writeStreamCallbackWithType:(CFStreamEventType)type
{
    printf("write from %d type %d\n", _nativeSocket, (int)type);
    [[NSNotificationCenter defaultCenter] postNotificationName:HTTPProxySocketWrapperWriteStreamNotification object:self];
}

- (CFIndex)writeData:(void *)bytes length:(CFIndex)length
{
    return CFWriteStreamWrite(_writeStream, bytes, length);
}

- (CFIndex)readData:(void *)bytes length:(CFIndex)length
{
    return CFReadStreamRead(_readStream, bytes, length);
}

- (void)open
{
    CFStreamClientContext streamContext = { 0, self, NULL, NULL, NULL };
    CFRunLoopRef runloop;
    
    printf("open socket stream for socket %d\n", _nativeSocket);
    runloop = CFRunLoopGetCurrent();
    CFStreamCreatePairWithSocket(NULL, _nativeSocket, &_readStream, &_writeStream);
    
    CFReadStreamSetClient(_readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, readStreamCallback, &streamContext);
    CFReadStreamScheduleWithRunLoop(_readStream, runloop, kCFRunLoopCommonModes);
    
    CFWriteStreamSetClient(_writeStream, kCFStreamEventHasBytesAvailable | kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, writeStreamCallback, &streamContext);
    CFWriteStreamScheduleWithRunLoop(_writeStream, runloop, kCFRunLoopCommonModes);
    
    CFReadStreamSetProperty(_readStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeBackground);
    CFWriteStreamSetProperty(_writeStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeBackground);
  
    CFReadStreamOpen(_readStream);
    CFWriteStreamOpen(_writeStream);
}

- (void)close
{
    NSLog(@"%@ %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
    CFReadStreamClose(_readStream);
    CFRelease(_readStream);
    
    CFWriteStreamClose(_writeStream);
    CFRelease(_writeStream);
}

@end
