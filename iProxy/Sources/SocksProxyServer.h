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
    UInt64 _download;
    UInt64 _upload;
    UInt64 _totalDownload;
    UInt64 _totalUpload;
}

- (void)getBandwidthStatWithUpload:(UInt64 *)upload download:(UInt64 *)download;
- (void)getTotalBytesWithUpload:(UInt64 *)upload download:(UInt64 *)download;
- (void)resetTotalBytes;
- (void)saveTotalBytes;

@end
