//
//  SocksProxyServer.m
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SocksProxyServer.h"
#import "SharedHeader.h"
#include "srelay.h"

@interface SocksProxyServer()
- (void)updateTmpTransferWithSocket:(SOCK_INFO *)si logInfo:(LOGINFO *)li download:(ssize_t)download upload:(ssize_t)upload;
@end

int proto_socks(SOCKS_STATE *state);
void relay(SOCKS_STATE *state);
extern u_long idle_timeout;
extern void (*log_end_transfer_callback)(SOCK_INFO *si, LOGINFO *li, struct timeval elp, const char *prc_ip, const char *prc_port, const char *myc_ip, const char *myc_port, const char *mys_ip, const char *mys_port, const char *prs_ip, const char *prs_port);
extern void (*log_tmp_transfer_callback)(SOCK_INFO *si, LOGINFO *li, ssize_t download, ssize_t upload);

static void my_log_end_transfer_callback(SOCK_INFO *si, LOGINFO *li, struct timeval elp, const char *prc_ip, const char *prc_port, const char *myc_ip, const char *myc_port, const char *mys_ip, const char *mys_port, const char *prs_ip, const char *prs_port)
{
    NSLog(@"%s:%s-%s:%s/%s:%s-%s:%s %lu(%lu/%lu) %ld.%06u",
            prc_ip, prc_port, myc_ip, myc_port,
            mys_ip, mys_port, prs_ip, prs_port,
            li->bc, li->upl, li->dnl,
            elp.tv_sec, elp.tv_usec);
//    [(SocksProxyServer *)[SocksProxyServer sharedServer] updateEndTransferWithSocket:si logInfo:li];
}

static void my_log_tmp_transfer_callback(SOCK_INFO *si, LOGINFO *li, ssize_t download, ssize_t upload)
{
    [(SocksProxyServer *)[SocksProxyServer sharedServer] updateTmpTransferWithSocket:si logInfo:li download:download upload:upload];
}

@implementation SocksProxyServer

+ (NSString *)pacFilePath
{
    return @"/socks.pac";
}

- (id)init
{
	self = [super init];
    if (self) {
        _logInfoValues = [[NSMutableDictionary alloc] init];
        log_end_transfer_callback = my_log_end_transfer_callback;
        log_tmp_transfer_callback = my_log_tmp_transfer_callback;
    }
    return self;
}

- (void)dealloc
{
	[_logInfoValues release];
	[super dealloc];
}

- (NSString *)serviceDomaine
{
	return SOCKS_PROXY_DOMAIN;
}

- (int)servicePort
{
	return SOCKS_PROXY_PORT;
}

- (void)processIncomingConnection:(NSDictionary *)info
{
	NSAutoreleasePool *pool;
    SOCKS_STATE state;
    SOCK_INFO si;
    NSFileHandle *fileHandle = [info objectForKey:@"handle"];
    
    pool = [[NSAutoreleasePool alloc] init];
	memset(&state, 0, sizeof(state));
    memset(&si, 0, sizeof(si));
    state.si = &si;
    state.s = [fileHandle fileDescriptor];
    if (proto_socks(&state) == 0) {
        relay(&state);
	    close(state.r);
    }
    [fileHandle closeFile];
    [self performSelectorOnMainThread:@selector(_closeConnexion:) withObject:info waitUntilDone:NO];
    [pool drain];
}

- (void)_receiveIncomingConnectionWithInfo:(NSDictionary *)info
{
	[NSThread detachNewThreadSelector:@selector(processIncomingConnection:) toTarget:self withObject:info];
}

- (void)getBandwidthStatWithUpload:(UInt64 *)upload download:(UInt64 *)download
{
	@synchronized (_logInfoValues) {
        *upload = _upload;
        *download = _download;
        _upload = 0;
        _download = 0;
    }
}

- (void)updateTmpTransferWithSocket:(SOCK_INFO *)si logInfo:(LOGINFO *)li download:(ssize_t)download upload:(ssize_t)upload
{
    @synchronized(_logInfoValues) {
        _download += download;
        _upload += upload;
    }
}

@end
