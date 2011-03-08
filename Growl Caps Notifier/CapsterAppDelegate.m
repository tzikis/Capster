//
//  CapsterAppDelegate.m
//  Capster
//
//  Created by Vasileios Georgitzikis on 3/3/11.
//  Copyright 2011 Tzikis. All rights reserved.
//
// This source code is release under the BSD License.

#import "CapsterAppDelegate.h"

//This is the callback function that gets called when the
//caps lock is pressed. All we need to care about is the
//refcon pointer, which is the buffer we use to send
//data to the callback function
CGEventRef myCallback (
					   CGEventTapProxy proxy,
					   CGEventType type,
					   CGEventRef event,
					   void *refcon
					   )
{
	//change the buffer to a char buffer
	char *buffer = (char*) refcon;
	//get the state, and save it for comparison
	NSUInteger *currentState = (NSUInteger*) buffer;
	NSUInteger oldState = (NSUInteger) *currentState;	

	//get the flags
	CGEventFlags flags = CGEventGetFlags (event);
	//is caps lock on or off?
	if ((flags & kCGEventFlagMaskAlphaShift) != 0)
		*currentState = 1;
	else
		*currentState = 0;
	
	//if it's our first event, then do nothing.
	//it's the fake event we're sending to ourselves
	if(oldState == 4) return event;
	
	//if the caps lock state has changed, do some work
	if(oldState != *currentState)
	{
		//prepare the stuff for the growl notification
		NSString* descriptions[] = {@"Caps Lock OFF", @"Caps Lock ON"};
		NSString* names[] = {@"caps off", @"caps on"};
		NSData* data[2];
		
		//if the shortcut var is 0, the preference panel shortcut is cmd-caps
		//if it's 1, then it's shift-caps
		CGEventFlags shortcuts[] = {kCGEventFlagMaskCommand , kCGEventFlagMaskShift};

		//increase the offset, since we've read the first NSUInteger
		int offset = sizeof(NSUInteger);
		char* tmpChar;
		
		//copy the length of the first image
		tmpChar = buffer + offset;
		NSUInteger* tempInt1 = (NSUInteger*) tmpChar;
		NSUInteger len_on = *tempInt1;
		offset +=(int) sizeof(NSUInteger);
		
		//copy the length of the second image
		tmpChar = buffer + offset;
		NSUInteger* tempInt2 = (NSUInteger*) tmpChar;
		NSUInteger len_off = *tempInt2;
		offset +=(int) sizeof(NSUInteger);
		
		//copy the images themselves
//		NSLog(@"len_on: %i len_off %i", len_on, len_off);
		data[1] = [NSData dataWithBytes:(buffer+offset) length:len_on];
		offset += (int) len_on;
		data[0] = [NSData dataWithBytes:(buffer+offset) length:len_off];
		offset += (int) len_off;

		//copy the object we'll be using
		id* tmpID2 = (id*) (buffer+offset);
		id tmpID = *tmpID2;
		offset += (int) sizeof(id*);
		
		//copy the pointer to the shortcut variable too
		NSInteger** tempInt = (NSInteger**) (buffer+offset);
		NSInteger shortcut = **tempInt;

//		printf("caps %d\n",(int) *currentState);
		//send the apropriate growl notification
		[GrowlApplicationBridge notifyWithTitle: @"Capster"
									description: descriptions[*currentState]
							   notificationName: names[*currentState]
									   iconData: data[*currentState]
									   priority: 0
									   isSticky: NO
								   clickContext:nil];
		//check if the user has pressed the key combination we're looking for.
		//if so, toggle the preference panel, on the main thread
		if ((flags & shortcuts[shortcut]) != 0)
		{
//			printf("enter setup\n");
//			NSApplication* app = [NSApplication sharedApplication];
			[tmpID performSelectorOnMainThread:@selector(toggleUI) 
								  withObject:nil 
							   waitUntilDone:FALSE];
//			[[NSThread mainThread] performSelector:@selector(toggleUI)];
		}
	}
	
//		printf("flag changed\n");
	return event;
}

@implementation Growl_Caps_NotifierAppDelegate

@synthesize preferencePanel;

//this function is called on startup
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//register the user's preferences
	[self registerDefaults];
	
	//set the shortcut pointer, so that we now what shortcut to consider
	//valid for showing the preference panel
	shortcut = malloc(sizeof(NSInteger*));	
	*shortcut = [preferences integerForKey:@"shortcut"];

	//this makes a new thread, and makes it block listening for a
	//change of state in the caps lock flag
	[self listenForCapsInNewThread];

	//initialize the mini icon image
	NSString* path_mini = [[NSBundle mainBundle] pathForResource:@"capster_mini" ofType:@"png"];
	mini = [[NSImage alloc] initWithContentsOfFile:path_mini];

	//select the apropriate radio button, based on which shortcut is active
	[shortcutMatrix selectCellAtRow:*shortcut column:0];

	//make everything in the preferences white. necessary for the text to be viewable
	[self makeEverythingWhite];
	
	//if the user want the menu to be shown, then do so
	if([preferences boolForKey:@"statusMenu"])
		[self initStatusMenu];
	else
		[statusCheckbox setState:NSOffState];
	
	//send a notification to the user to let him know we're on
	[self sendStartupGrowlNotification];
}

//This function takes care of listening creating the new thread and setting the listener
-(void) listenForCapsInNewThread
{
	//run the listener to the new thread
	[NSThread detachNewThreadSelector:@selector(listen)
							 toTarget:self
						   withObject:nil];
	
	//because of the way our code behaves, the first event will not be shown.
	//therefore, we wait for 2 seconds to make sure we have started listening,
	//and then we send a fake event, which will be captured and not shown
	sleep(2);
	CGEventRef event1 = CGEventCreateKeyboardEvent (NULL,(CGKeyCode)56,true);
	CGEventRef event2 = CGEventCreateKeyboardEvent (NULL,(CGKeyCode)56,false);
	CGEventPost(kCGAnnotatedSessionEventTap, event1);
	CGEventPost(kCGAnnotatedSessionEventTap, event2);

}

//starts the listener and blocks the current thread, waiting for events
-(void) listen
{
	//the new thread needs to have its own autorelease pool
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	//Initialize the images for capslock on and off
	NSString* path_on = [[NSBundle mainBundle] pathForResource:@"caps_on" ofType:@"png"];
	NSString* path_off = [[NSBundle mainBundle] pathForResource:@"caps_off" ofType:@"png"];
	NSData* on = [NSData dataWithContentsOfFile:path_on];
	NSData* off = [NSData dataWithContentsOfFile:path_off];
	
	//We hold the length of each image because we need to send it to the callback, in order
	//to know its size, and reconstruct the NSData from the buffer
	NSUInteger len_on = [on length];
	NSUInteger len_off = [off length];
//	NSLog(@"len_on: %i len_off %i", len_on, len_off);
	
	//calculate the size of the buffer
	int size = (int) len_on+ (int) len_off +\
	(3 * (int) sizeof(NSUInteger)) + (int) sizeof(id)+\
	(int) sizeof(NSInteger*);
	//allocate the buffer
	char *byteData = (char*)malloc(sizeof(char) * size);
	
	//offset is the offset, tmpChar is a temporary variable
	int offset = 0;
	char *tmpChar;
	
	//The state is 0 if Caps Lock is not pressed, and 1 when pressed. However,
	//we initialize it as 4 because we don't know the state on startup. After
	//the first event, we'll know. Then we copy the state to the buffer
	NSUInteger currentState = 4;
	byteData[offset] = currentState;
	offset+=(int) sizeof(NSUInteger);
//	printf("offset: %d\n", offset);
	
	//We also copy the length of the first image to the buffer
	NSUInteger* tempInt1 = (NSUInteger*) (byteData + offset);
	*tempInt1 = len_on;
//	NSLog(@"len_on: %i", *tempInt1);
	offset+=(int) sizeof(NSUInteger);
//	printf("offset: %d\n", offset);
	
	//And the second one
	tmpChar = byteData + offset;
	NSUInteger* tempInt2 = (NSUInteger*) tmpChar;
	*tempInt2 = len_off;
//	NSLog(@"len_off: %i", *tempInt2);
	offset+=(int) sizeof(NSUInteger);
//	printf("offset: %d\n", offset);
		
	//we then copy the bytes of the first image to the buffer
	memcpy(byteData+offset, [on bytes], len_on);
	offset+=(int) len_on;
	
	//and the second one's too
	memcpy(byteData+offset, [off bytes], len_off);
	offset+=(int) len_off;
	
	//then, we save a pointer to ourselves, since we'll need to call
	//one of our methods to show or hide the preference panel
	id* tmpID2 = (id*) (byteData+offset);
	*tmpID2 = (id) self;
	offset+=(int) sizeof(id*);
	
	//we also send the pointer to the shortcut key's enum
	NSInteger** tempInt = (NSInteger**) (byteData+offset);
	*tempInt = shortcut;
	
//	NSLog(@"len_on: %i len_off %i", *tempInt1, *tempInt2);
	NSLog(@"size of my object: %lu", sizeof(self));
	
	//this produces invalid warnings for the analyzer, so we silence them
#ifndef __clang_analyzer__
	//We create the Event Tap
	CFMachPortRef bla = CGEventTapCreate (
										  kCGAnnotatedSessionEventTap,
										  kCGHeadInsertEventTap,
										  kCGEventTapOptionListenOnly,
										  CGEventMaskBit(kCGEventFlagsChanged),
										  myCallback,
										  (void*) byteData
										  );
	//make sure the event variable isn't NULL
	assert(bla != NULL);
	
	//Create the loop source
	CFRunLoopSourceRef bla2 = CFMachPortCreateRunLoopSource(NULL, bla, 0);
	//again, make sure it's not NULL
	assert(bla2 != NULL);
	//add the loop source to the current loop
	CFRunLoopAddSource(CFRunLoopGetCurrent(), bla2, kCFRunLoopDefaultMode);
	// Run the loop.
//	printf("Listening using Core Foundation:\n");
	CFRunLoopRun();
#endif
	//if we reach this, something has gone wrong
	[pool release];
	fprintf(stderr, "CFRunLoopRun returned\n");
//    return EXIT_FAILURE;
}

//initializes the user preferences, and loads the defaults from the defaults file
-(void) registerDefaults
{
	//Save a reference to the user's preferences
	preferences = [[NSUserDefaults standardUserDefaults] retain];
	//get the default preferences file
	NSString *file = [[NSBundle mainBundle]
					  pathForResource:@"defaults" ofType:@"plist"];
	//make a dictionary of that file
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:file];
	//register the defaults
	[preferences registerDefaults:dict];
}

//makes everything in the preference panel white
-(void) makeEverythingWhite
{
	//get all the cells in the matrix
	NSArray * cells = [shortcutMatrix cells];
	
	//for each cell
	for(int i = 0 ; i < [cells count] ; i ++)
	{
		//create a reference to the cell 
		NSButtonCell* cell = [cells objectAtIndex:i];
		[self setButtonTitleFor:cell
					   toString:[cell title]
					  withColor:[NSColor whiteColor]];
	}
	[self setButtonTitleFor:statusCheckbox
				   toString:[statusCheckbox title]
				  withColor:[NSColor whiteColor]];
}

//Set the button's title using nsattributedtitle, which lets us change the color of a button or cell's text
- (void)setButtonTitleFor:(id)button toString:(NSString*)title withColor:(NSColor*)color 
{
	if([button respondsToSelector:@selector(setAttributedTitle:)] == NO) return;
	
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	[style setAlignment:NSCenterTextAlignment];
	NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
									 color, NSForegroundColorAttributeName, style, NSParagraphStyleAttributeName, nil];
	NSAttributedString *attrString = [[NSAttributedString alloc]
									  initWithString:title attributes:attrsDictionary];
	[button setAttributedTitle:attrString];
	[style release];
	[attrString release];		
}

//toggle the preference panel between visible and invisible
-(void) toggleUI
{
//	NSLog(@"UI Toggled");
	static BOOL isVisible = YES;
	[preferencePanel setIsVisible:isVisible];
	[preferencePanel center];
	isVisible = !isVisible;
}

//set the status menu to the value of the checkbox sender
-(IBAction) setStatusMenuTo:(id) sender
{
	//merely a casting
	sender = (NSButton*) sender;
	//if the checkbox is checked, then run initStatusMenu
	//otherwise run disableStatusMenu
	if([sender state] == NSOnState)
	{
		[self initStatusMenu];
	}
	else
	{
		[self disableStatusMenu:nil];
	}
}

-(IBAction) enableStatusMenu:(id)sender
{
	//not used
}
//update the user's preferences, and remove the item from the status bar
-(IBAction) disableStatusMenu: (id)sender
{
	[preferences setObject:@"NO" forKey:@"statusMenu"];
	[preferences synchronize];
	[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
}

//set the key binding that shows/hides the preference panel
- (IBAction)setKeyBinding:(id)sender
{
	sender =(NSMatrix*) sender;
	if([sender selectedRow] == 0)
	{
//		NSLog(@"first");
	}
	else
	{
//		NSLog(@"second");		
	}
	//update the preferences, and the value of our pointer which shows
	//the selected key binding
	*shortcut= [sender selectedRow];
	[preferences setInteger:[sender selectedRow] forKey:@"shortcut"];
	[preferences synchronize];
}

//update the user's preferences, create a status bar item, and add it to the
//status bar
-(void) initStatusMenu
{
	[preferences setObject:@"YES" forKey:@"statusMenu"];
	[preferences synchronize];
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain]; 
	[statusItem setMenu:statusMenu];
	[statusItem setImage:mini];
	[statusItem setHighlightMode:YES];
}

//let the user know we're live
- (void) sendStartupGrowlNotification
{
	//initialize the image needed for the growl notification
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
@end
