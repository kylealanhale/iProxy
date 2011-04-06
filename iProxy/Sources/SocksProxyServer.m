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

#define TOTAL_UPLOAD_KEY @"SocksProxyServer.totalDUpload"
#define TOTAL_DOWNLOAD_KEY @"SocksProxyServer.totalDownload"

@interface SocksProxyServer()
- (void)updateTmpTransferWithSocket:(SOCK_INFO *)si logInfo:(LOGINFO *)li download:(ssize_t)download upload:(ssize_t)upload;
@end

int proto_socks(SOCKS_STATE *state);
void relay(SOCKS_STATE *state);
extern u_long idle_timeout;
extern void (*log_end_transfer_callback)(SOCK_INFO *si, LOGINFO *li, struct timeval elp, const char *prc_ip, const char *prc_port, const char *myc_ip, const char *myc_port, const char *mys_ip, const char *mys_port, const char *prs_ip, const char *prs_port);
extern void (*log_tmp_transfer_callback)(SOCK_INFO *si, LOGINFO *li, ssize_t download, ssize_t upload);
extern void (*msg_out_callback)__P((int, const char *, ...));

static void my_log_end_transfer_callback(SOCK_INFO *si, LOGINFO *li, struct timeval elp, const char *prc_ip, const char *prc_port, const char *myc_ip, const char *myc_port, const char *mys_ip, const char *mys_port, const char *prs_ip, const char *prs_port)
{
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
        msg_out_callback = NULL;
        log_end_transfer_callback = my_log_end_transfer_callback;
        log_tmp_transfer_callback = my_log_tmp_transfer_callback;
        _totalUpload = [[[NSUserDefaults standardUserDefaults] objectForKey:TOTAL_UPLOAD_KEY] unsignedLongLongValue];
        _totalDownload = [[[NSUserDefaults standardUserDefaults] objectForKey:TOTAL_DOWNLOAD_KEY] unsignedLongLongValue];
    }
    return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (NSString *)serviceDomain
{
	return SOCKS_PROXY_DOMAIN;
}

- (int)servicePort
{
	return SOCKS_PROXY_PORT;
}

- (void)_stopped
{
    [self saveTotalBytes];
    [super _stopped];
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
    [self performSelectorOnMainThread:@selector(closeConnection:) withObject:info waitUntilDone:NO];
    [pool drain];
}

- (void)didOpenConnection:(NSDictionary *)info
{
    if (!_lastBandwidthQueryDate) {
        _lastBandwidthQueryDate = [[NSDate date] retain];
    }
	[NSThread detachNewThreadSelector:@selector(processIncomingConnection:) toTarget:self withObject:info];
}

- (void)didCloseConnection:(NSDictionary *)info
{
}

- (void)getBandwidthStatWithUpload:(double *)uploadBandwidth download:(double *)downloadBandwidth
{
    UInt64 upload;
    UInt64 download;
    
	@synchronized (self) {
        upload = _upload;
        download = _download;
        _upload = 0;
        _download = 0;
    }
    if (_lastBandwidthQueryDate) {
        NSDate *now;
        NSTimeInterval interval;
        
        now = [NSDate date];
        interval = [now timeIntervalSinceDate:_lastBandwidthQueryDate];
        if (uploadBandwidth) {
            if (interval) {
                *uploadBandwidth = upload / interval;
            } else {
                *uploadBandwidth = 0;
            }
        }
        if (downloadBandwidth) {
            if (interval) {
                *downloadBandwidth = download / interval;
            } else {
                *downloadBandwidth = 0;
            }
        }
        [_lastBandwidthQueryDate release];
        _lastBandwidthQueryDate = [now retain];
    } else {
        if (uploadBandwidth) {
            *uploadBandwidth = 0;
        }
        if (downloadBandwidth) {
            *downloadBandwidth = 0;
        }
    }
}

- (void)updateTmpTransferWithSocket:(SOCK_INFO *)si logInfo:(LOGINFO *)li download:(ssize_t)download upload:(ssize_t)upload
{
    @synchronized(self) {
        _upload += upload;
        _download += download;
        _totalUpload += upload;
        _totalDownload += download;
    }
}

- (void)getTotalBytesWithUpload:(UInt64 *)upload download:(UInt64 *)download
{
    @synchronized(self) {
        *upload = _totalUpload;
        *download = _totalDownload;
    }
}

- (void)resetTotalBytes
{
    @synchronized(self) {
        _totalUpload = 0;
        _totalDownload = 0;
    }
}

- (void)saveTotalBytes
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedLongLong:_totalUpload] forKey:TOTAL_UPLOAD_KEY];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedLongLong:_totalDownload] forKey:TOTAL_DOWNLOAD_KEY];
}


- (NSString *)pacFileContentWithCurrentIP:(NSString *)ip
{
    return [NSString stringWithFormat:@"function FindProxyForURL(url, host) { return \"SOCKS %@:%d\"; }", ip, self.servicePort];
}

@end
