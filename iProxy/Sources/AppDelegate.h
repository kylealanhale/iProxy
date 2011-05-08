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

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <SystemConfiguration/SCNetworkReachability.h>

#define HTTP_PROXY_ENABLED 1

@class MainViewController;

@interface AppDelegate : NSObject <UIApplicationDelegate, AVAudioSessionDelegate>
{
    IBOutlet UIWindow *window;
    IBOutlet MainViewController *statusViewController;
    AVAudioPlayer *_player;
    
    NSMutableArray *_proxyServers;
    BOOL _serverRunning;
    BOOL _hasNetwork;
    BOOL _hasWifi;
    SCNetworkReachabilityRef _defaultRouteReachability;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) MainViewController *statusViewController;
@property (nonatomic, assign) BOOL hasNetwork;
@property (nonatomic, assign) BOOL hasWifi;

@end