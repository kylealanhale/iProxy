//
//  SocksProxyServer.h
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GenericServer.h"

#define HTTPProxyServerNewBandwidthStatNotification @"HTTPProxyServerNewBandwidthStatNotification"

@interface SocksProxyServer : SocketServer <NSNetServiceDelegate>
{
    UInt32 _currentStat;
    UInt64 _upload;
    UInt64 _download;
}

+ (SocksProxyServer *)sharedSocksProxyServer;

- (void)_addBandwidthStatWithUpload:(UInt64)upload download:(UInt64)download;
- (void)getBandwidthStatWithUpload:(float *)upload download:(float *)download;

@end
