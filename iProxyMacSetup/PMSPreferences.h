//
//  PMSPreferences.h
//  iProxy
//
//  Created by Jérôme Lebel on 25/03/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface PMSPreferences : NSObject
{
    IBOutlet NSWindow *_window;
    IBOutlet NSButton *_sshCheckBox;
}

- (IBAction)cancelAction:(id)sender;
- (IBAction)okAction:(id)sender;

@end
