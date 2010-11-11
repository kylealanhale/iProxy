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

#import "MainViewController.h"
#import "InfoViewController.h"
#import "HTTPServer.h"
#import "PacFileResponse.h"
#import "SocksProxyServer.h"
#import "HTTPProxyServer.h"
#import "UIViewAdditions.h"
#import "UIColorAdditions.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <netinet/in.h>
#import <AudioToolbox/AudioToolbox.h>

// defaults keys
#define KEY_SOCKS_ON    @"socks.on"
#define KEY_HTTP_ON     @"http.on"

void reachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	[(MainViewController *)info reachabilityNotificationWithFlags:flags];
}

@interface MainViewController()
- (void)updateHTTPProxy;
- (void)updateSocksProxy;
@end

@implementation MainViewController

@synthesize httpSwitch;
@synthesize httpAddressLabel;
@synthesize httpPacLabel;
@synthesize socksSwitch;
@synthesize socksAddressLabel;
@synthesize socksPacLabel;
@synthesize connectView;
@synthesize runningView;
@synthesize socksConnextionCountLabel;
@synthesize hasNetwork;
@synthesize hasWifi;

#define ReachableDirectWWAN               (1 << 18)

- (void)unsetupReachabilityNotification
{
    if (defaultRouteReachability) {
    	SCNetworkReachabilityUnscheduleFromRunLoop(defaultRouteReachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        SCNetworkReachabilitySetCallback(defaultRouteReachability, NULL, NULL);
        CFRelease(defaultRouteReachability);
        defaultRouteReachability = NULL;
    }
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
    defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
//	defaultRouteReachability = SCNetworkReachabilityCreateWithName(NULL, "169.254.255.255");

	if (defaultRouteReachability
    	&& SCNetworkReachabilitySetCallback(defaultRouteReachability, reachabilityCallback, &context)
        && SCNetworkReachabilityScheduleWithRunLoop(defaultRouteReachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
        result = YES;
    }
    if (!result && defaultRouteReachability) {
    	[self unsetupReachabilityNotification];
    } else if (result) {
		SCNetworkReachabilityFlags flags;

		if (SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags)) {
        	self.hasNetwork = YES;
			[self reachabilityNotificationWithFlags:flags];
		}
    }
    return result;
}

- (void)reachabilityNotificationWithFlags:(SCNetworkReachabilityFlags)flags
{
	BOOL newHasNetwork;
    BOOL newHasWifi;
    
    newHasNetwork = (flags & kSCNetworkFlagsReachable) ? YES : NO;
    newHasWifi = (flags & ReachableDirectWWAN) ? NO : newHasNetwork;
    if (newHasNetwork != hasNetwork) {
		AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
    }
//    NSLog(@"%d %d %d %d", newHasNetwork, newHasWifi, hasNetwork, hasWifi);
//    NSLog(@"%d", flags);
    self.hasNetwork = newHasNetwork;
    self.hasWifi = newHasWifi;
}

- (void) viewWillAppear:(BOOL)animated
{
	NSString *hostName;
	
    [self setupReachabilityNotification];
    httpSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey: KEY_HTTP_ON];
    socksSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey: KEY_SOCKS_ON];

    connectView.backgroundColor = [UIColor clearColor];
    runningView.backgroundColor = [UIColor clearColor];

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = [NSArray arrayWithObjects:
        (id)[[UIColor colorWithRGB:241, 231, 165] CGColor],
        (id)[[UIColor colorWithRGB:208, 180, 35] CGColor],
        nil];
    [self.view.layer insertSublayer:gradient atIndex:0];
    
    hostName = [[NSProcessInfo processInfo] hostName];
    httpAddressLabel.text = [NSString stringWithFormat:@"%@:%d", hostName, [HTTPProxyServer sharedHTTPProxyServer].servicePort];
    httpPacLabel.text = [NSString stringWithFormat:@"http://%@:%d/http.pac", hostName, [HTTPServer sharedHTTPServer].servicePort];

    socksAddressLabel.text = [NSString stringWithFormat:@"%@:%d", hostName, [SocksProxyServer sharedSocksProxyServer].servicePort];
    socksPacLabel.text = [NSString stringWithFormat:@"http://%@:%d/socks.pac", hostName, [HTTPServer sharedHTTPServer].servicePort];
    [self.view addTaggedSubview:runningView];
	
    [[SocksProxyServer sharedSocksProxyServer] addObserver:self forKeyPath:@"connexionCount" options:NSKeyValueObservingOptionNew context:nil];
    [[SocksProxyServer sharedSocksProxyServer] addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
    [[HTTPProxyServer sharedHTTPProxyServer] addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scheduleSocksProxyInfoTimer) name:HTTPProxyServerNewBandwidthStatNotification object:nil];
    [self updateHTTPProxy];
    [self updateSocksProxy];
}

- (void)scheduleSocksProxyInfoTimer
{
    if (!socksProxyInfoTimer) {
        socksProxyInfoTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateSocksProxyInfo) userInfo:nil repeats:NO];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == [SocksProxyServer sharedSocksProxyServer] && [keyPath isEqualToString:@"connexionCount"]) {
    	[self scheduleSocksProxyInfoTimer];
    }
}

static NSDate *date = nil;
- (void)updateSocksProxyInfo
{
	UInt64 upload = 0, download = 0;
    NSDate *now = [NSDate date];
    
    [[SocksProxyServer sharedSocksProxyServer] getBandwidthStatWithUpload:&upload download:&download];
    if (date) {
    	NSTimeInterval lapse;
        
        lapse = [now timeIntervalSinceDate:date];
	    NSLog(@"upload %f download %f", upload / lapse, download / lapse);
    }
    [date release];
    date = [now retain];
    socksConnextionCountLabel.text = [NSString stringWithFormat:@"%d", [SocksProxyServer sharedSocksProxyServer].connexionCount];
    socksProxyInfoTimer = nil;
}

- (void)updateHTTPProxy
{
    if (httpSwitch.on) {
        [[HTTPProxyServer sharedHTTPProxyServer] start];

        httpAddressLabel.alpha = 1.0;
        httpPacLabel.alpha = 1.0;
        httpPacButton.enabled = YES;

    } else {
        [[HTTPProxyServer sharedHTTPProxyServer] stop];

        httpAddressLabel.alpha = 0.1;
        httpPacLabel.alpha = 0.1;
        httpPacButton.enabled = NO;
    }
    if (httpSwitch.on || socksSwitch.on) {
        [[HTTPServer sharedHTTPServer] start];
    } else {
        [[HTTPServer sharedHTTPServer] stop];
    }
}

- (void)updateSocksProxy
{
    if (socksSwitch.on) {
        [[SocksProxyServer sharedSocksProxyServer] start];

        socksAddressLabel.alpha = 1.0;
        socksPacLabel.alpha = 1.0;
        socksPacButton.enabled = YES;

    } else {
        [[SocksProxyServer sharedSocksProxyServer] stop];

        socksAddressLabel.alpha = 0.1;
        socksPacLabel.alpha = 0.1;
        socksPacButton.enabled = NO;
        socksConnextionCountLabel.text = @"";
        [socksProxyInfoTimer invalidate];
        socksProxyInfoTimer = nil;
    }
    if (httpSwitch.on || socksSwitch.on) {
        [[HTTPServer sharedHTTPServer] start];
    } else {
        [[HTTPServer sharedHTTPServer] stop];
    }
}

- (IBAction) switchedHttp:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool: httpSwitch.on forKey: KEY_HTTP_ON];
    [self updateHTTPProxy];
}

- (IBAction) switchedSocks:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool: socksSwitch.on forKey: KEY_SOCKS_ON];
    [self updateSocksProxy];
}

- (IBAction) showInfo
{
    InfoViewController *viewController = [[InfoViewController alloc] init];
    UINavigationController *navigationConroller = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentModalViewController:navigationConroller animated:YES];
    [navigationConroller release];
    [viewController release];
}

#pragma mark socks proxy

- (void) httpURLAction:(id)sender
{
    UIActionSheet *test;
    
    test = [[UIActionSheet alloc] initWithTitle:@"HTTP Pac URL Action" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Send by Email", @"Copy URL", nil];
	[emailBody release];
	emailBody = [[NSString alloc] initWithFormat:@"http pac URL : %@\n", httpPacLabel.text];
	[emailURL release];
	emailURL = [httpPacLabel.text retain];
    [test showInView:self.view];
    [test release];
}

- (void) socksURLAction:(id)sender
{
    UIActionSheet *test;
    
    test = [[UIActionSheet alloc] initWithTitle:@"SOCKS Pac URL Action" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Send by Email", @"Copy URL", nil];
	[emailBody release];
	emailBody = [[NSString alloc] initWithFormat:@"socks pac URL : %@\n", socksPacLabel.text];
	[emailURL release];
	emailURL = [socksPacLabel.text retain];
    [test showInView:self.view];
    [test release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	switch (buttonIndex) {
        case 0:
        	{
                MFMailComposeViewController*	messageController = [[MFMailComposeViewController alloc] init];
                
                if ([messageController respondsToSelector:@selector(setModalPresentationStyle:)])	// XXX not available in 3.1.3
                    messageController.modalPresentationStyle = UIModalPresentationFormSheet;
                    
                messageController.mailComposeDelegate = self;
                [messageController setMessageBody:emailBody isHTML:NO];
                [self presentModalViewController:messageController animated:YES];
                [messageController release];
            }
            break;
        case 1:
        	{
				NSDictionary *items;
                
				items = [NSDictionary dictionaryWithObjectsAndKeys:emailURL, kUTTypePlainText, emailURL, kUTTypeText, emailURL, kUTTypeUTF8PlainText, [NSURL URLWithString:emailURL], kUTTypeURL, nil];
                [UIPasteboard generalPasteboard].items = [NSArray arrayWithObjects:items, nil];
            }
        	break;
        default:
            break;
    }
}


- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error 
{
	[self dismissModalViewControllerAnimated:YES];
}

@end
