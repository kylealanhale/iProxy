/*
 * Copyright 2010, Torsten Curdt
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AppDelegate.h"
#import "MainViewController.h"
#if HTTP_PROXY_ENABLED
#import "HTTPProxyServer.h"
#endif
#import "SocksProxyServer.h"
#import "HTTPServer.h"
#import <netinet/in.h>
#import <AudioToolbox/AudioToolbox.h>

#define ReachableDirectWWAN               (1 << 18)

@interface UIApplication (PrivateAPI)
- (void)_terminateWithStatus:(int)status;
@end

@interface AppDelegate ()
- (void)_checkServerStatus;
- (BOOL)setupReachabilityNotification;
- (void)_reachabilityNotificationWithFlags:(SCNetworkReachabilityFlags)flags;
@end

static void reachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	[(AppDelegate *)info _reachabilityNotificationWithFlags:flags];
}

@implementation AppDelegate

@synthesize window;
@synthesize statusViewController;
@synthesize hasNetwork = _hasNetwork;
@synthesize hasWifi = _hasWifi;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [window addSubview:statusViewController.view];
    [window makeKeyAndVisible];
    
    _proxyServers = [[NSMutableArray alloc] init];
#if HTTP_PROXY_ENABLED
    [_proxyServers addObject:[HTTPProxyServer sharedServer]];
#endif
    [_proxyServers addObject:[SocksProxyServer sharedServer]];

    for (GenericServer *server in _proxyServers) {
        [server addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
    }
    [self _checkServerStatus];
    [self setupReachabilityNotification];
    
    return YES;
}


- (void)beginInterruption
{
}

- (void)endInterruption
{
    AVAudioSession *session = [AVAudioSession sharedInstance];

    NSError *error = nil;

    if (![session setActive:YES error:&error]) {
        NSLog(@"ERROR: audio active %@", error);
    }
    
    // resume playback
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [(SocksProxyServer *)[SocksProxyServer sharedServer] saveTotalBytes];
    if (_serverRunning) {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        session.delegate = self;
        if (![session setCategory:AVAudioSessionCategoryPlayback error:&error]) {
            NSLog(@"ERROR: audio category %@", error);
        }
        
        if (![session setActive:YES error:&error]) {
            NSLog(@"ERROR: audio active %@", error);
        }
        
        NSString *sample = [[NSBundle mainBundle] pathForResource:@"silence" ofType:@"wav"];
        NSURL *url = [NSURL URLWithString:sample];
        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        _player.numberOfLoops = -1;
        _player.volume = 0.00;
        [_player prepareToPlay];
        [_player play];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (_player) {
        NSError *error = nil;
        
        [_player stop];
        [_player release];
        _player = nil;
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        session.delegate = nil;
        if (![session setActive:NO error:&error]) {
            NSLog(@"ERROR: audio active %@", error);
        }
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)_serverRunning
{
    [[HTTPServer sharedHTTPServer] start];
    _serverRunning = YES;
}

- (void)_serverStopped
{
    [[HTTPServer sharedHTTPServer] stop];
    _serverRunning = NO;
}

- (void)_checkServerStatus
{
    BOOL serverRunning = NO;
    
    for (GenericServer *server in _proxyServers) {
        serverRunning = serverRunning || [server state] != SERVER_STATE_STOPPED;
    }
    if (serverRunning && !_serverRunning) {
        [self _serverRunning];
    } else if (!serverRunning && _serverRunning) {
        [self _serverStopped];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self _checkServerStatus];
}

- (void)dealloc
{
    [statusViewController release];
    [window release];
    [super dealloc];
}

- (void)unsetupReachabilityNotification
{
    if (_defaultRouteReachability) {
    	SCNetworkReachabilityUnscheduleFromRunLoop(_defaultRouteReachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        SCNetworkReachabilitySetCallback(_defaultRouteReachability, NULL, NULL);
        CFRelease(_defaultRouteReachability);
        _defaultRouteReachability = NULL;
    }
}

- (void)_reachabilityNotificationWithFlags:(SCNetworkReachabilityFlags)flags
{
	BOOL newHasNetwork;
    BOOL newHasWifi;
    
    newHasNetwork = (flags & kSCNetworkFlagsReachable) ? YES : NO;
    newHasWifi = (flags & ReachableDirectWWAN) ? NO : newHasNetwork;
    if (newHasNetwork != _hasNetwork) {
		AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
    self.hasNetwork = newHasNetwork;
    self.hasWifi = newHasWifi;
}

- (BOOL)setupReachabilityNotification
{
    // Create zero addy
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    SCNetworkReachabilityContext context = { 0, self, NULL, NULL, NULL };
    BOOL result = NO;
	
    // Recover reachability flags
    _defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    
	if (_defaultRouteReachability
    	&& SCNetworkReachabilitySetCallback(_defaultRouteReachability, reachabilityCallback, &context)
        && SCNetworkReachabilityScheduleWithRunLoop(_defaultRouteReachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
        result = YES;
    }
    if (!result && _defaultRouteReachability) {
    	[self unsetupReachabilityNotification];
    } else if (result) {
		SCNetworkReachabilityFlags flags;
        
		if (SCNetworkReachabilityGetFlags(_defaultRouteReachability, &flags)) {
        	self.hasNetwork = YES;
			[self _reachabilityNotificationWithFlags:flags];
		}
    }
    return result;
}

@end
