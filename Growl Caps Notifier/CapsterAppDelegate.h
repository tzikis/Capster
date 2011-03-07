//
//  CapsterAppDelegate.h
//  Capster
//
//  Created by Vasileios Georgitzikis on 3/3/11.
//  Copyright 2011 Tzikis. All rights reserved.
//
// This source code is release under the BSD License.

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>

#import <Growl/Growl.h>

#include <assert.h>
#include <errno.h>
#include <mach/mach.h>
#include <notify.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

@interface Growl_Caps_NotifierAppDelegate : NSObject <NSApplicationDelegate, GrowlApplicationBridgeDelegate>
{
@private
//	NSWindow *window;
	IBOutlet NSPanel *preferencePanel;
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
	NSImage* mini;
	NSUserDefaults *preferences;
	IBOutlet NSButton *statusCheckbox;
	IBOutlet NSMatrix *shortcutMatrix;
	NSInteger *shortcut;
}

//@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSPanel *preferencePanel;

- (void) registerDefaults;
-(void) makeEverythingWhite;
- (void) listenForCapsInNewThread;
- (void) listen;
- (void) toggleUI;
- (IBAction) setStatusMenuTo:(id) sender;
- (IBAction)enableStatusMenu:(id)sender;
- (IBAction)disableStatusMenu:(id)sender;
- (IBAction)setKeyBinding:(id)sender;
- (void) initStatusMenu;
@end
