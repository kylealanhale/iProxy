//
//  PMSUIController.h
//  iProxy
//
//  Created by Jérôme Lebel on 18/09/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PMSAppDelegate;

@interface PMSUIController : NSObject
{
	IBOutlet PMSAppDelegate *appDelegate;
    IBOutlet NSPopUpButton *proxyPopUpButton;
    IBOutlet NSButton *automaticButton;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *startButton;
}

@property(nonatomic, readonly, assign)PMSAppDelegate *appDelegate;

- (void)updateProgressIndicator;
- (void)updateProxyPopUpButton;
- (void)updateStartButton;
- (IBAction)startButtonAction:(id)sender;
- (IBAction)proxyPopUpButtonAction:(id)sender;

@end
