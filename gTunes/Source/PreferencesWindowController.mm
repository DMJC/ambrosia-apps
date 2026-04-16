#import "PreferencesWindowController.h"
#import "Preferences.h"
#import "MusicLibrary.h"

@interface PreferencesWindowController ()
- (void)_buildWindow;
- (void)_browse:(id)sender;
- (void)_ok:(id)sender;
- (void)_cancel:(id)sender;
@end

@implementation PreferencesWindowController

+ (PreferencesWindowController *)sharedController
{
    static PreferencesWindowController *ctrl = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ctrl = [[PreferencesWindowController alloc] init]; });
    return ctrl;
}

- (id)init
{
    self = [super initWithWindow:nil];
    if (self) [self _buildWindow];
    return self;
}

- (void)_buildWindow
{
    NSRect frame = NSMakeRect(0, 0, 480, 140);
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask;
    NSWindow *win = [[NSWindow alloc] initWithContentRect:frame
        styleMask:style backing:NSBackingStoreBuffered defer:NO];
    [win setTitle:@"gTunes Preferences"];
    [win center];
    [self setWindow:win];
    [win release];

    NSView *v = [win contentView];

    // ── Label ──
    NSTextField *label = [[[NSTextField alloc] initWithFrame:
        NSMakeRect(20, 96, 160, 18)] autorelease];
    [label setStringValue:@"Music Library Path:"];
    [label setBezeled:NO]; [label setDrawsBackground:NO];
    [label setEditable:NO]; [label setSelectable:NO];
    [v addSubview:label];

    // ── Path field ──
    _pathField = [[NSTextField alloc]
        initWithFrame:NSMakeRect(20, 68, 350, 22)];
    [_pathField setStringValue:
        [[Preferences sharedPreferences] musicLibraryPath]];
    [v addSubview:_pathField];

    // ── Browse button ──
    _browseButton = [[NSButton alloc]
        initWithFrame:NSMakeRect(378, 66, 84, 26)];
    [_browseButton setTitle:@"Browse…"];
    [_browseButton setBezelStyle:NSRoundedBezelStyle];
    [_browseButton setTarget:self];
    [_browseButton setAction:@selector(_browse:)];
    [v addSubview:_browseButton];

    // ── Cancel / OK ──
    _cancelButton = [[NSButton alloc]
        initWithFrame:NSMakeRect(304, 14, 84, 32)];
    [_cancelButton setTitle:@"Cancel"];
    [_cancelButton setBezelStyle:NSRoundedBezelStyle];
    [_cancelButton setTarget:self];
    [_cancelButton setAction:@selector(_cancel:)];
    [v addSubview:_cancelButton];

    _okButton = [[NSButton alloc]
        initWithFrame:NSMakeRect(396, 14, 66, 32)];
    [_okButton setTitle:@"OK"];
    [_okButton setBezelStyle:NSRoundedBezelStyle];
    [_okButton setKeyEquivalent:@"\r"];
    [_okButton setTarget:self];
    [_okButton setAction:@selector(_ok:)];
    [v addSubview:_okButton];
}

- (void)showWindow:(id)sender
{
    // Refresh field with current stored value each time the panel opens.
    [_pathField setStringValue:
        [[Preferences sharedPreferences] musicLibraryPath]];
    [[self window] center];
    [[self window] makeKeyAndOrderFront:sender];
}

- (void)_browse:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setCanChooseFiles:NO];
    [op setCanChooseDirectories:YES];
    [op setAllowsMultipleSelection:NO];
    [op setTitle:@"Choose Music Library Folder"];
    [op setPrompt:@"Choose"];
    if ([op runModal] == NSModalResponseOK) {
        NSString *path = [[[op URLs] firstObject] path];
        if (path) [_pathField setStringValue:path];
    }
}

- (void)_ok:(id)sender
{
    NSString *path = [[_pathField stringValue]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([path length] > 0) {
        [[Preferences sharedPreferences] setMusicLibraryPath:path];
        [[Preferences sharedPreferences] setHasConfiguredLibrary:YES];
        [[MusicLibrary sharedLibrary] scanDirectory:path];
    }
    [[self window] orderOut:nil];
}

- (void)_cancel:(id)sender
{
    [[self window] orderOut:nil];
}

- (void)dealloc
{
    [_pathField    release];
    [_browseButton release];
    [_okButton     release];
    [_cancelButton release];
    [super dealloc];
}

@end
