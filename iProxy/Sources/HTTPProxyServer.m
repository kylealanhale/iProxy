//
//  HTTPProxyServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "HTTPProxyServer.h"
#import "SharedHeader.h"
#import "HTTPProxySocketWrapper.h"
#include "polipo.h"

static NSMutableDictionary *_plpEvent = nil;
int daemonise = 0;
AtomPtr configFile = NULL;
AtomPtr pidFile = NULL;

@interface PLPEvent : NSObject
{
    void *_event;
}
@end

@implementation PLPEvent

+ (id)eventWithHandlerPtr:(void *)event
{
    return [_plpEvent objectForKey:[NSValue valueWithPointer:event]];
}

- (id)initWithEvent:(void *)event
{
    self = [self init];
    if (self) {
        _event = event;
    }
    return self;
}

- (void)dealloc
{
    free(_event);
    [super dealloc];
}

- (void)registerEvent
{
    [_plpEvent setObject:self forKey:[NSValue valueWithPointer:_event]];
}

- (void)unregisterEvent
{
    [[self retain] autorelease];
    [_plpEvent removeObjectForKey:[NSValue valueWithPointer:_event]];
}

@end

@interface PLPTimeEvent : PLPEvent
{
    int _seconds;
    NSTimer *_timer;
}
@property (readonly, nonatomic) TimeEventHandlerPtr timeEventHandlerPtr;
- (void)schedule;
- (void)unschedule;
@end

@implementation PLPTimeEvent

- (id)initWithSeconds:(int)seconds handler:(void *)handler dataSize:(int)dataSize data:(void *)data
{
    self = [self init];
    if (self) {
        _event = malloc(sizeof(TimeEventHandlerRec) - 1 + dataSize);
        self.timeEventHandlerPtr->next = NULL;
        self.timeEventHandlerPtr->previous = NULL;
        self.timeEventHandlerPtr->handler = handler;
        _seconds = seconds;
        if(dataSize > 0) {
            memcpy(self.timeEventHandlerPtr->data, data, dataSize);
        }
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (TimeEventHandlerPtr)timeEventHandlerPtr
{
    return _event;
}

- (void)schedule
{
    _timer = [[NSTimer scheduledTimerWithTimeInterval:_seconds target:self selector:@selector(timerTriggered:) userInfo:nil repeats:NO] retain];
    [self registerEvent];
}

- (void)unschedule
{
    [_timer invalidate];
    [_timer release];
    _timer = nil;
    [self unregisterEvent];
}

- (void)timerTriggered:(id)unused
{
    self.timeEventHandlerPtr->handler(self.timeEventHandlerPtr);
    [self unregisterEvent];
}

@end

static int scheduleTimeEvent_count = 0;

TimeEventHandlerPtr scheduleTimeEvent(int seconds, int (*handler)(TimeEventHandlerPtr), int dsize, void *data)
{
    PLPTimeEvent *timeEvent;
    TimeEventHandlerPtr result;
    
    timeEvent = [[PLPTimeEvent alloc] initWithSeconds:seconds handler:handler dataSize:dsize data:data];
    [timeEvent schedule];
    result = timeEvent.timeEventHandlerPtr;
    [timeEvent release];
    printf("scheduleTimeEvent event(%d) %p (%p)\n", scheduleTimeEvent_count++, result, timeEvent);
    return result;
}

void cancelTimeEvent(TimeEventHandlerPtr event)
{
    PLPTimeEvent *timeEvent;
    
    printf("cancelTimeEvent event %p\n", event);
    timeEvent = [PLPTimeEvent eventWithHandlerPtr:event];
    [timeEvent unschedule];
}

void polipoExit()
{
    assert("test");
}

@interface PLPWrapperEvent : PLPEvent
{
}
@property(readonly, nonatomic) FdEventHandlerPtr fdEvent;
@end

@implementation PLPWrapperEvent

- (id)initWithFDEvent:(FdEventHandlerPtr)event
{
    self = [self init];
    if (self) {
        ConnectRequestPtr request = (ConnectRequestPtr)&event->data;
        
        printf("init event %p %p %s:%d\n", event, self, __FILE__, __LINE__);
        printf("\trequest %p addr %p\n", request, request->addr);
        [self initWithEvent:event];
    }
    return self;
}

- (void)dealloc
{
    printf("dealloc %p\n", self);
    [super dealloc];
}

- (FdEventHandlerPtr)fdEvent
{
    return _event;
}

- (void)streamNotification:(NSNotification *)notification
{
    if (((FdEventHandlerPtr)_event)->handler) {
        int done;
        
        done = ((FdEventHandlerPtr)_event)->handler(0, _event);
        if (done) {
            [self unregisterEvent];
        }
    }
}

- (void)registerEvent
{
    HTTPProxySocketWrapper *wrapper;
    
    wrapper = [HTTPProxySocketWrapper httpProxySocketWrapperForNativeSocket:self.fdEvent->fd];
    if (!wrapper) {
        wrapper = [HTTPProxySocketWrapper createHTTPProxySocketWrapperForNativeSocket:self.fdEvent->fd];
    }
    if (self.fdEvent->poll_events & POLLIN) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(streamNotification:) name:HTTPProxySocketWrapperReadStreamNotification object:wrapper];
    }
    if (self.fdEvent->poll_events & POLLOUT) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(streamNotification:) name:HTTPProxySocketWrapperWriteStreamNotification object:wrapper];
    }
    [super registerEvent];
}

- (void)unregisterEvent
{
    HTTPProxySocketWrapper *wrapper;
    
    wrapper = [HTTPProxySocketWrapper httpProxySocketWrapperForNativeSocket:self.fdEvent->fd];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:wrapper];
    [super unregisterEvent];
}

@end

static int registerFdEventHelper_count = 0;

FdEventHandlerPtr registerFdEventHelper(FdEventHandlerPtr event)
{
    PLPWrapperEvent *fdEvent;
    
    printf("registerFdEventHelper(%d) %p\n", registerFdEventHelper_count++, event);
    fdEvent = [[PLPWrapperEvent alloc] initWithFDEvent:event];
    [fdEvent registerEvent];
    [fdEvent autorelease];
    return event;
}

void unregisterFdEventI(FdEventHandlerPtr event, int i)
{
    PLPWrapperEvent *fdEvent;
    
    fdEvent = [PLPWrapperEvent eventWithHandlerPtr:event];
    [fdEvent unregisterEvent];
}

void unregisterFdEvent(FdEventHandlerPtr event)
{
    unregisterFdEventI(event, 0);
}


@implementation HTTPProxyServer

+ (NSString *)pacFilePath
{
    return @"/http.pac";
}

- (id)init
{
    NSLog(@"http proxy port: %d", HTTP_PROXY_PORT);
    self = [super init];
    if (self) {
        _plpEvent = [[NSMutableDictionary alloc] init];
        initAtoms();
        CONFIG_VARIABLE(daemonise, CONFIG_BOOLEAN, "Run as a daemon");
        CONFIG_VARIABLE(pidFile, CONFIG_ATOM, "File with pid of running daemon.");
        
        preinitChunks();
        preinitLog();
        preinitObject();
        preinitIo();
        preinitDns();
        preinitServer();
        preinitHttp();
        preinitDiskcache();
        preinitLocal();
        preinitForbidden();
        preinitSocks();
        
//        parseConfigLine("parentProxy=\"Jet-iPhone.local.:1080\"", "command line", 0, 0);
//        parseConfigLine("socksProxyType=\"socks5\"", "command line", 0, 0);
        
        initChunks();
        initLog();
        initObject();
        initIo();
        initDns();
        initHttp();
        initServer();
        initDiskcache();
        initForbidden();
        initSocks();
    }
    return self;
}

- (NSString *)serviceDomain
{
	return HTTP_PROXY_DOMAIN;
}

- (int)servicePort
{
	return HTTP_PROXY_PORT;
}

- (NSString *)pacFileContentWithCurrentIP:(NSString *)ip
{
    return [NSString stringWithFormat:@"function FindProxyForURL(url, host) { return \"PROXY %@:%d\"; }", ip, self.servicePort];
}

- (void)didOpenConnection:(NSDictionary *)info
{
    int nativeSocket;
    
    nativeSocket = [[info objectForKey:@"handle"] fileDescriptor];
    httpAccept(nativeSocket, NULL, NULL);
}

- (void)didCloseConnection:(NSDictionary *)info
{
    NSLog(@"test1");
}

@end
