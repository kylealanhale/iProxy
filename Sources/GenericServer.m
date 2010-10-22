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
		responseHandlers = [[NSMutableSet alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[responseHandlers release];
	[super dealloc];
}

- (void)_setLastErrorWithMessage:(NSString *)message
{
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

- (BOOL)_openSocket
{
    socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, 0, NULL, NULL);
    if (!socket) {
        [self _setLastErrorWithMessage:@"Unable to create socket."];
        return NO;
    }

    int reuse = true;
    int fileDescriptor = CFSocketGetNative(socket);
    if (setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, (void *)&reuse, sizeof(int)) != 0) {
        CFSocketInvalidate(socket);
    	CFRelease(socket);
        socket = nil;
        [self _setLastErrorWithMessage:@"Unable to set socket options."];
        return NO;
    }
    
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons(self.servicePort);
    CFDataRef addressData = CFDataCreate(NULL, (const UInt8 *)&address, sizeof(address));
    
    if (CFSocketSetAddress(socket, addressData) != kCFSocketSuccess) {
        CFSocketInvalidate(socket);
    	CFRelease(socket);
        socket = nil;
        [self _setLastErrorWithMessage:@"Unable to bind socket to address."];
        return NO;
    }
    CFRelease(addressData);

    listeningHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileDescriptor closeOnDealloc:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveIncomingConnectionNotification:) name:NSFileHandleConnectionAcceptedNotification object:listeningHandle];
    [listeningHandle acceptConnectionInBackgroundAndNotify];
    return YES;
}

- (void)_closeSocket
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleConnectionAcceptedNotification object:nil];

    [responseHandlers removeAllObjects];

    [listeningHandle closeFile];
    [listeningHandle release];
    listeningHandle = nil;
	
    if (socket) {
        CFSocketInvalidate(socket);
        CFRelease(socket);
        socket = nil;
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
}

@end