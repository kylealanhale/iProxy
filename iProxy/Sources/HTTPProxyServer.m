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

TimeEventHandlerPtr scheduleTimeEvent(int seconds, int (*handler)(TimeEventHandlerPtr), int dsize, void *data)
{
    PLPTimeEvent *timeEvent;
    TimeEventHandlerPtr result;
    
    timeEvent = [[PLPTimeEvent alloc] initWithSeconds:seconds handler:handler dataSize:dsize data:data];
    [timeEvent schedule];
    result = timeEvent.timeEventHandlerPtr;
    [timeEvent release];
    printf("scheduleTimeEvent event %p (%p)\n", result, timeEvent);
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

@interface PLPFDEvent : PLPEvent
{
    CFReadStreamRef _readStream;
    CFWriteStreamRef _writeStream;
}
@property(readonly, nonatomic) FdEventHandlerPtr fdEvent;
@end

@implementation PLPFDEvent

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

- (CFOptionFlags)streamEvent
{
    CFOptionFlags result = 0;
    
    if (self.fdEvent->poll_events & POLLIN) {
        result |= kCFStreamEventHasBytesAvailable;
    }
    if (self.fdEvent->poll_events & POLLOUT) {
        result |= kCFStreamEventCanAcceptBytes;
    }
    if (self.fdEvent->poll_events & POLLERR) {
        result |= kCFStreamEventErrorOccurred;
    }
    if (self.fdEvent->poll_events & POLLHUP) {
        result |= kCFStreamEventEndEncountered;
    }
    if (self.fdEvent->poll_events & POLLNVAL) {
        result |= kCFStreamEventEndEncountered;
    }
    return result;
}

- (void)readStreamCallbackWithEvent:(CFStreamEventType)type
{
    if (((FdEventHandlerPtr)_event)->handler) {
        int done;
        
        printf("read event %p read stream %p type %d\n", _event, _readStream, (int)type);
        done = ((FdEventHandlerPtr)_event)->handler(0, _event);
        if (done) {
            [self unregisterEvent];
        }
    }
}

- (void)writeStreamCallbackWithEvent:(CFStreamEventType)type
{
    if (((FdEventHandlerPtr)_event)->handler) {
        int done;
        
        printf("write event %p write stream %p type %d\n", _event, _writeStream, (int)type);
        done = ((FdEventHandlerPtr)_event)->handler(0, _event);
        if (done) {
            [self unregisterEvent];
        }
    }
}

static void PLPFDEventReadStreamClientCallBack(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
    printf("read callback stream %p\n", stream);
    [(id)clientCallBackInfo readStreamCallbackWithEvent:type];
}

static void PLPFDEventWriteStreamClientCallBack(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
    printf("write callback stream %p\n", stream);
    [(id)clientCallBackInfo writeStreamCallbackWithEvent:type];
}

- (void)registerEvent
{
    CFReadStreamRef *readStreamPtr = NULL;
    CFWriteStreamRef *writeStreamPtr = NULL;
    CFStreamClientContext context;
    CFStringRef currentMode;
    CFRunLoopRef runloop;
    
    context.version = 0;
    context.info = self;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    if (self.fdEvent->poll_events & POLLIN) {
        readStreamPtr = &_readStream;
    }
    if (self.fdEvent->poll_events & POLLOUT) {
        writeStreamPtr = &_writeStream;
    }
    CFStreamCreatePairWithSocket(NULL, self.fdEvent->fd, readStreamPtr, writeStreamPtr);
    
    printf("listen read stream %p write stream %p event %p\n", _readStream, _writeStream, _event);
    runloop = CFRunLoopGetCurrent();
    currentMode = CFRunLoopCopyCurrentMode(runloop);
    currentMode = kCFRunLoopCommonModes;
    if (_readStream) {
        CFReadStreamSetClient(_readStream, [self streamEvent], PLPFDEventReadStreamClientCallBack, &context);
        CFReadStreamScheduleWithRunLoop(_readStream, runloop, currentMode);
        CFReadStreamOpen(_readStream);
    }
    if (_writeStream) {
        CFWriteStreamSetClient(_writeStream, [self streamEvent], PLPFDEventWriteStreamClientCallBack, &context);
        CFWriteStreamScheduleWithRunLoop(_writeStream, runloop, currentMode);
        CFWriteStreamOpen(_writeStream);
    }
    
    CFRelease(currentMode);
    [super registerEvent];
}

- (void)unregisterEvent
{
    CFRunLoopRef runloop;
    
    printf("unregister event %p\n", _event);
    runloop = CFRunLoopGetCurrent();
    if (_readStream) {
        CFReadStreamUnscheduleFromRunLoop(_readStream, runloop, kCFRunLoopCommonModes);
    }
    if (_writeStream) {
        CFWriteStreamUnscheduleFromRunLoop(_writeStream, runloop, kCFRunLoopCommonModes);
    }
    [super unregisterEvent];
}

@end

static int registerFdEventHelper_count = 0;

FdEventHandlerPtr registerFdEventHelper(FdEventHandlerPtr event)
{
    PLPFDEvent *fdEvent;
    
    printf("registerFdEventHelper(%d) %p\n", registerFdEventHelper_count++, event);
    fdEvent = [[PLPFDEvent alloc] initWithFDEvent:event];
    [fdEvent registerEvent];
    [fdEvent autorelease];
    return event;
}

void unregisterFdEventI(FdEventHandlerPtr event, int i)
{
    PLPFDEvent *fdEvent;
    
    fdEvent = [PLPFDEvent eventWithHandlerPtr:event];
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
    httpAccept([[info objectForKey:@"handle"] fileDescriptor], NULL, NULL);
}

- (void)didCloseConnection:(NSDictionary *)info
{
    NSLog(@"test1");
}

@end
