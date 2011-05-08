//
//  HTTPProxyServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "HTTPProxyServer.h"
#import "SharedHeader.h"
#include "polipo.h"

static NSMutableDictionary *_plpEvent = nil;
int daemonise = 0;
AtomPtr configFile = NULL;
AtomPtr pidFile = NULL;

@interface PLPTimeEvent : NSObject
{
    TimeEventHandlerPtr _timeEventHandlerPtr;
    int _seconds;
    NSTimer *_timer;
}
@property (readonly, nonatomic) TimeEventHandlerPtr timeEventHandlerPtr;
@end

@implementation PLPTimeEvent

@synthesize timeEventHandlerPtr = _timeEventHandlerPtr;

+ (PLPTimeEvent *)timeEventForTimeEventHandlerPtr:(TimeEventHandlerPtr)ptr
{
    return [_plpEvent objectForKey:[NSValue valueWithPointer:ptr]];
}

- (id)initWithSeconds:(int)seconds handler:(void *)handler dataSize:(int)dataSize data:(void *)data
{
    self = [self init];
    if (self) {
        _timeEventHandlerPtr = malloc(sizeof(*_timeEventHandlerPtr) - 1 + dataSize);
        _timeEventHandlerPtr->next = NULL;
        _timeEventHandlerPtr->previous = NULL;
        _timeEventHandlerPtr->handler = handler;
        _seconds = seconds;
        if(dataSize > 0) {
            memcpy(_timeEventHandlerPtr->data, data, dataSize);
        }
        [_plpEvent setObject:self forKey:[NSValue valueWithPointer:_timeEventHandlerPtr]];
    }
    return self;
}

- (void)dealloc
{
    free(_timeEventHandlerPtr);
    [_timer release];
    [super dealloc];
}

- (void)remove
{
    [_plpEvent removeObjectForKey:[NSValue valueWithPointer:_timeEventHandlerPtr]];
}

- (void)schedule
{
    _timer = [[NSTimer scheduledTimerWithTimeInterval:_seconds target:self selector:@selector(timerTriggered:) userInfo:nil repeats:NO] retain];
}

- (void)cancel
{
    [_timer invalidate];
}

- (void)timerTriggered:(id)unused
{
    _timeEventHandlerPtr->handler(_timeEventHandlerPtr);
    [self remove];
}

@end

TimeEventHandlerPtr scheduleTimeEvent(int seconds, int (*handler)(TimeEventHandlerPtr), int dsize, void *data)
{
    PLPTimeEvent *timeEvent;
    
    timeEvent = [[PLPTimeEvent alloc] initWithSeconds:seconds handler:handler dataSize:dsize data:data];
    [timeEvent schedule];
    [timeEvent autorelease];
    return timeEvent.timeEventHandlerPtr;
}

void cancelTimeEvent(TimeEventHandlerPtr event)
{
    PLPTimeEvent *timeEvent;
    
    timeEvent = [PLPTimeEvent timeEventForTimeEventHandlerPtr:event];
    [timeEvent cancel];
    [timeEvent remove];
}

void polipoExit()
{
    assert("test");
}

FdEventHandlerPtr registerFdEventHelper(FdEventHandlerPtr event)
{
    if(event->poll_events
    return event;
}


@implementation HTTPProxyServer

+ (NSString *)pacFilePath
{
    return @"/http.pac";
}

- (id)init
{
    self = [super init];
    if (self) {
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

//        _listener = create_listener(proxyAddress->string, 
//                                   proxyPort, httpAccept, NULL);
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
    httpAccept([[info objectForKey:@"handle"] fileDescriptor], NULL, NULL);
}

- (void)didCloseConnection:(NSDictionary *)info
{
    NSLog(@"test1");
}

@end
