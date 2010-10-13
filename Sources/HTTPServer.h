//
//  HTTPServer.h
//  TextTransfer
//
//  Created by Matt Gallagher on 2009/07/13.
//  Copyright 2009 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import <Foundation/Foundation.h>
#import "GenericServer.h"

@class HTTPResponseHandler;

@interface HTTPServer : GenericServer <NSNetServiceDelegate>
{
	NSError *lastError;
	NSFileHandle *listeningHandle;
	CFSocketRef socket;
	CFMutableDictionaryRef incomingRequests;
	NSMutableSet *responseHandlers;
}

@property (nonatomic, readonly, retain) NSError *lastError;

+ (HTTPServer *)sharedHTTPServer;

- (void)start;
- (void)stop;

- (void)closeHandler:(HTTPResponseHandler *)aHandler;

@end

extern NSString * const HTTPServerNotificationStateChanged;
