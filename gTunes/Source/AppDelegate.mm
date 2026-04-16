#import "AppDelegate.h"
#import "MainWindowController.h"
#import "PreferencesWindowController.h"
#import "MusicLibrary.h"
#import "AudioPlayer.h"
#import "Preferences.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
    // Register defaults (must happen before first use)
    [Preferences sharedPreferences];

    // Initialise singletons early
    [MusicLibrary sharedLibrary];
    [AudioPlayer  sharedPlayer];

    _mainWindowController = [[MainWindowController alloc] init];
    [_mainWindowController showWindow:nil];

    _prefsWindowController = [[PreferencesWindowController sharedController] retain];

    // On first launch, scan ~/Music automatically if the directory exists.
    if (![[Preferences sharedPreferences] hasConfiguredLibrary]) {
        NSString *musicPath =
            [NSHomeDirectory() stringByAppendingPathComponent:@"Music"];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager]
                fileExistsAtPath:musicPath isDirectory:&isDir] && isDir) {
            [[Preferences sharedPreferences] setMusicLibraryPath:musicPath];
            [[Preferences sharedPreferences] setHasConfiguredLibrary:YES];
            [[MusicLibrary sharedLibrary] scanDirectory:musicPath];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)note
{
    [[MusicLibrary sharedLibrary] save];
    [[AudioPlayer  sharedPlayer]  stop];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)s
{
    return YES;
}

// ──────────── About ────────────

- (void)showAboutPanel:(id)sender
{
    NSDictionary *options = @{
        @"ApplicationName"    : @"gTunes",
        @"ApplicationVersion" : @"1.0",
        @"Version"            : @"1.0",
        @"Copyright"          : @"Copyright © 2024 Ambrosia.\nAll rights reserved.",
        @"Credits"            : [[[NSAttributedString alloc]
            initWithString:@"A music player for GNUstep / Debian.\n"
                           @"Built with GStreamer and TagLib."]
            autorelease],
    };
    [NSApp orderFrontStandardAboutPanelWithOptions:options];
}

// ──────────── Preferences ────────────

- (void)openPreferences:(id)sender
{
    [_prefsWindowController showWindow:sender];
}

- (void)dealloc
{
    [_mainWindowController  release];
    [_prefsWindowController release];
    [super dealloc];
}

@end
