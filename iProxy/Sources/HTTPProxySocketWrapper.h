//
//  HTTPProxySocketWrapper.h
//  iProxy
//
//  Created by Jérôme Lebel on 24/07/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#define HTTPProxySocketWrapperReadStreamNotification @"HTTPProxySocketWrapperReadStreamNotification"
#define HTTPProxySocketWrapperWriteStreamNotification @"HTTPProxySocketWrapperWriteStreamNotification"

@interface HTTPProxySocketWrapper : NSObject
{
    int _nativeSocket;
    CFRunLoopSourceRef _runLoopSource;
    CFReadStreamRef _readStream;
    CFWriteStreamRef _writeStream;
}

+ (HTTPProxySocketWrapper *)httpProxySocketWrapperForNativeSocket:(int)nativeSocket;
+ (HTTPProxySocketWrapper *)createHTTPProxySocketWrapperForNativeSocket:(int)nativeSocket;
+ (void)closeHTTPProxySocketWrapperForNativeSocket:(int)nativeSocket;

- (id)initWithNativeSocket:(int)nativeSocket;
- (void)readStreamCallbackWithType:(CFStreamEventType)type;
- (void)writeStreamCallbackWithType:(CFStreamEventType)type;
- (CFIndex)writeData:(void *)bytes length:(CFIndex)length;
- (CFIndex)readData:(void *)bytes length:(CFIndex)length;
- (void)sendReadEvent;
- (void)sendWriteEvent;

@end
