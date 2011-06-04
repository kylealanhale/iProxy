//
//  HTTPProxyServer.h
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SocketServer.h"

@class HTTPProxyRequest;

@interface HTTPProxyServer : SocketServer <NSNetServiceDelegate, ProxyServer>
{
    NSMutableDictionary *_pendingData;
    NSMutableDictionary *_incomingHeaderRequest;
}

- (void)closingRequest:(HTTPProxyRequest *)request fileHandle:(NSFileHandle *)fileHandle;

@end
