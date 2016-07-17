
#import "AppDelegate.h"
#import "ISSoundAdditions.h"
#import <CoreAudio/CoreAudio.h>

@interface AppDelegate () {
	NSStatusItem *statusItem;
}

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self setupSystemMenuItem];
	[NSTimer scheduledTimerWithTimeInterval:2.0
									 target:self
								   selector:@selector(updateVolumeIcon)
								   userInfo:nil
									repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	
}

- (void)setupSystemMenuItem {
	BOOL launchedBefore = [[NSUserDefaults standardUserDefaults] boolForKey:@"LaunchedBefore"];
	if (!launchedBefore) {
		[self askForLaunchOnStartup];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"LaunchedBefore"];
	}
	
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	[self updateVolumeIcon];
	[statusItem.button setTarget:self];
	[statusItem.button setAction:@selector(openMenu)];
}

- (void)openMenu {
	NSMenu *menu = [[NSMenu alloc] init];
	[statusItem setMenu:menu];
	
	float vol = [NSSound systemVolume];
	if (vol == -1) {
		NSMenuItem *menuItem = [[NSMenuItem alloc] init];
		menuItem.title = NSLocalizedString(@"ToolTipNotSupported", nil);
		[statusItem.menu addItem:menuItem];
	} else {
		NSRect size = NSMakeRect(0,0,30,104);
		NSSlider *slider = [[NSSlider alloc] initWithFrame:size];
		[slider setTarget:self];
		[slider setAction:@selector(sliderAction:)];
		[slider setMaxValue:1.0];
		[slider setMinValue:0.0];
		[slider setFloatValue:vol];
		[slider setContinuous:YES];
		NSMenuItem *sliderItem = [[NSMenuItem alloc] init];
		[sliderItem setView:slider];
		[statusItem.menu addItem:sliderItem];
	}
	
	[statusItem.button performClick:self];
	statusItem.menu = nil;
}

- (void)sliderAction:(id)sender {
	float vol = [sender floatValue];
	[NSSound setSystemVolume:[sender floatValue]];
	if (vol == 0) { // manually mute when slider hits 0
		[NSSound applyMute:YES];
	}
	[self updateVolumeIcon];
}

- (void)updateVolumeIcon {
	// TODO: test black and white, and dark system menu
	NSImage *image;
	float vol = [NSSound systemVolume];
	if (vol < 0.034) { // muted
		image = [NSImage imageNamed:@"volume_0"];
	} else if ( vol > 0.66) {
		image = [NSImage imageNamed:@"volume_75"];
	} else if ( vol > 0.33) {
		image = [NSImage imageNamed:@"volume_50"];

	} else {
		image = [NSImage imageNamed:@"volume_25"];
	}
	
	[image setTemplate:YES];
	[statusItem.button setImage:image];
}

- (void)askForLaunchOnStartup {
	
	NSString *appPath = [[NSBundle mainBundle] bundlePath];
	if (![self loginItemExistsForPath:appPath]) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString(@"AlertTitel", nil);
		[alert addButtonWithTitle:NSLocalizedString(@"AlertOK", nil)];
		[alert addButtonWithTitle:NSLocalizedString(@"AlertCancel", nil)];
		[alert setInformativeText:NSLocalizedString(@"AlertText", nil)];
		NSModalResponse response = [alert runModal];
		if (response == NSAlertFirstButtonReturn) {
			[self enableLoginItemForPath:appPath];
		}
	}
}

- (BOOL)loginItemExistsForPath:(NSString *)appPath {
	BOOL found = NO;
	UInt32 seedValue;
	CFURLRef thePath;
	
	LSSharedFileListRef theLoginItemsRefs = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	// We're going to grab the contents of the shared file list (LSSharedFileListItemRef objects)
	// and pop it in an array so we can iterate through it to find our item.
	NSArray  *loginItemsArray = (__bridge NSArray *)LSSharedFileListCopySnapshot(theLoginItemsRefs, &seedValue);
	for (id item in loginItemsArray) {
		LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
		if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &thePath, NULL) == noErr) {
			if ([[(__bridge NSURL *)thePath path] hasPrefix:appPath]) {
				found = YES;
				break;
			}
			CFRelease(thePath);
		}
	}
	CFRelease((CFArrayRef)loginItemsArray);
	CFRelease(theLoginItemsRefs);
	
	return found;
}

- (void)disableLoginItem {
	NSString *appPath = [[NSBundle mainBundle] bundlePath];
	[self disableLoginItemForPath:appPath];
}

- (void)disableLoginItemForPath:(NSString *)appPath {
	UInt32 seedValue;
	CFURLRef thePath = NULL;
	LSSharedFileListRef loginItemsRefs = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	
	// We're going to grab the contents of the shared file list (LSSharedFileListItemRef objects)
	// and pop it in an array so we can iterate through it to find our item.
	CFArrayRef loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRefs, &seedValue);
	for (id item in (__bridge NSArray *)loginItemsArray) {
		LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
		if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &thePath, NULL) == noErr) {
			if ([[(__bridge NSURL *)thePath path] hasPrefix:appPath]) {
				LSSharedFileListItemRemove(loginItemsRefs, itemRef); // Deleting the item
			}
			// Docs for LSSharedFileListItemResolve say we're responsible
			// for releasing the CFURLRef that is returned
			if (thePath != NULL) CFRelease(thePath);
		}
	}
	if (loginItemsArray != NULL) CFRelease(loginItemsArray);
}

- (void)enableLoginItem {
	NSString *appPath = [[NSBundle mainBundle] bundlePath];
	[self enableLoginItemForPath:appPath];
}

- (void)enableLoginItemForPath:(NSString *)appPath {
	LSSharedFileListRef theLoginItemsRefs = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	
	// We call LSSharedFileListInsertItemURL to insert the item at the bottom of Login Items list.
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
	LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(theLoginItemsRefs, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
	if (item) {
		CFRelease(item);
	}
	CFRelease(theLoginItemsRefs);
}

- (void)addQuitMenu {
	NSMenu *menu = [[NSMenu alloc] init];
	NSString *appPath = [[NSBundle mainBundle] bundlePath];
	NSMenuItem *menuItem = [[NSMenuItem alloc] init];
	menuItem.title = NSLocalizedString(@"Launch at startup", nil); // Launch at startup
	menuItem.target = self;
	
	if (![self loginItemExistsForPath:appPath]) {
		menuItem.action = @selector(enableLoginItem);
		[menuItem setState:NSOffState];
	} else {
		menuItem.action = @selector(disableLoginItem);
		[menuItem setState:NSOnState];
	}
	[menu addItem:menuItem];
	
	NSMenuItem *quitMenuItem = [[NSMenuItem alloc] init];
	quitMenuItem.title = NSLocalizedString(@"Quit", nil);
	quitMenuItem.target = self;
	quitMenuItem.action = @selector(quit);
	[menu addItem:quitMenuItem];
	
	statusItem.menu = menu;
	[statusItem.button performClick:self];
	statusItem.menu = nil;
}

- (void)quit {
	[NSApp terminate:self];
}

@end

@interface NSStatusBarButton (NSStatusBarButtonQuit)
- (void)rightMouseDown:(NSEvent *)event;
@end

@implementation NSStatusBarButton (NSStatusBarButtonQuit)
- (void)rightMouseDown:(NSEvent *)event {
	[self.target performSelector:@selector(addQuitMenu) withObject:nil];
}

- (void)scrollWheel:(NSEvent *)theEvent {
	[self.target performSelector:@selector(openMenu) withObject:nil];
}

@end


@implementation NSSlider (Scrollwheel)

- (void)scrollWheel:(NSEvent*)event {
	float range = [self maxValue] - [self minValue];
	float increment = (range * [event deltaY]) / 100;
	float val = [self floatValue] + increment;
	
	BOOL wrapValue = ([[self cell] sliderType] == NSCircularSlider);
	
	if (wrapValue) {
		if (val < [self minValue]) {
			val = [self maxValue] - fabs(increment);
		}
		
		if( val > [self maxValue]) {
			val = [self minValue] + fabs(increment);
		}
	}
	
	[self setFloatValue:val];
	[self sendAction:[self action] to:[self target]];
}

@end
