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
#if HTTP_PROXY_ENABLED
#import "HTTPProxyServer.h"
#endif
#import "UIViewAdditions.h"
#import "UIColorAdditions.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "UIDevice_Extended.h"
#define OFTEN_UPDATE_PERIOD             0.5
#define NOT_SO_OFTEN_UPDATE_PERIOD      2.0

// defaults keys
#define KEY_SOCKS_ON    @"socks.on"
#define KEY_HTTP_ON     @"http.on"
extern int fdEventNum;
@interface MainViewController()
- (void)updateHTTPProxy;
- (void)updateSocksProxy;
- (void)updateTransfer;
@end

@implementation MainViewController

@synthesize httpSwitch;
@synthesize httpAddressLabel;
@synthesize httpPacLabel;
@synthesize httpPacButton;
@synthesize proxyEventCountLabel;

@synthesize socksSwitch;
@synthesize socksAddressLabel;
@synthesize socksPacLabel;
@synthesize socksPacButton;
@synthesize socksIPCountLabel;
@synthesize socksConnectionCountLabel;

@synthesize _bandwidthUpload;
@synthesize _bandwidthDownload;
@synthesize _totalUpload;
@synthesize _totalDownload;

@synthesize connectView;
@synthesize runningView;

- (void)updateTransfer
{
    double uploadBandwidth;
    double downloadBandwidth;
	UInt64 oldIn = 0;
	UInt64 oldOut = 0;
	
    _updateTransferTimer = nil;
    [[SocksProxyServer sharedServer] getBandwidthStatWithUpload:&uploadBandwidth download:&downloadBandwidth];
    [[SocksProxyServer sharedServer] getTotalBytesWithUpload:&oldOut download:&oldIn];
    [_totalUpload setText:[NSString stringWithFormat:@"%0.2f kB", ((float)oldOut / 1024.0f)]];
    [_totalDownload setText:[NSString stringWithFormat:@"%0.2f kB", ((float)oldIn / 1024.0f)]];
    [_bandwidthUpload setText:[NSString stringWithFormat:@"%0.2f kB/s", (uploadBandwidth / 1024.0f)]];
    [_bandwidthDownload setText:[NSString stringWithFormat:@"%0.2f kB/s", (downloadBandwidth / 1024.0f)]];
    if (_applicationActive && _windowVisible && _viewVisible) {
        if ((uploadBandwidth != 0) || (downloadBandwidth != 0)) {
            _updateTransferTimer = [NSTimer scheduledTimerWithTimeInterval:OFTEN_UPDATE_PERIOD target:self selector:@selector(updateTransfer) userInfo:nil repeats:NO];
        } else {
            _updateTransferTimer = [NSTimer scheduledTimerWithTimeInterval:NOT_SO_OFTEN_UPDATE_PERIOD target:self selector:@selector(updateTransfer) userInfo:nil repeats:NO];	
        }
    }
//    NSLog(@"application: %@ window: %@ view: %@", _applicationActive?@"active":@"not active", _windowVisible?@"visible":@"hidden", _viewVisible?@"visible":@"hidden");
}

- (void)viewDidLoad
{
    _applicationActive = YES;
    _windowVisible = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeVisible:) name:UIWindowDidBecomeVisibleNotification object:self.view.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeHidden:) name:UIWindowDidBecomeHiddenNotification object:self.view.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:[UIApplication sharedApplication]];
}

- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    if (_applicationActive) {
        _applicationActive = NO;
        [_updateTransferTimer invalidate];
        _updateTransferTimer = nil;
    }
//    NSLog(@"%@ application: %@ window: %@ view: %@", NSStringFromSelector(_cmd), _applicationActive?@"active":@"not active", _windowVisible?@"visible":@"hidden", _viewVisible?@"visible":@"hidden");
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (!_applicationActive) {
        _applicationActive = YES;
        if (_windowVisible && _viewVisible && !_updateTransferTimer) {
            [self updateTransfer];
        }
    }
//    NSLog(@"%@ application: %@ window: %@ view: %@", NSStringFromSelector(_cmd), _applicationActive?@"active":@"not active", _windowVisible?@"visible":@"hidden", _viewVisible?@"visible":@"hidden");
}

- (void)windowDidBecomeVisible:(NSNotification *)notification
{
    if (!_windowVisible) {
        _windowVisible = YES;
        if (_applicationActive && _viewVisible && !_updateTransferTimer) {
            [self updateTransfer];
        }
    }
//    NSLog(@"%@ application: %@ window: %@ view: %@", NSStringFromSelector(_cmd), _applicationActive?@"active":@"not active", _windowVisible?@"visible":@"hidden", _viewVisible?@"visible":@"hidden");
}

- (void)windowDidBecomeHidden:(NSNotification *)notification
{
    if (_windowVisible) {
        _windowVisible = NO;
        [_updateTransferTimer invalidate];
        _updateTransferTimer = nil;
    }
//    NSLog(@"%@ application: %@ window: %@ view: %@", NSStringFromSelector(_cmd), _applicationActive?@"active":@"not active", _windowVisible?@"visible":@"hidden", _viewVisible?@"visible":@"hidden");
}

-(void)setLabels
{
	NSString *hostName;
    //hostName = [[NSProcessInfo processInfo] hostName];
    hostName = [UIDevice localWiFiIPAddress];
#if HTTP_PROXY_ENABLED
    httpAddressLabel.text = [NSString stringWithFormat:@"%@:%d", hostName, [[HTTPProxyServer sharedServer] servicePort]];
    httpPacLabel.text = [NSString stringWithFormat:@"http://%@:%d%@", hostName, [HTTPServer sharedHTTPServer].servicePort, [HTTPProxyServer pacFilePath]];
#endif
    
    socksAddressLabel.text = [NSString stringWithFormat:@"%@:%d", hostName, [[SocksProxyServer sharedServer] servicePort]];
    socksPacLabel.text = [NSString stringWithFormat:@"http://%@:%d%@", hostName, [HTTPServer sharedHTTPServer].servicePort, [SocksProxyServer pacFilePath]]; 
    
    proxyEventCountLabel.text = [NSString stringWithFormat:@"%d", fdEventNum];
}
- (void)scheduleLabelTimer
{
    if (!labelTimer) {
        labelTimer = [NSTimer scheduledTimerWithTimeInterval:NOT_SO_OFTEN_UPDATE_PERIOD target:self selector:@selector(setLabels) userInfo:nil repeats:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
	
#if HTTP_PROXY_ENABLED
    httpSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey: KEY_HTTP_ON];
#else
    httpSwitch.on = NO;
#endif
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
    [self setLabels];
    [self scheduleLabelTimer];
    [self.view addTaggedSubview:runningView];
    [[SocksProxyServer sharedServer] addObserver:self forKeyPath:@"connectionCount" options:NSKeyValueObservingOptionNew context:nil];
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scheduleSocksProxyInfoTimer) name:HTTPProxyServerNewBandwidthStatNotification object:nil];
    [self updateHTTPProxy];
    [self updateSocksProxy];
}

- (void)viewDidAppear:(BOOL)animated
{
    _viewVisible = YES;
    if (_applicationActive && _windowVisible && !_updateTransferTimer) {
        [self updateTransfer];
    }
//    NSLog(@"%@ application: %@ window: %@ view: %@", NSStringFromSelector(_cmd), _applicationActive?@"active":@"not active", _windowVisible?@"visible":@"hidden", _viewVisible?@"visible":@"hidden");
}

- (void)viewDidDisappear:(BOOL)animated
{
    _viewVisible = NO;
    [_updateTransferTimer invalidate];
    _updateTransferTimer = nil;
    [socksProxyInfoTimer invalidate];
    socksProxyInfoTimer = nil;
    [labelTimer invalidate];
    labelTimer = nil;

//    NSLog(@"%@ application: %@ window: %@ view: %@", NSStringFromSelector(_cmd), _applicationActive?@"active":@"not active", _windowVisible?@"visible":@"hidden", _viewVisible?@"visible":@"hidden");
}


- (void)scheduleSocksProxyInfoTimer
{
    if (!socksProxyInfoTimer) {
        socksProxyInfoTimer = [NSTimer scheduledTimerWithTimeInterval:OFTEN_UPDATE_PERIOD target:self selector:@selector(updateSocksProxyInfo) userInfo:nil repeats:NO];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == [SocksProxyServer sharedServer] && [keyPath isEqualToString:@"connectionCount"]) {
    	[self scheduleSocksProxyInfoTimer];
    }
}

- (void)updateSocksProxyInfo
{
    socksConnectionCountLabel.text = [NSString stringWithFormat:@"%d", [[SocksProxyServer sharedServer] connectionCount]];
    socksIPCountLabel.text = [NSString stringWithFormat:@"%d", [[SocksProxyServer sharedServer] ipCount]];
    socksProxyInfoTimer = nil;
}

- (void)updateHTTPProxy
{
#if HTTP_PROXY_ENABLED
    if (httpSwitch.on) {
        [(GenericServer *)[HTTPProxyServer sharedServer] start];

        httpAddressLabel.alpha = 1.0;
        httpPacLabel.alpha = 1.0;
        httpPacButton.enabled = YES;

    } else {
        [[HTTPProxyServer sharedServer] stop];

        httpAddressLabel.alpha = 0.1;
        httpPacLabel.alpha = 0.1;
        httpPacButton.enabled = NO;
    }
#endif
}

- (void)updateSocksProxy
{
    if (socksSwitch.on) {
        [(GenericServer *)[SocksProxyServer sharedServer] start];

        socksAddressLabel.alpha = 1.0;
        socksPacLabel.alpha = 1.0;
        socksPacButton.enabled = YES;

    } else {
        [[SocksProxyServer sharedServer] stop];

        socksAddressLabel.alpha = 0.1;
        socksPacLabel.alpha = 0.1;
        socksPacButton.enabled = NO;
        socksConnectionCountLabel.text = @"";
        [socksProxyInfoTimer invalidate];
        socksProxyInfoTimer = nil;
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

- (IBAction)resetTransfer:(id)sender
{
    [[SocksProxyServer sharedServer] resetTotalBytes];
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
