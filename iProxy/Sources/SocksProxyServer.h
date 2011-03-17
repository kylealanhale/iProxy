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
    NSMutableArray *_logInfoValues;
}

+ (SocksProxyServer *)sharedSocksProxyServer;

- (void)getBandwidthStatWithUpload:(UInt64 *)upload download:(UInt64 *)download;

@end
