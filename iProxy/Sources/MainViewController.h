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
#import <MessageUI/MFMailComposeViewController.h>

@interface MainViewController : UIViewController <UIActionSheetDelegate, MFMailComposeViewControllerDelegate, NSNetServiceDelegate> {

    NSTimer *socksProxyInfoTimer;
    NSTimer *labelTimer;
	
	NSString *emailBody;
	NSString *emailURL;
    
    BOOL _applicationActive;
    BOOL _windowVisible;
    BOOL _viewVisible;
    NSTimer *_updateTransferTimer;
}

- (IBAction) switchedHttp:(id)sender;
- (IBAction) switchedSocks:(id)sender;
- (IBAction) httpURLAction:(id)sender;
- (IBAction) socksURLAction:(id)sender;
- (IBAction) showInfo;
- (IBAction) resetTransfer:(id)sender;

@property (nonatomic, strong) IBOutlet UISwitch *httpSwitch;
@property (nonatomic, strong) IBOutlet UILabel *httpAddressLabel;
@property (nonatomic, strong) IBOutlet UILabel *httpPacLabel;
@property (nonatomic, strong) IBOutlet UIButton *httpPacButton;
@property (nonatomic, strong) IBOutlet UILabel *proxyEventCountLabel;

@property (nonatomic, strong) IBOutlet UISwitch *socksSwitch;
@property (nonatomic, strong) IBOutlet UILabel *socksAddressLabel;
@property (nonatomic, strong) IBOutlet UILabel *socksPacLabel;
@property (nonatomic, strong) IBOutlet UIButton *socksPacButton;
@property (nonatomic, strong) IBOutlet UILabel *socksIPCountLabel;
@property (nonatomic, strong) IBOutlet UILabel *socksConnectionCountLabel;

@property (nonatomic, strong) IBOutlet UILabel *_bandwidthUpload;
@property (nonatomic, strong) IBOutlet UILabel *_bandwidthDownload;
@property (nonatomic, strong) IBOutlet UILabel *_totalUpload;
@property (nonatomic, strong) IBOutlet UILabel *_totalDownload;

@property (nonatomic, strong) IBOutlet UIView *connectView;
@property (nonatomic, strong) IBOutlet UIView *runningView;

@end

