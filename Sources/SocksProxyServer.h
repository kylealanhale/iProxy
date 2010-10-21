//
//  SocksProxyServer.h
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GenericServer.h"

@interface SocksProxyServer : SocketServer <NSNetServiceDelegate>
{
	NSUInteger _connexionCount;
}

+ (SocksProxyServer *)sharedSocksProxyServer;

@property(readonly) NSUInteger connexionCount;

@end
