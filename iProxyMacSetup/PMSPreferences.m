//
//  PMSPreferences.m
//  iProxy
//
//  Created by Jérôme Lebel on 25/03/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PMSPreferences.h"
#import "PMSAppDelegate.h"

@implementation PMSPreferences

- (id)init
{
    self = [super init];
    if (self) {
        [NSBundle loadNibNamed:@"PMSPreferences" owner:self];
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)_update
{
    [_sshCheckBox setState:[[NSUserDefaults standardUserDefaults] boolForKey:SSH_CONFIG_PREF_KEY]?NSOnState:NSOffState];
}

- (void)awakeFromNib
{
    [self _update];
    [_window makeKeyAndOrderFront:nil];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self autorelease];
}

- (IBAction)cancelAction:(id)sender
{
    [_window close];
}

- (IBAction)okAction:(id)sender
{
    [_window close];
    [[NSUserDefaults standardUserDefaults] setBool:[_sshCheckBox state] == NSOnState forKey:SSH_CONFIG_PREF_KEY];
}

@end
