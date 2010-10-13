//
//  GenericServer.h
//  iProxy
//
//  Created by Jérôme Lebel on 12/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum
{
	SERVER_STATE_STOPPED,
	SERVER_STATE_STARTING,
	SERVER_STATE_RUNNING,
	SERVER_STATE_STOPPING
} ServerState;


@interface GenericServer : NSObject <NSNetServiceDelegate>
{
	ServerState _state;
    NSNetService *_netService;
}

@property (readonly, assign) ServerState state;
@property (readonly, getter = serviceDomain) NSString *serviceDomain;
@property (readonly, getter = servicePort) int servicePort;

- (void)start;
- (void)stop;

@end
