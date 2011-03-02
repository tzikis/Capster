//
//  Growl_Caps_NotifierAppDelegate.h
//  Growl Caps Notifier
//
//  Created by Vasileios Georgitzikis on 3/3/11.
//  Copyright 2011 Tzikis. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Growl_Caps_NotifierAppDelegate : NSObject <NSApplicationDelegate> {
@private
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
