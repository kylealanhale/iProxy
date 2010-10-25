//
//  GenericServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GenericServer.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <CFNetwork/CFNetwork.h>


static void socketCallback(CFSocketRef sock, CFSocketCallBackType type, CFDataRef address, const void *data, SocketServer* server)
{
	[server socketCallbackWithSocket:sock type:type address:address data:data];
}

@implementation GenericServer

@synthesize state = _state; 

- (id)init
{
	self = [super init];
	if (self != nil) {
		_state = SERVER_STATE_STOPPED;
	}
	return self;
}

- (void)dealloc
{
	[_netService release];
	[super dealloc];
}

- (NSString *)serviceDomaine
{
	return nil;
}

- (int)servicePort
{
	return 0;
}

- (BOOL)_starting
{
	return YES;
}

- (void)_started
{
    _netService = [[NSNetService alloc] initWithDomain:@"" type:self.serviceDomaine name:@"" port:self.servicePort];
    _netService.delegate = self;
    [_netService publish];
    [self willChangeValueForKey:@"state"];
    _state = SERVER_STATE_RUNNING;
    [self didChangeValueForKey:@"state"];
}

- (void)_failedStarting
{
    [self willChangeValueForKey:@"state"];
    _state = SERVER_STATE_STOPPED;
    [self didChangeValueForKey:@"state"];
}

- (BOOL)start
{
    BOOL starting = NO;
	if (_state == SERVER_STATE_STOPPED) {
        [self willChangeValueForKey:@"state"];
        _state = SERVER_STATE_STARTING;
        [self didChangeValueForKey:@"state"];
        starting = [self _starting];
        if (!starting) {
        	[self _failedStarting];
        }
    }
    return starting;
}

- (void)_stopping
{
}

- (void)_stopped
{
    [_netService stop];
    [_netService release];
    _netService = nil;
    [self willChangeValueForKey:@"state"];
    _state = SERVER_STATE_STOPPED;
    [self didChangeValueForKey:@"state"];
}

- (void)stop
{
	if (_state == SERVER_STATE_RUNNING) {
        [self willChangeValueForKey:@"state"];
        _state = SERVER_STATE_STOPPING;
        [self didChangeValueForKey:@"state"];
        [self _stopping];
    }
}

@end

@implementation SocketServer

- (id)init
{
	self = [super init];
	if (self != nil) {
		_connexions = [[NSMutableSet alloc] init];
        [self _createSocket];
	}
	return self;
}

- (void)dealloc
{
	[_connexions release];
	[super dealloc];
}

- (void)_setLastErrorWithMessage:(NSString *)message
{
	NSLog(@"********* error %@", message);
	[_lastError release];
	_lastError = [[NSError
		errorWithDomain:@"HTTPServerError"
		code:0
		userInfo:[NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(message, @"", @"HTTPServerErrors") forKey:NSLocalizedDescriptionKey]] retain];
}

- (NSError *)lastError
{
	return _lastError;
}

- (void)_createSocket
{
    int reuse = true;
    
    CFSocketContext socketCtxt = {0, self, (const void*(*)(const void*))&CFRetain, (void(*)(const void*))&CFRelease, (CFStringRef(*)(const void *))&CFCopyDescription };
    _sockets[0] = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&socketCallback, &socketCtxt);
    if (!_sockets[0]) {
        [self _setLastErrorWithMessage:@"Unable to create socket."];
        return;
    }

    if (setsockopt(CFSocketGetNative(_sockets[0]), SOL_SOCKET, SO_REUSEADDR, (void *)&reuse, sizeof(int)) != 0) {
        CFSocketInvalidate(_sockets[0]);
    	CFRelease(_sockets[0]);
        _sockets[0] = nil;
        [self _setLastErrorWithMessage:@"Unable to set socket options."];
        return;
    }
    
    _sockets[1] = CFSocketCreate(kCFAllocatorDefault, PF_INET6, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&socketCallback, &socketCtxt);
    if (!_sockets[1]) {
        [self _setLastErrorWithMessage:@"Unable to create socket."];
        return;
    }

    if (setsockopt(CFSocketGetNative(_sockets[1]), SOL_SOCKET, SO_REUSEADDR, (void *)&reuse, sizeof(int)) != 0) {
        CFSocketInvalidate(_sockets[1]);
    	CFRelease(_sockets[1]);
        _sockets[1] = nil;
        [self _setLastErrorWithMessage:@"Unable to set socket options."];
        return;
    }
}

- (BOOL)_openSocket
{
	CFRunLoopRef rl = CFRunLoopGetCurrent();
	for (unsigned int ii = 0; ii < (sizeof(_sockets) / sizeof(_sockets[0])); ii++) {
	
		// Create the run loop source for putting on the run loop.
        if (_sockets[ii]) {
			CFRunLoopSourceRef src = CFSocketCreateRunLoopSource(NULL, _sockets[ii], 0);
			if (src == NULL)
				break;
			
			// Add the run loop source to the current run loop and default mode.
			CFRunLoopAddSource(rl, src, kCFRunLoopCommonModes);
			CFRelease(src);
        }
    }
    
    struct sockaddr_in addr4;
	CFDataRef addressData;
    
    memset(&addr4, 0, sizeof(addr4));
    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons((UInt16)self.servicePort);
    addr4.sin_addr.s_addr = htonl(INADDR_ANY);
    addressData = CFDataCreateWithBytesNoCopy(NULL, (const UInt8*)&addr4, sizeof(addr4), kCFAllocatorNull);
    
    if (CFSocketSetAddress(_sockets[0], addressData) != kCFSocketSuccess) {
	    CFRelease(addressData);
        CFSocketInvalidate(_sockets[0]);
    	CFRelease(_sockets[0]);
        _sockets[0] = nil;
        [self _setLastErrorWithMessage:@"Unable to bind socket to address."];
        return NO;
    }
    CFRelease(addressData);
    
    
	struct sockaddr_in6 addr6;
    memset(&addr6, 0, sizeof(addr6));

	// Put the local port and address into the native address.
	addr6.sin6_family = AF_INET6;
	addr6.sin6_port = htons((UInt16)self.servicePort);
	addr6.sin6_len = sizeof(addr6);
	memcpy(&(addr6.sin6_addr), &in6addr_any, sizeof(addr6.sin6_addr));
	
    // Wrap the native address structure for CFSocketCreate.
    addressData = CFDataCreateWithBytesNoCopy(NULL, (const UInt8*)&addr6, sizeof(addr6), kCFAllocatorNull);
    
    // Set the local binding which causes the socket to start listening.
	if (CFSocketSetAddress(_sockets[1], addressData) != kCFSocketSuccess) {
	    CFRelease(addressData);
        CFSocketInvalidate(_sockets[1]);
    	CFRelease(_sockets[1]);
        _sockets[1] = nil;
        [self _setLastErrorWithMessage:@"Unable to bind socket to address6."];
        return NO;
    }
	CFRelease(addressData);
   
    return YES;
}

- (void)_closeSocket
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleConnectionAcceptedNotification object:nil];
    
    for (NSFileHandle *handle in _connexions) {
		[handle closeFile];
    }
    [_connexions removeAllObjects];
	
    for (int ii = 0; ii < sizeof(_sockets) / sizeof(_sockets[0]); ii++) {
	    if (_sockets[ii]) {
    	    CFSocketInvalidate(_sockets[ii]);
        	CFRelease(_sockets[ii]);
	        _sockets[ii] = nil;
    	}
    }
}

- (BOOL)_starting
{
    BOOL started;
    
	started = [self _openSocket];
    if (started) {
    	[self _started];
    }
    return started;
}

//
// stop
//
// Stops the server.
//
- (void)_stopping
{
    [self _closeSocket];
    [self _stopped];
}

//
// receiveIncomingConnectionNotification:
//
// Receive the notification for a new incoming request. This method starts
// receiving data from the incoming request's file handle and creates a
// new CFHTTPMessageRef to store the incoming data..
//
// Parameters:
//    notification - the new connection notification
//
- (void)receiveIncomingConnectionNotification:(NSNotification *)notification
{
	[self newReceiveIncomingConnection:[[notification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem]];
}


- (void)socketCallbackWithSocket:(CFSocketRef)sock type:(CFSocketCallBackType)type address:(CFDataRef)address data:(const void *)data
{
	assert((sock == _sockets[0]) || (sock == _sockets[1]));

	// Only care about accept callbacks.
    if (type == kCFSocketAcceptCallBack) {
    	int description;
        NSFileHandle *handle;
        
		assert((data != NULL) && (*((CFSocketNativeHandle*)data) != -1));
		
        description = *(CFSocketNativeHandle*)data;
        handle = [[NSFileHandle alloc] initWithFileDescriptor:description];
        [self newReceiveIncomingConnection:handle];
        [handle release];
	}
}

- (void)newReceiveIncomingConnection:(NSFileHandle *)handle
{
    [self willChangeValueForKey:@"connexionCount"];
    [_connexions addObject:handle];
    [self _receiveIncomingConnection:handle];
    [self didChangeValueForKey:@"connexionCount"];
}

- (void)_receiveIncomingConnection:(NSFileHandle *)incomingFileHandle
{
	NSAssert(NO, @"should be implemented in sub class");
}

- (void)_closeConnexion:(NSFileHandle *)handle
{
	[handle closeFile];
    [_connexions removeObject:handle];
}

- (NSUInteger)connexionCount
{
	return [_connexions count];
}

@end