//
//  PMSAppDelegate.h
//  iProxyMacSetup
//
//  Created by Jérôme Lebel on 18/09/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define INTERFACE_NAME @"name"
#define INTERFACE_DEVICE_NAME @"device"
#define INTERFACE_ENABLED @"enabled"

#define PROXY_SERVICE_KEY @"service"
#define PROXY_HOST_NAME_KEY @"hostname"
#define PROXY_DEVICE_KEY @"device"
#define PROXY_RESOLVING_KEY @"resolving"

#define SSH_CONFIG_PREF_KEY @"SSH_CONFIG"

@class PMSSSHFileController;

@interface PMSAppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>
{
	NSMutableArray *proxyServiceList;
    NSMutableDictionary *deviceList;
    PMSSSHFileController *sshFileController;
    
    BOOL browsing;
    BOOL automatic;
    NSUInteger resolvingServiceCount;
    
    NSString *proxyEnabledInterfaceName;
    NSString *currentProxyServer;
    NSUInteger currentProxyPort;
    BOOL proxyEnabled;
}

@property(nonatomic, readonly, assign) BOOL browsing;
@property(nonatomic, readwrite, assign) BOOL automatic;
@property(nonatomic, readonly, assign) BOOL proxyEnabled;
@property(nonatomic, readonly, assign) NSUInteger resolvingServiceCount;
@property(nonatomic, readonly, retain) NSArray *proxyServiceList;

- (void)startBrowsingServices;
- (void)enableProxy:(NSDictionary *)proxy;
- (void)disableCurrentProxy;

- (BOOL)isProxyReady:(NSDictionary *)proxy;

- (IBAction)openPreferences:(id)sender;

@end
