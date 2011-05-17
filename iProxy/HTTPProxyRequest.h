//
//  HTTPProxyRequest.h
//  iProxy
//
//  Created by Jérôme Lebel on 17/05/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HTTPProxyServer;

@interface HTTPProxyRequest : NSObject
{
    NSFileHandle *_incomingFileHandle;
    CFHTTPMessageRef _incomingMessage;
    HTTPProxyServer *_httpProxyServer;
    NSMutableData *_incomingData;
}

- (id)initWithFileHandle:(NSFileHandle *)fileHandle httpProxyServer:(HTTPProxyServer *)server;

@end
