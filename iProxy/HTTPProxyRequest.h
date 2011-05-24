//
//  HTTPProxyRequest.h
//  iProxy
//
//  Created by Jérôme Lebel on 17/05/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HTTPProxyServer;
@class HTTPProxyRequestToServer;

@interface HTTPProxyRequest : NSObject<NSStreamDelegate>
{
    NSFileHandle *_incomingFileHandle;
    HTTPProxyServer *_httpProxyServer;
    NSMutableData *_incomingData;
    HTTPProxyRequestToServer *_incomingRequest;
    
    NSMutableArray *_requests;
}

- (id)initWithFileHandle:(NSFileHandle *)fileHandle httpProxyServer:(HTTPProxyServer *)server;
- (void)sendDataToClient:(NSData *)data fromRequest:(HTTPProxyRequestToServer *)request;
- (void)serverRequestClosed:(HTTPProxyRequestToServer *)serverRequest;

@end
