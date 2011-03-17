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

// urls
#define URL_HELP    @"http://github.com/tcurdt/iProxy/wiki/Configuring-iProxy"
#define URL_ISSUES  @"http://github.com/tcurdt/iProxy/issues"
#define URL_LIKE    @"http://vafer.org/log/iproxy?%@"
#define URL_DONATE  @"https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=tcurdt%40vafer.org&item_name=Thanks%20for%20iProxy&currency_code=EUR&lc=US"

#import "InfoViewController.h"
#import "NSStringAdditions.h"
#import "UIColorAdditions.h"
#import <QuartzCore/QuartzCore.h>

@implementation InfoViewController

- (void) viewDidLoad
{
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = [NSArray arrayWithObjects:
        (id)[[UIColor colorWithRGB:241, 231, 165] CGColor],
        (id)[[UIColor colorWithRGB:208, 180, 35] CGColor],
        nil];
    [self.view.layer insertSublayer:gradient atIndex:0];

    self.title = @"Info";  
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismiss)] autorelease];
}

- (IBAction) actionLike;
{
    NSString *anonymizedUnique = [[[UIDevice currentDevice] uniqueIdentifier] md5];

#if TARGET_IPHONE_SIMULATOR
    NSURL *url = [NSURL URLWithString: [NSString stringWithFormat: @"http://localhost?%@", anonymizedUnique]];
#else
    NSURL *url = [NSURL URLWithString: [NSString stringWithFormat: URL_LIKE, anonymizedUnique]];
#endif

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([(NSHTTPURLResponse*)response statusCode] == 200) {

        [connection release];

        UIAlertView *view = [[UIAlertView alloc] initWithTitle: @"Like It!"
            message: @"Thanks for the feedback!"
            delegate: self cancelButtonTitle: @"OK" otherButtonTitles: nil];
     
        [view show];
        [view release];

        return;
    }

    [self connection:connection didFailWithError:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [connection release];

    UIAlertView *view = [[UIAlertView alloc] initWithTitle: @"Like It!"
        message: @"That somehow did not get through. But thanks for trying!"
        delegate: self cancelButtonTitle: @"OK" otherButtonTitles: nil];
 
    [view show];
    [view release];
}


- (IBAction) actionHelp
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: URL_HELP]];
}

- (IBAction) actionIssues
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: URL_ISSUES]];
}

- (IBAction) actionDonate
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: URL_DONATE]];
}

- (void) dismiss
{
    [self dismissModalViewControllerAnimated:YES];
}

@end
