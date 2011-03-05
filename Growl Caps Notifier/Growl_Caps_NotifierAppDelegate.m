//
//  Growl_Caps_NotifierAppDelegate.m
//  Growl Caps Notifier
//
//  Created by Vasileios Georgitzikis on 3/3/11.
//  Copyright 2011 Tzikis. All rights reserved.
//
// This source code is release under the BSD License.

#import "Growl_Caps_NotifierAppDelegate.h"

CGEventRef myCallback (
					   CGEventTapProxy proxy,
					   CGEventType type,
					   CGEventRef event,
					   void *refcon
					   )
{
	char *buffer = (char*) refcon;
	NSUInteger *currentState = (NSUInteger*) buffer;
	NSUInteger oldState = (NSUInteger) *currentState;	

	CGEventFlags flags = CGEventGetFlags (event);
	if ((flags & kCGEventFlagMaskAlphaShift) != 0)
		*currentState = 1;
	else
		*currentState = 0;
	if(oldState == 4) return event;
	
	if(oldState != *currentState)
	{
		NSString* descriptions[] = {@"Caps Lock OFF", @"Caps Lock ON"};
		NSString* names[] = {@"caps off", @"caps on"};
		NSData* data[2];
		
		int offset = sizeof(NSUInteger);
		char* tmpChar;
		
		tmpChar = buffer + offset;
		NSUInteger* tempInt1 = (NSUInteger*) tmpChar;
		NSUInteger len_on = *tempInt1;
		offset +=(int) sizeof(NSUInteger);
		
		tmpChar = buffer + offset;
		NSUInteger* tempInt2 = (NSUInteger*) tmpChar;
		NSUInteger len_off = *tempInt2;
		offset +=(int) sizeof(NSUInteger);
		
//		NSLog(@"len_on: %i len_off %i", len_on, len_off);
		data[1] = [NSData dataWithBytes:(buffer+offset) length:len_on];
		offset += (int) len_on;
		data[0] = [NSData dataWithBytes:(buffer+offset) length:len_off];

		printf("caps %d\n",(int) *currentState);
		[GrowlApplicationBridge notifyWithTitle: @"Capster"
									description: descriptions[*currentState]
							   notificationName: names[*currentState]
									   iconData: data[*currentState]
									   priority: 0
									   isSticky: NO
								   clickContext:nil];
//		if ((flags & kCGEventFlagMaskShift) != 0)
//		{
//			printf("enter setup\n");
//			NSApplication* app = [NSApplication sharedApplication];
//			[self performSelectorOnMainThread:@selector(toggleUI) 
//								  withObject:nil 
//							   waitUntilDone:FALSE];
//			[[NSThread mainThread] performSelector:@selector(toggleUI)];
//		}
	}
	
//		printf("flag changed\n");
	return event;
}

@implementation Growl_Caps_NotifierAppDelegate

//@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self listenForCapsInNewThread];
	[self registerDefaults];
	
	NSString* path_mini = [[NSBundle mainBundle] pathForResource:@"capster_mini" ofType:@"png"];
	mini = [[NSImage alloc] initWithContentsOfFile:path_mini];

	if([preferences boolForKey:@"statusMenu"])
		[self initStatusMenu];

	
	NSString* path_ter = [[NSBundle mainBundle] pathForResource:@"caps_ter" ofType:@"png"];
	NSData* ter = [NSData dataWithContentsOfFile:path_ter];
	
	[GrowlApplicationBridge setGrowlDelegate:self];
	[GrowlApplicationBridge notifyWithTitle: @"Capster"
								description: @"Starting"
						   notificationName: @"starting"
								   iconData: ter
								   priority: 0
								   isSticky: NO
							   clickContext:nil];	
}

-(void) listenForCapsInNewThread
{
	[NSThread detachNewThreadSelector:@selector(listen)
							 toTarget:self
						   withObject:nil];
	
	sleep(2);
	CGEventRef event1 = CGEventCreateKeyboardEvent (NULL,(CGKeyCode)56,true);
	CGEventRef event2 = CGEventCreateKeyboardEvent (NULL,(CGKeyCode)56,false);
	CGEventPost(kCGAnnotatedSessionEventTap, event1);
	CGEventPost(kCGAnnotatedSessionEventTap, event2);

}
-(void) listen
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSString* path_on = [[NSBundle mainBundle] pathForResource:@"caps_on" ofType:@"png"];
	NSString* path_off = [[NSBundle mainBundle] pathForResource:@"caps_off" ofType:@"png"];
	
	NSData* on = [NSData dataWithContentsOfFile:path_on];
	NSData* off = [NSData dataWithContentsOfFile:path_off];
	
	NSUInteger len_on = [on length];
	NSUInteger len_off = [off length];
//	NSLog(@"len_on: %i len_off %i", len_on, len_off);
	
	int size = (int) len_on+ (int) len_off + (3 * (int) sizeof(NSUInteger));
	char *byteData = (char*)malloc(sizeof(char) * size);
	
	int offset = 0;
	char *tmpChar;
	
	NSUInteger currentState = 4;
	byteData[offset] = currentState;
	offset+=(int) sizeof(NSUInteger);
//	printf("offset: %d\n", offset);
	
	NSUInteger* tempInt1 = (NSUInteger*) (byteData + offset);
	*tempInt1 = len_on;
//	NSLog(@"len_on: %i", *tempInt1);
	offset+=(int) sizeof(NSUInteger);
//	printf("offset: %d\n", offset);
	
	tmpChar = byteData + offset;
	NSUInteger* tempInt2 = (NSUInteger*) tmpChar;
	*tempInt2 = len_off;
//	NSLog(@"len_off: %i", *tempInt2);
	offset+=(int) sizeof(NSUInteger);
//	printf("offset: %d\n", offset);
		
	memcpy(byteData+offset, [on bytes], len_on);
	offset+=(int) len_on;
	
	memcpy(byteData+offset, [off bytes], len_off);
//	offset+= len_off;
	
//	NSLog(@"len_on: %i len_off %i", *tempInt1, *tempInt2);
	NSLog(@"size of my object: %lu", sizeof(self));
	
#ifndef __clang_analyzer__
	CFMachPortRef bla = CGEventTapCreate (
										  kCGAnnotatedSessionEventTap,
										  kCGHeadInsertEventTap,
										  kCGEventTapOptionListenOnly,
										  CGEventMaskBit(kCGEventFlagsChanged),
										  myCallback,
										  (void*) byteData
										  );
	assert(bla != NULL);
	

	CFRunLoopSourceRef bla2 = CFMachPortCreateRunLoopSource(NULL, bla, 0);
	assert(bla2 != NULL);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), bla2, kCFRunLoopDefaultMode);
	// Run the run loop.
	
	printf("Listening using Core Foundation:\n");
	CFRunLoopRun();
#endif
	
	[pool release];
	fprintf(stderr, "CFRunLoopRun returned\n");
//    return EXIT_FAILURE;
}


-(void) registerDefaults
{
	preferences = [[NSUserDefaults standardUserDefaults] retain];
	NSString *file = [[NSBundle mainBundle]
					  pathForResource:@"defaults" ofType:@"plist"];
	
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:file];
	[preferences registerDefaults:dict];
}

-(void) toggleUI
{
	
}

-(IBAction) enableStatusMenu:(id)sender
{
	//not used
}
-(IBAction) disableStatusMenu: (id)sender
{
	[preferences setObject:@"NO" forKey:@"statusMenu"];
	[preferences synchronize];
	[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
}

-(void) initStatusMenu
{
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain]; 
	[statusItem setMenu:statusMenu];
	[statusItem setImage:mini];
	[statusItem setHighlightMode:YES];
}
@end
