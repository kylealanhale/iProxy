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
#include <arpa/inet.h>
#import "NSStringAdditions.h"

static void socketCallback(CFSocketRef sock, CFSocketCallBackType type, CFDataRef address, const void *data, SocketServer* server)
{
	[server socketCallbackWithSocket:sock type:type address:address data:data];
}

@implementation GenericServer

@synthesize state = _state; 
@synthesize serviceDomain;

+ (id)sharedServer
{
	static NSMutableDictionary *servers = nil;
    id server;
    
    if (!servers) {
    	servers = [[NSMutableDictionary alloc] init];
    }
    server = [servers objectForKey:NSStringFromClass([self class])];
    if (!server) {
        server = [[[self class] alloc] init];
        [servers setObject:server forKey:NSStringFromClass([self class])];
        [server autorelease];
    }
    return server;
}

+ (NSString *)pacFilePath
{
    NSAssert(FALSE, @"not implemented");
    return nil;
}

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

- (NSString *)pacFileContentWithCurrentIP:(NSString *)ip
{
    NSAssert(FALSE, @"not implemented");
    return nil;
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
		_connexionPerIP = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_connexionPerIP release];
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
    [self _createSocket];
	CFRunLoopRef rl = CFRunLoopGetCurrent();
	for (unsigned int ii = 0; ii < (sizeof(_sockets) / sizeof(_sockets[0])); ii++) {
	
		// Create the run loop source for putting on the run loop.
        if (_sockets[ii]) {
			_runLoopSource[ii] = CFSocketCreateRunLoopSource(NULL, _sockets[ii], 0);
			if (_runLoopSource[ii] == NULL)
				break;
			
			// Add the run loop source to the current run loop and default mode.
			CFRunLoopAddSource(rl, _runLoopSource[ii], kCFRunLoopCommonModes);
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
        if (_sockets[0]) {
            CFSocketInvalidate(_sockets[0]);
            CFRelease(_sockets[0]);
            _sockets[0] = nil;
        }
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
        if (_sockets[1]) {
            CFSocketInvalidate(_sockets[1]);
            CFRelease(_sockets[1]);
            _sockets[1] = nil;
        }
        [self _setLastErrorWithMessage:@"Unable to bind socket to address6."];
        return NO;
    }
	CFRelease(addressData);
   
    return YES;
}

- (void)_closeSocket
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleConnectionAcceptedNotification object:nil];
    
    for (NSMutableSet *connexions in [_connexionPerIP allValues]) {
        for (NSFileHandle *handle in connexions) {
            [handle closeFile];
        }
    }
    [_connexionPerIP removeAllObjects];
	
	CFRunLoopRef rl = CFRunLoopGetCurrent();
    for (int ii = 0; ii < sizeof(_sockets) / sizeof(_sockets[0]); ii++) {
    	if (_runLoopSource[ii]) {
        	CFRunLoopRemoveSource(rl, _runLoopSource[ii], kCFRunLoopCommonModes);
			CFRelease(_runLoopSource[ii]);
            _runLoopSource[ii] = NULL;
        }
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

- (void)socketCallbackWithSocket:(CFSocketRef)sock type:(CFSocketCallBackType)type address:(CFDataRef)address data:(const void *)data
{
	assert((sock == _sockets[0]) || (sock == _sockets[1]));

	// Only care about accept callbacks.
    if (type == kCFSocketAcceptCallBack) {
    	int description;
        NSFileHandle *handle;
        NSDictionary *info;
        
		assert((data != NULL) && (*((CFSocketNativeHandle*)data) != -1));
		
        description = *(CFSocketNativeHandle*)data;
        handle = [[NSFileHandle alloc] initWithFileDescriptor:description];
        info = [[NSDictionary alloc] initWithObjectsAndKeys:handle, @"handle", address, @"address", [NSString addressFromData:(NSData *)address], @"ip", nil];
        [self newReceiveIncomingConnectionWithInfo:info];
        [info release];
        [handle release];
	}
}

- (void)newReceiveIncomingConnectionWithInfo:(NSDictionary *)info
{
    NSMutableArray *connexions;
    
    [self willChangeValueForKey:@"connexionCount"];
    _connexionCount++;
    connexions = [_connexionPerIP objectForKey:[info objectForKey:@"ip"]];
    if (!connexions) {
        [self willChangeValueForKey:@"computerCount"];
        connexions = [[NSMutableSet alloc] init];
        [_connexionPerIP setObject:connexions forKey:[info objectForKey:@"ip"]];
        [connexions autorelease];
        [self didChangeValueForKey:@"computerCount"];
    }
    [connexions addObject:[info objectForKey:@"handle"]];
    [self didOpenConnection:info];
    [self didChangeValueForKey:@"connexionCount"];
}

- (void)didOpenConnection:(NSDictionary *)info
{
	NSAssert(NO, @"should be implemented in sub class");
}

- (void)closeConnexion:(NSDictionary *)info
{
    NSMutableSet *connexions;
    
    [self willChangeValueForKey:@"connexionCount"];
    _connexionCount--;
	[[info objectForKey:@"handle"] closeFile];
    connexions = [_connexionPerIP objectForKey:[info objectForKey:@"ip"]];
    [connexions removeObject:[info objectForKey:@"handle"]];
    if (connexions && [connexions count] == 0) {
        [self willChangeValueForKey:@"computerCount"];
        [_connexionPerIP removeObjectForKey:[info objectForKey:@"ip"]];
        [self didChangeValueForKey:@"computerCount"];
    }
    [self didCloseConnection:info];
    [self didChangeValueForKey:@"connexionCount"];
}

- (void)didCloseConnection:(NSDictionary *)info
{
}

- (NSUInteger)connexionCount
{
	return _connexionCount;
}

- (NSUInteger)ipCount
{
    return [_connexionPerIP count];
}

@end