// MainWindowController.mm
#import "MainWindowController.h"
#import "MusicLibrary.h"
#import "AudioPlayer.h"
#import "Preferences.h"
#import <GNUstepGUI/GSTheme.h>

@interface StatusBarCell : NSTextFieldCell
@end
@implementation StatusBarCell
- (NSRect)drawingRectForBounds:(NSRect)theRect
{
    NSRect r = [super drawingRectForBounds:theRect];
    CGFloat textH = [[self attributedStringValue] size].height;
    if (textH > 0 && textH < NSHeight(r))
        r.origin.y += floor((NSHeight(r) - textH) / 2.0);
    return r;
}
@end

@interface StatusBarView : NSView
@end
@implementation StatusBarView
- (void)drawRect:(NSRect)r
{
    GSTheme *theme = [GSTheme theme];
    NSColor *c1 = [theme colorNamed:@"statusBarGradient1" state:GSThemeNormalState];
    NSColor *c2 = [theme colorNamed:@"statusBarGradient2" state:GSThemeNormalState];
    if (!c1) c1 = [NSColor colorWithCalibratedWhite:0.88 alpha:1.0];
    if (!c2) c2 = [NSColor colorWithCalibratedWhite:0.78 alpha:1.0];

    CGFloat midY = floor(NSMidY(r));
    NSRect topHalf = NSMakeRect(r.origin.x, midY, NSWidth(r), NSMaxY(r) - midY);
    NSRect botHalf = NSMakeRect(r.origin.x, r.origin.y, NSWidth(r), midY - r.origin.y);

    NSGradient *g1 = [[NSGradient alloc] initWithStartingColor:c1 endingColor:c2];
    [g1 drawInRect:topHalf angle:270];
    [g1 release];

    NSGradient *g2 = [[NSGradient alloc] initWithStartingColor:c2 endingColor:c1];
    [g2 drawInRect:botHalf angle:270];
    [g2 release];
}
@end

// NSTableView subclass: shows the context menu on right-mouse-UP rather than DOWN.
//
// On X11/GNUstep the default behaviour is to show a context menu on button-down
// and fire the item under the cursor on button-up.  Because "Info…" is the first
// menu item it appears right under the cursor, so releasing the right button
// immediately triggers it without the user ever seeing the menu.
//
// Fix: absorb rightMouseDown: (select the row, suppress the default menu-on-press),
// then show the menu explicitly in rightMouseUp: via popUpContextMenu:withEvent:forView:.
// By the time the menu appears the right button is already released, so the user
// can browse items and click freely.
@interface GTunesTableView : NSTableView
@end
@implementation GTunesTableView

- (void)rightMouseDown:(NSEvent *)event
{
    // Select the clicked row (if not already in the selection) so that the menu
    // actions always operate on the intended track(s).
    NSPoint pt = [self convertPoint:[event locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:pt];
    if (row >= 0 && ![[self selectedRowIndexes] containsIndex:(NSUInteger)row])
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
            byExtendingSelection:NO];
    // Do NOT call super — that would trigger GNUstep's menu-on-down behaviour.
}

- (void)rightMouseUp:(NSEvent *)event
{
    // Show the context menu after the button is released so it behaves like a
    // normal click-to-open menu rather than a press-and-hold X11 popup.
    NSMenu *menu = [self menu];
    if (menu)
        [NSMenu popUpContextMenu:menu withEvent:event forView:self];
    else
        [super rightMouseUp:event];
}

// Return nil so nothing tries to show a menu during rightMouseDown:.
- (NSMenu *)menuForEvent:(NSEvent *)event { return nil; }

@end

// Tiny helper: stops the current modal session with a specific return code.
// Used by the "New Playlist" dialog buttons since they can't call stopModalWithCode:
// themselves (NSApp is the target, not a window controller method).
@interface GTunesModalHelper : NSObject
@end
@implementation GTunesModalHelper
- (void)okAction:(id)sender     { [NSApp stopModalWithCode:NSAlertFirstButtonReturn]; }
- (void)cancelAction:(id)sender { [NSApp stopModalWithCode:NSAlertSecondButtonReturn]; }
@end

@interface MainWindowController ()
- (void)_buildMenu;
- (void)_buildWindow;
- (void)_buildNowPlayingBar;
- (void)_buildSidebar;
- (void)_buildBrowser;
- (void)_layoutBrowserColumns;
- (void)_buildTrackList;
- (void)_buildStatusBar;
- (void)_reloadTrackListForSection:(NSString *)section
                             genre:(NSString *)genre
                            artist:(NSString *)artist
                             album:(NSString *)album;
- (void)_addMusicFolder:(id)sender;
- (void)_rescanDefaultLibrary:(id)sender;
- (void)_clickTrack:(id)sender;
- (void)_doubleClickTrack:(id)sender;
- (void)_libraryChanged:(NSNotification *)note;
- (void)_trackChanged:(NSNotification *)note;
- (void)_updateStatusBar;
// Controls
- (void)toggleShuffle:(id)sender;
- (void)_toggleShuffle:(id)sender;
- (void)toggleRepeat:(id)sender;
- (void)_cycleRepeat:(id)sender;
- (void)_volumeUp:(id)sender;
- (void)_volumeDown:(id)sender;
// View
- (void)_toggleSidebar:(id)sender;
- (void)_toggleBrowser:(id)sender;
// Advanced
- (void)_clearLibraryCache:(id)sender;
- (void)_importPlaylist:(id)sender;
- (void)_exportPlaylist:(id)sender;
// Help
- (void)_showHelp:(id)sender;
// Context menu
- (void)_buildTrackContextMenu;
- (NSArray *)_selectedTracks;
- (void)_trackInfoAction:(id)sender;
- (void)_loveAction:(id)sender;
- (void)_dislikeAction:(id)sender;
- (void)_addToPlaylistAction:(id)sender;
- (void)_newPlaylistFromSelectionAction:(id)sender;
- (void)_removeFromPlaylistAction:(id)sender;
- (void)_deleteFromLibraryAction:(id)sender;
@end

@implementation MainWindowController

- (id)init
{
    self = [super initWithWindow:nil];
    if (self) {
        [self _buildMenu];
        [self _buildWindow];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(_libraryChanged:)
            name:MusicLibraryDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(_trackChanged:)
            name:AudioPlayerTrackChangedNotification object:nil];
        _currentSection = [@"Music" retain];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_currentSection release];
    [_infoWindowCtrl release];
    [_sidebarArtView release]; [_sidebarContainer release];
    [_sidebarCtrl  release]; [_browserCtrl release]; [_trackCtrl release];
    [super dealloc];
}

// ──────────── Menu ────────────

- (void)_buildMenu
{
    NSMenu *menuBar = [[[NSMenu alloc] initWithTitle:@"gTunes"] autorelease];
    // ── gTunes items (live directly in the main menu on GNUstep) ──
    {
        NSMenuItem *about = [menuBar addItemWithTitle:@"About gTunes"
            action:@selector(showAboutPanel:) keyEquivalent:@""];
        [about setTarget:[NSApp delegate]];

        [menuBar addItem:[NSMenuItem separatorItem]];

        NSMenuItem *prefs = [menuBar addItemWithTitle:@"Preferences\u2026"
            action:@selector(openPreferences:) keyEquivalent:@","];
        [prefs setTarget:[NSApp delegate]];

        [menuBar addItem:[NSMenuItem separatorItem]];

        NSMenuItem *quit = [menuBar addItemWithTitle:@"Quit gTunes"
            action:@selector(terminate:) keyEquivalent:@"q"];
        [quit setTarget:NSApp];

        [menuBar addItem:[NSMenuItem separatorItem]];
    }

    // ── File ──
    NSMenuItem *fileItem = [menuBar addItemWithTitle:@"File"
        action:nil keyEquivalent:@""];
    NSMenu *fileMenu = [[[NSMenu alloc] initWithTitle:@"File"] autorelease];
    {
        NSMenuItem *add = [fileMenu addItemWithTitle:@"Add Folder to Library\u2026"
            action:@selector(_addMusicFolder:) keyEquivalent:@"o"];
        [add setTarget:self];

        [fileMenu addItem:[NSMenuItem separatorItem]];

        NSMenuItem *rescan = [fileMenu addItemWithTitle:@"Rescan Music Library"
            action:@selector(_rescanDefaultLibrary:) keyEquivalent:@"r"];
        [rescan setTarget:self];

        [fileMenu addItem:[NSMenuItem separatorItem]];

        NSMenuItem *close = [fileMenu addItemWithTitle:@"Close Window"
            action:@selector(performClose:) keyEquivalent:@"w"];
        [close setTarget:nil];   // first-responder chain reaches the window
    }
    [fileItem setSubmenu:fileMenu];

    // ── Edit ──
    NSMenuItem *editItem = [menuBar addItemWithTitle:@"Edit"
        action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[[NSMenu alloc] initWithTitle:@"Edit"] autorelease];
    {
        [editMenu addItemWithTitle:@"Cut"   action:@selector(cut:)   keyEquivalent:@"x"];
        [editMenu addItemWithTitle:@"Copy"  action:@selector(copy:)  keyEquivalent:@"c"];
        [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
        [editMenu addItem:[NSMenuItem separatorItem]];
        [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    }
    [editItem setSubmenu:editMenu];

    // ── Controls ──
    NSMenuItem *ctrlItem = [menuBar addItemWithTitle:@"Controls"
        action:nil keyEquivalent:@""];
    NSMenu *ctrlMenu = [[[NSMenu alloc] initWithTitle:@"Controls"] autorelease];
    {
        NSMenuItem *pp = [ctrlMenu addItemWithTitle:@"Play/Pause"
            action:@selector(_togglePlay:) keyEquivalent:@" "];
        [pp setTarget:self];

        NSMenuItem *nxt = [ctrlMenu addItemWithTitle:@"Next"
            action:@selector(_next:) keyEquivalent:@"]"];
        [nxt setTarget:self];

        NSMenuItem *prv = [ctrlMenu addItemWithTitle:@"Previous"
            action:@selector(_previous:) keyEquivalent:@"["];
        [prv setTarget:self];

        [ctrlMenu addItem:[NSMenuItem separatorItem]];

        NSMenuItem *shuf = [ctrlMenu addItemWithTitle:@"Shuffle"
            action:@selector(_toggleShuffle:) keyEquivalent:@"s"];
        [shuf setTarget:self];

        NSMenuItem *rep = [ctrlMenu addItemWithTitle:@"Repeat"
            action:@selector(_cycleRepeat:) keyEquivalent:@"l"];
        [rep setTarget:self];

        [ctrlMenu addItem:[NSMenuItem separatorItem]];

        NSMenuItem *volUp = [ctrlMenu addItemWithTitle:@"Volume Up"
            action:@selector(_volumeUp:) keyEquivalent:@""];
        [volUp setTarget:self];

        NSMenuItem *volDn = [ctrlMenu addItemWithTitle:@"Volume Down"
            action:@selector(_volumeDown:) keyEquivalent:@""];
        [volDn setTarget:self];
    }
    [ctrlItem setSubmenu:ctrlMenu];

    // ── View ──
    NSMenuItem *viewItem = [menuBar addItemWithTitle:@"View"
        action:nil keyEquivalent:@""];
    NSMenu *viewMenu = [[[NSMenu alloc] initWithTitle:@"View"] autorelease];
    {
        NSMenuItem *sidebar = [viewMenu addItemWithTitle:@"Show/Hide Sidebar"
            action:@selector(_toggleSidebar:) keyEquivalent:@"\\"];
        [sidebar setTarget:self];

        NSMenuItem *browser = [viewMenu addItemWithTitle:@"Show/Hide Browser"
            action:@selector(_toggleBrowser:) keyEquivalent:@"b"];
        [browser setTarget:self];
    }
    [viewItem setSubmenu:viewMenu];

    // ── Advanced ──
    NSMenuItem *advItem = [menuBar addItemWithTitle:@"Advanced"
        action:nil keyEquivalent:@""];
    NSMenu *advMenu = [[[NSMenu alloc] initWithTitle:@"Advanced"] autorelease];
    {
        NSMenuItem *clearLib = [advMenu addItemWithTitle:@"Clear Library Cache"
            action:@selector(_clearLibraryCache:) keyEquivalent:@""];
        [clearLib setTarget:self];

        [advMenu addItem:[NSMenuItem separatorItem]];

        NSMenuItem *importPL = [advMenu addItemWithTitle:@"Import Playlist\u2026"
            action:@selector(_importPlaylist:) keyEquivalent:@""];
        [importPL setTarget:self];

        NSMenuItem *exportPL = [advMenu addItemWithTitle:@"Export Playlist\u2026"
            action:@selector(_exportPlaylist:) keyEquivalent:@""];
        [exportPL setTarget:self];
    }
    [advItem setSubmenu:advMenu];

    // ── Window ──
    NSMenuItem *winItem = [menuBar addItemWithTitle:@"Window"
        action:nil keyEquivalent:@""];
    NSMenu *winMenu = [[[NSMenu alloc] initWithTitle:@"Window"] autorelease];
    {
        NSMenuItem *mini = [winMenu addItemWithTitle:@"Minimize"
            action:@selector(performMiniaturize:) keyEquivalent:@"m"];
        [mini setTarget:nil];

        NSMenuItem *zoom = [winMenu addItemWithTitle:@"Zoom"
            action:@selector(performZoom:) keyEquivalent:@""];
        [zoom setTarget:nil];

        [winMenu addItem:[NSMenuItem separatorItem]];

        NSMenuItem *front = [winMenu addItemWithTitle:@"Bring All to Front"
            action:@selector(arrangeInFront:) keyEquivalent:@""];
        [front setTarget:NSApp];
    }
    [winItem setSubmenu:winMenu];
    [NSApp setWindowsMenu:winMenu];

    // ── Help ──
    NSMenuItem *helpItem = [menuBar addItemWithTitle:@"Help"
        action:nil keyEquivalent:@""];
    NSMenu *helpMenu = [[[NSMenu alloc] initWithTitle:@"Help"] autorelease];
    {
        NSMenuItem *helpDoc = [helpMenu addItemWithTitle:@"gTunes Help"
            action:@selector(_showHelp:) keyEquivalent:@"?"];
        [helpDoc setTarget:self];
    }
    [helpItem setSubmenu:helpMenu];

    [NSApp setMainMenu:menuBar];
}

// ──────────── Window ────────────

- (void)_buildWindow
{
    NSRect frame = NSMakeRect(100, 100, 1100, 700);
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask
                     | NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSWindow *win = [[NSWindow alloc] initWithContentRect:frame
        styleMask:style backing:NSBackingStoreBuffered defer:NO];
    [win setTitle:@"gTunes"];
    [win setMinSize:NSMakeSize(800, 500)];
    [self setWindow:win];
    [win release];

    NSView *content = [win contentView];

    // Use the actual content bounds for all layout so that any CSD title bar
    // drawn inside the backing store does not clip subviews placed at the top.
    CGFloat cw = [content bounds].size.width;
    CGFloat ch = [content bounds].size.height;

    // ── Now Playing Bar (top, fixed 60px) ──
    [self _buildNowPlayingBar];
    NSRect barRect = NSMakeRect(0, ch - 60, cw, 60);
    [_nowPlayingBar setFrame:barRect];
    [_nowPlayingBar setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [content addSubview:_nowPlayingBar];

    // ── Search field (top right, beside toolbar) ──
    _searchField = [[NSSearchField alloc]
        initWithFrame:NSMakeRect(cw - 170, ch - 54, 160, 24)];
    [_searchField setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    [[_searchField cell] setPlaceholderString:@"Search"];
    [_searchField setContinuous:YES];
    [_searchField setTarget:self]; [_searchField setAction:@selector(_search:)];
    [_searchField setDelegate:(id)self];
    [content addSubview:_searchField];

    // ── Status bar (bottom, 20px) ──
    [self _buildStatusBar];
    NSRect sbRect = NSMakeRect(0, 0, cw, 34);
    [_statusBar setFrame:sbRect];
    [_statusBar setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    [_statusLabel setFrame:[_statusBar bounds]];
    
    CGFloat bW = 36.0, bH = 24.0, gap = 0.0;
    // New Playlist button (leftmost)
    _newPlaylistBtn = [[NSButton alloc] initWithFrame:
    NSMakeRect(3, 3, bW, bH)];
    [_newPlaylistBtn setButtonType:NSMomentaryPushInButton];
    [_newPlaylistBtn setBordered:YES];
    [_newPlaylistBtn setTitle:@"+"];
//    [_newPlaylistBtn setImage:[NSImage imageNamed:@"new-playlist"]];
    [_newPlaylistBtn setTarget:self];
    [_newPlaylistBtn setAction:@selector(newPlaylist:)];
    [_newPlaylistBtn setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
    [_statusBar addSubview:_newPlaylistBtn];

    // Shuffle button
    _shuffleBtn = [[NSButton alloc] initWithFrame:
    NSMakeRect(3 + bW + gap, 3, bW, bH)];
    [_shuffleBtn setButtonType:NSPushOnPushOffButton]; // toggleable
    [_shuffleBtn setBordered:YES];
    [_shuffleBtn    setTitle:@"⇄"];
//    [_shuffleBtn setImage:[NSImage imageNamed:@"shuffle"]];
    [_shuffleBtn setTarget:self];
    [_shuffleBtn setAction:@selector(toggleShuffle:)];
    [_shuffleBtn setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
    [_statusBar addSubview:_shuffleBtn];

    // Repeat button
    _repeatBtn = [[NSButton alloc] initWithFrame:
    NSMakeRect(3 + (bW + gap) * 2, 3, bW, bH)];
    [_repeatBtn setButtonType:NSPushOnPushOffButton]; // toggleable
    [_repeatBtn setBordered:YES];
    [_repeatBtn     setTitle:@"↺"];
//    [_repeatBtn setImage:[NSImage imageNamed:@"repeat"]];
    [_repeatBtn setTarget:self];
    [_repeatBtn setAction:@selector(toggleRepeat:)];
    [_repeatBtn setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
    [_statusBar addSubview:_repeatBtn];

    // Restore persisted shuffle/repeat state
    {
        Preferences *prefs = [Preferences sharedPreferences];
        AudioPlayer *p = [AudioPlayer sharedPlayer];
        p.shuffle = prefs.shuffle;
        [_shuffleBtn setState:prefs.shuffle ? NSOnState : NSOffState];
        p.repeatMode = prefs.repeat ? RepeatModeAll : RepeatModeNone;
        [_repeatBtn setState:prefs.repeat ? NSOnState : NSOffState];
    }

    [content addSubview:_statusBar];

    // ── Main horizontal split: sidebar (200px) | content ──
    CGFloat splitTop = ch - 62;
    CGFloat splitH   = splitTop - 24;
    _mainSplit = [[NSSplitView alloc]
        initWithFrame:NSMakeRect(0, 24, cw, splitH)];
    [_mainSplit setDividerStyle:NSSplitViewDividerStyleThin];
    [_mainSplit setVertical:YES];
    [_mainSplit setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    // Sidebar
    [self _buildSidebar];
    static const CGFloat kArtH = 180.0;
    NSRect sideRect = NSMakeRect(0, 0, 180, splitH);
    [_sidebarContainer setFrame:sideRect];
    [_sidebarArtView   setFrame:NSMakeRect(0, 0, 180, kArtH)];
    [_sidebarScroll    setFrame:NSMakeRect(0, kArtH, 180, splitH - kArtH)];
    [_mainSplit addSubview:_sidebarContainer];

    // Content split (vertical: browser 150px | track list)
    _contentSplit = [[NSSplitView alloc]
        initWithFrame:NSMakeRect(0, 0, cw - 182, splitH)];
    [_contentSplit setDividerStyle:NSSplitViewDividerStyleThin];
    [_contentSplit setVertical:NO]; // horizontal split: browser top, tracks below
    [_contentSplit setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_contentSplit setDelegate:self];

    // Browser
    [self _buildBrowser];
    NSRect browserRect = NSMakeRect(0, splitH - 155, cw - 182, 155);
    [_browserSplit setFrame:browserRect];
    [_contentSplit addSubview:_browserSplit];

    // Track list
    [self _buildTrackList];
    NSRect trackRect = NSMakeRect(0, 0, cw - 182, splitH - 157);
    [_trackScroll setFrame:trackRect];
    [_contentSplit addSubview:_trackScroll];

    [_mainSplit addSubview:_contentSplit];
    [content addSubview:_mainSplit];

    // Set initial split positions
    [_mainSplit setPosition:180 ofDividerAtIndex:0];
    [_mainSplit adjustSubviews];

    // Apply browser/track split after the split views have their final bounds.
    CGFloat contentH = NSHeight([_contentSplit bounds]);
    CGFloat browserH = MIN(155.0, MAX(80.0, contentH * 0.30));
    [_contentSplit setPosition:contentH - browserH ofDividerAtIndex:0];
    [_contentSplit adjustSubviews];

    [self _layoutBrowserColumns];

    // Reload initial data
    [_trackCtrl setTracks:[[MusicLibrary sharedLibrary] allTracks]];
    [self _updateStatusBar];
}

// ──────────── Sub-view builders ────────────

- (void)_buildNowPlayingBar
{
    _nowPlayingBar = [[NowPlayingBar alloc] initWithFrame:NSZeroRect];
    [_nowPlayingBar setAutoresizingMask:NSViewWidthSizable];
    [_nowPlayingBar setDelegate:self];
}

- (void)_buildStatusBar
{
    _statusBar = [[StatusBarView alloc] initWithFrame:NSZeroRect];

    _statusLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    StatusBarCell *cell = [[StatusBarCell alloc] initTextCell:@""];
    [_statusLabel setCell:cell];
    [cell release];
    [_statusLabel setBezeled:NO];
    [_statusLabel setDrawsBackground:NO];
    [_statusLabel setEditable:NO]; [_statusLabel setSelectable:NO];
    [_statusLabel setAlignment:NSTextAlignmentCenter];
    [_statusLabel setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[_statusLabel cell] setFont:[NSFont boldSystemFontOfSize:11]];
    [_statusLabel setStringValue:@"0 songs"];
    [_statusBar addSubview:_statusLabel];
    [_statusLabel release];
}

- (void)_buildSidebar
{
    static const CGFloat kArtH = 180.0;

    _sidebarContainer = [[NSView alloc] initWithFrame:NSZeroRect];
    [_sidebarContainer setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];

    // Album art panel at the bottom
    _sidebarArtView = [[NSImageView alloc]
        initWithFrame:NSMakeRect(0, 0, 180, kArtH)];
    [_sidebarArtView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [_sidebarArtView setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    [_sidebarContainer addSubview:_sidebarArtView];

    // Outline scroll view fills the space above the art panel
    _sidebarScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_sidebarScroll setBorderType:NSNoBorder];
    [_sidebarScroll setHasVerticalScroller:YES];
    [_sidebarScroll setAutohidesScrollers:YES];
    [_sidebarScroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_sidebarContainer addSubview:_sidebarScroll];

    _sidebarOutline = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"item"];
    [col setWidth:160];
    [_sidebarOutline addTableColumn:col]; [col release];
    [_sidebarScroll setDocumentView:_sidebarOutline];

    _sidebarCtrl = [[LibrarySidebarController alloc] init];
    _sidebarCtrl.delegate = self;
    [_sidebarCtrl setOutlineView:_sidebarOutline];
}

- (NSTableView *)_makeColumnTableWithIdentifiers:(NSArray *)idents
                                          titles:(NSArray *)titles
{
    NSTableView *tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 200, 32000)];
    [tv setHeaderView:[[NSTableHeaderView alloc] initWithFrame:NSZeroRect]];
    for (NSUInteger i = 0; i < [idents count]; i++) {
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:idents[i]];
        [[col headerCell] setStringValue:titles[i]];
        [col setMinWidth:60];
        [col setWidth:100];
        [col setResizingMask:NSTableColumnAutoresizingMask];
        [tv addTableColumn:col]; [col release];
    }
    [tv setUsesAlternatingRowBackgroundColors:YES];
    [tv setRowHeight:17];
    [tv setDrawsGrid:NO];
    // LastColumnOnly: the single column fills available width as the table resizes.
    // Uniform style caused a resize→column-resize→notification→resize loop in GNUstep.
    [tv setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
    [tv setAutoresizingMask:NSViewWidthSizable];
    return [tv autorelease];
}

- (void)_buildBrowser
{
    // Three-column browser (Genre | Artist | Album)
    _browserSplit = [[NSView alloc] initWithFrame:NSZeroRect];
    [_browserSplit setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    _genreTable  = [self _makeColumnTableWithIdentifiers:@[@"genre"]
                                                  titles:@[@"Genres"]];
    _artistTable = [self _makeColumnTableWithIdentifiers:@[@"artist"]
                                                  titles:@[@"Artists"]];
    _albumTable  = [self _makeColumnTableWithIdentifiers:@[@"album"]
                                                  titles:@[@"Albums"]];

    _genreScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_genreScroll setBorderType:NSBezelBorder];
    [_genreScroll setHasVerticalScroller:YES];
    [_genreScroll setAutohidesScrollers:YES];
    [[_genreScroll contentView] setAutoresizesSubviews:YES];
    [_genreScroll setDocumentView:_genreTable];

    _artistScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_artistScroll setBorderType:NSBezelBorder];
    [_artistScroll setHasVerticalScroller:YES];
    [_artistScroll setAutohidesScrollers:YES];
    [[_artistScroll contentView] setAutoresizesSubviews:YES];
    [_artistScroll setDocumentView:_artistTable];

    _albumScroll  = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_albumScroll setBorderType:NSBezelBorder];
    [_albumScroll setHasVerticalScroller:YES];
    [_albumScroll setAutohidesScrollers:YES];
    [[_albumScroll contentView] setAutoresizesSubviews:YES];
    [_albumScroll setDocumentView:_albumTable];

    [_browserSplit addSubview:_genreScroll];
    [_browserSplit addSubview:_artistScroll];
    [_browserSplit addSubview:_albumScroll];

    _browserCtrl = [[BrowserController alloc] init];
    _browserCtrl.delegate = self;
    [_browserCtrl setGenreTable:_genreTable
                    artistTable:_artistTable
                     albumTable:_albumTable];
}

- (void)_layoutBrowserColumns
{
    NSRect b = [_browserSplit bounds];
    if (NSWidth(b) <= 0 || NSHeight(b) <= 0) return;

    CGFloat divider = 1.0;
    CGFloat colW = (NSWidth(b) - 2.0 * divider) / 3.0;
    CGFloat h = NSHeight(b);

    // Only move the scroll views — table view widths and column widths are
    // handled automatically by NSViewWidthSizable + NSTableViewLastColumnOnlyAutoresizingStyle.
    // Manually setting table/column widths here fired NSViewFrameDidChangeNotification
    // which GNUstep's NSSplitView observes on its subviews, causing adjustSubviews to
    // re-enter and post NSSplitViewDidResizeSubviewsNotification again — infinite loop.
    [_genreScroll  setFrame:NSMakeRect(0, 0, colW, h)];
    [_artistScroll setFrame:NSMakeRect(colW + divider, 0, colW, h)];
    [_albumScroll  setFrame:NSMakeRect((colW + divider) * 2.0, 0,
                                      NSWidth(b) - (colW + divider) * 2.0, h)];
}

- (void)_buildTrackList
{
    _trackScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_trackScroll setBorderType:NSNoBorder];
    [_trackScroll setHasVerticalScroller:YES];
    [_trackScroll setHasHorizontalScroller:NO];
    [_trackScroll setAutohidesScrollers:YES];
    [[_trackScroll contentView] setAutoresizesSubviews:YES];

    NSArray *colIds = @[@"name",  @"time",  @"artist", @"album",
                        @"genre", @"rating",@"playCount", @"lastPlayed"];
    NSArray *colTtl = @[@"Name",  @"Time",  @"Artist", @"Album",
                        @"Genre", @"Rating",@"Play Count",@"Last Played"];
    CGFloat colW[]  = {220,  50,  120,  130,  80,  72,  72,  130};
    // YES = expands with the window; NO = fixed width
    BOOL    expand[]= { YES, NO,  YES,  YES,  NO,  NO,  NO,  NO };

    _trackTable = [[GTunesTableView alloc] initWithFrame:NSZeroRect];
    for (NSUInteger i = 0; i < [colIds count]; i++) {
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:colIds[i]];
        [[col headerCell] setStringValue:colTtl[i]];
        [col setWidth:colW[i]];
        if (expand[i]) {
            [col setMinWidth:40];
            [col setResizingMask:NSTableColumnAutoresizingMask
                                | NSTableColumnUserResizingMask];
        } else {
            [col setMinWidth:colW[i]];
            [col setMaxWidth:colW[i]];
            [col setResizingMask:NSTableColumnNoResizing];
        }
        [_trackTable addTableColumn:col]; [col release];
    }
    [_trackTable setAction:@selector(_clickTrack:)];
    [_trackTable setDoubleAction:@selector(_doubleClickTrack:)];
    [_trackTable setDrawsGrid:NO];
    [_trackTable setAutoresizingMask:NSViewWidthSizable];
    [_trackTable setTarget:self];
    [_trackScroll setDocumentView:_trackTable];

    _trackCtrl = [[TrackListController alloc] init];
    [_trackCtrl setTableView:_trackTable];
    // Uniform style distributes available space equally across expanding columns
    // (those with NSTableColumnAutoresizingMask). Fixed columns are unaffected.
    [_trackTable setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];

    [self _buildTrackContextMenu];
}

// ──────────── Delegates ────────────

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
    if ([notification object] != _contentSplit) return;
    if (_inBrowserLayout) return;   // GNUstep NSSplitView fires this re-entrantly;
                                    // guard to break the notification loop.
    _inBrowserLayout = YES;
    [self _layoutBrowserColumns];
    _inBrowserLayout = NO;
}

- (void)sidebarSelectedSection:(NSString *)section
{
    [_currentSection release]; _currentSection = [section retain];
    [self _reloadTrackListForSection:section genre:nil artist:nil album:nil];
    [_browserCtrl reloadWithTracks:[_trackCtrl tracks]];
}

- (void)sidebarRenamedPlaylist:(NSString *)oldName to:(NSString *)newName
{
    if ([_currentSection isEqualToString:oldName]) {
        [_currentSection release];
        _currentSection = [newName retain];
    }
}

- (void)browserSelectionChangedWithGenre:(NSString *)genre
                                  artist:(NSString *)artist
                                   album:(NSString *)album
{
    [self _reloadTrackListForSection:_currentSection
                               genre:genre artist:artist album:album];
}

// ──────────── Track List Loading ────────────

- (void)_reloadTrackListForSection:(NSString *)section
                             genre:(NSString *)genre
                            artist:(NSString *)artist
                             album:(NSString *)album
{
    MusicLibrary *lib = [MusicLibrary sharedLibrary];
    NSArray *tracks = nil;

    if ([section isEqualToString:@"Music"] || section == nil) {
        tracks = [lib allTracks];
    } else if ([lib isSmartPlaylist:section]) {
        tracks = [lib tracksForPlaylist:section];
    } else if ([lib.playlistNames containsObject:section]) {
        tracks = [lib tracksForPlaylist:section];
    } else {
        tracks = [lib allTracks];
    }

    // Filter by browser selection
    if (genre)  tracks = [tracks filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"genre ==[c] %@", genre]];
    if (artist) tracks = [tracks filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"artist ==[c] %@", artist]];
    if (album)  tracks = [tracks filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"album ==[c] %@", album]];

    [_trackCtrl setTracks:tracks];
    [self _updateStatusBar];
}

// ──────────── Actions ────────────

- (void)_clickTrack:(id)sender
{
    NSInteger row = [_trackTable clickedRow];
    NSInteger col = [_trackTable clickedColumn];
    if (row < 0 || col < 0) return;
    NSString *ident = [[_trackTable tableColumns][col] identifier];
    if (![ident isEqualToString:@"rating"]) return;
    MusicTrack *t = [_trackCtrl trackAtRow:row];
    if (!t) return;
    t.rating = (t.rating >= 5) ? 0 : t.rating + 1;
    [_trackTable reloadData];
    [[MusicLibrary sharedLibrary] save];
}

- (void)_doubleClickTrack:(id)sender
{
    NSInteger row = [_trackTable clickedRow];
    NSInteger col = [_trackTable clickedColumn];
    if (row < 0) return;
    if (col >= 0 && [[[_trackTable tableColumns][col] identifier]
            isEqualToString:@"rating"]) return;
    MusicTrack *t = [_trackCtrl trackAtRow:row];
    if (!t) return;
    // Build queue from visible tracks
    [[AudioPlayer sharedPlayer] playTrack:t
                                withQueue:[_trackCtrl visibleTracks]];
}

- (void)_addMusicFolder:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setCanChooseFiles:NO];
    [op setCanChooseDirectories:YES];
    [op setAllowsMultipleSelection:YES];
    [op setTitle:@"Add Folder to gTunes Library"];
    [op setPrompt:@"Add"];
    if ([op runModal] == NSModalResponseOK) {
        for (NSURL *url in [op URLs])
            [[MusicLibrary sharedLibrary] scanDirectory:[url path]];
    }
}

- (void)_search:(id)sender
{
    [_trackCtrl filterBySearchString:[_searchField stringValue]];
    [self _updateStatusBar];
}

// Fired on every keystroke when setContinuous:YES is not honoured by the backend
- (void)controlTextDidChange:(NSNotification *)note
{
    if ([note object] == _searchField)
        [self _search:_searchField];
}

- (void)_togglePlay:(id)sender
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    if (p.state == AudioPlayerStatePlaying)     [p pause];
    else if (p.state == AudioPlayerStatePaused) [p resume];
    else [self nowPlayingBarPlayRequested:_nowPlayingBar];
}

- (void)nowPlayingBarPlayRequested:(NowPlayingBar *)bar
{
    NSInteger row = [_trackTable selectedRow];
    if (row < 0) return;
    MusicTrack *t = [_trackCtrl trackAtRow:row];
    if (!t) return;
    [[AudioPlayer sharedPlayer] playTrack:t withQueue:[_trackCtrl visibleTracks]];
}
- (void)_next:(id)sender     { [[AudioPlayer sharedPlayer] next]; }
- (void)_previous:(id)sender { [[AudioPlayer sharedPlayer] previous]; }

- (void)_rescanDefaultLibrary:(id)sender
{
    NSString *path = [[Preferences sharedPreferences] musicLibraryPath];
    if (path) [[MusicLibrary sharedLibrary] scanDirectory:path];
}

// ── Controls extras ──

- (void)toggleShuffle:(id)sender
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    p.shuffle = !p.shuffle;
    [[Preferences sharedPreferences] setShuffle:p.shuffle];
    [_shuffleBtn setState:p.shuffle ? NSOnState : NSOffState];
}

- (void)_toggleShuffle:(id)sender { [self toggleShuffle:sender]; }

- (void)toggleRepeat:(id)sender
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    BOOL nowOn = (p.repeatMode == RepeatModeNone);
    p.repeatMode = nowOn ? RepeatModeAll : RepeatModeNone;
    [[Preferences sharedPreferences] setRepeat:nowOn];
    [_repeatBtn setState:nowOn ? NSOnState : NSOffState];
}

- (void)_cycleRepeat:(id)sender { [self toggleRepeat:sender]; }

- (void)_volumeUp:(id)sender
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    p.volume = MIN(1.0f, p.volume + 0.1f);
}

- (void)_volumeDown:(id)sender
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    p.volume = MAX(0.0f, p.volume - 0.1f);
}

// ── View extras ──

- (void)_toggleSidebar:(id)sender
{
    NSView *sidebar = [[_mainSplit subviews] firstObject];
    [sidebar setHidden:![sidebar isHidden]];
    [_mainSplit adjustSubviews];
}

- (void)_toggleBrowser:(id)sender
{
    NSView *browser = [[_contentSplit subviews] firstObject];
    [browser setHidden:![browser isHidden]];
    [_contentSplit adjustSubviews];
}

// ── Advanced ──

- (void)_clearLibraryCache:(id)sender
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:@"Clear Library Cache?"];
    [alert setInformativeText:
        @"This will remove all tracks from the library. "
         "The original files will not be deleted. "
         "You can re-add them via File \u2192 Add Folder to Library."];
    [alert addButtonWithTitle:@"Clear Cache"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        // There is no public bulk-remove API; reload the singleton via save/load cycle.
        NSString *savePath = [[MusicLibrary sharedLibrary]
            performSelector:@selector(_savePath)];
        [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
        // Restart is the safest way to clear in-memory state.
        NSAlert *info = [[[NSAlert alloc] init] autorelease];
        [info setMessageText:@"Library cache cleared."];
        [info setInformativeText:@"Please restart gTunes."];
        [info addButtonWithTitle:@"OK"];
        [info runModal];
    }
}

- (void)_importPlaylist:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setCanChooseFiles:YES];
    [op setCanChooseDirectories:NO];
    [op setAllowsMultipleSelection:NO];
    [op setTitle:@"Import Playlist"];
    [op setPrompt:@"Import"];
    // Stub – full M3U/PLS import would go here
    if ([op runModal] == NSModalResponseOK) {
        NSAlert *stub = [[[NSAlert alloc] init] autorelease];
        [stub setMessageText:@"Playlist Import"];
        [stub setInformativeText:@"Playlist import is not yet implemented."];
        [stub addButtonWithTitle:@"OK"];
        [stub runModal];
    }
}

- (void)_exportPlaylist:(id)sender
{
    NSSavePanel *sp = [NSSavePanel savePanel];
    [sp setTitle:@"Export Playlist"];
    [sp setPrompt:@"Export"];
    // Stub – full M3U export would go here
    if ([sp runModal] == NSModalResponseOK) {
        NSAlert *stub = [[[NSAlert alloc] init] autorelease];
        [stub setMessageText:@"Playlist Export"];
        [stub setInformativeText:@"Playlist export is not yet implemented."];
        [stub addButtonWithTitle:@"OK"];
        [stub runModal];
    }
}

// ── Help ──

- (void)_showHelp:(id)sender
{
    NSAlert *help = [[[NSAlert alloc] init] autorelease];
    [help setMessageText:@"gTunes Help"];
    [help setInformativeText:
        @"gTunes is a music player for GNUstep.\n\n"
         "• Double-click a track to play it.\n"
         "• Use File \u2192 Add Folder to Library to add music.\n"
         "• Use Preferences to change the default music folder.\n"
         "• Space bar toggles Play/Pause."];
    [help addButtonWithTitle:@"OK"];
    [help runModal];
}

- (void)_trackChanged:(NSNotification *)note
{
    MusicTrack *t = [AudioPlayer sharedPlayer].currentTrack;
    [_sidebarArtView setImage:t.albumArt];

    if (t) {
        NSUInteger idx = [[_trackCtrl visibleTracks] indexOfObject:t];
        if (idx != NSNotFound) {
            [_trackTable selectRowIndexes:[NSIndexSet indexSetWithIndex:idx]
                     byExtendingSelection:NO];
            [_trackTable scrollRowToVisible:(NSInteger)idx];
        }
    }
}

- (void)_libraryChanged:(NSNotification *)note
{
    [self _reloadTrackListForSection:_currentSection
                               genre:nil artist:nil album:nil];
    [_browserCtrl reloadWithTracks:[_trackCtrl tracks]];
    [_sidebarCtrl reload];
}

- (void)_updateStatusBar
{
    NSArray *tracks = [_trackCtrl tracks];
    NSUInteger n    = [tracks count];
    NSTimeInterval totalSecs = 0;
    unsigned long long totalBytes = 0;
    for (MusicTrack *t in tracks) {
        totalSecs  += t.duration;
        totalBytes += t.fileSize;
    }
    NSUInteger h = (NSUInteger)(totalSecs / 3600);
    NSUInteger m = (NSUInteger)((totalSecs - h * 3600) / 60);
    double mb = totalBytes / (1024.0 * 1024.0);
    [_statusLabel setStringValue:[NSString stringWithFormat:
        @"%lu songs, %lu.%lu hours, %.1f MB",
        (unsigned long)n, (unsigned long)h, (unsigned long)m, mb]];
}

// ──────────── Context Menu ────────────

- (void)_buildTrackContextMenu
{
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    [menu setDelegate:self];   // menuNeedsUpdate: rebuilds the playlist submenu

    NSMenuItem *info = [menu addItemWithTitle:@"Info…"
        action:@selector(_trackInfoAction:) keyEquivalent:@"i"];
    [info setTarget:self];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *love = [menu addItemWithTitle:@"Love"
        action:@selector(_loveAction:) keyEquivalent:@""];
    [love setTarget:self];

    NSMenuItem *dislike = [menu addItemWithTitle:@"Dislike"
        action:@selector(_dislikeAction:) keyEquivalent:@""];
    [dislike setTarget:self];

    [menu addItem:[NSMenuItem separatorItem]];

    // "Add to Playlist" — submenu is populated just-in-time in menuNeedsUpdate:
    _addToPlaylistItem = [menu addItemWithTitle:@"Add to Playlist"
        action:nil keyEquivalent:@""];
    NSMenu *sub = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    [_addToPlaylistItem setSubmenu:sub];

    NSMenuItem *newPL = [menu addItemWithTitle:@"New Playlist from Selection"
        action:@selector(_newPlaylistFromSelectionAction:) keyEquivalent:@""];
    [newPL setTarget:self];

    _removeFromPlaylistItem = [menu addItemWithTitle:@"Remove from Playlist"
        action:@selector(_removeFromPlaylistAction:) keyEquivalent:@""];
    [_removeFromPlaylistItem setTarget:self];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *del = [menu addItemWithTitle:@"Delete from Library"
        action:@selector(_deleteFromLibraryAction:) keyEquivalent:@""];
    [del setTarget:self];

    [_trackTable setMenu:menu];
}

// ── NSMenuDelegate ──

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if (!_addToPlaylistItem) return;
    NSMenu *sub = [_addToPlaylistItem submenu];
    [sub removeAllItems];
    NSSet *excluded = [NSSet setWithObjects:@"Podcasts", @"Radio", nil];
    NSArray *names = [[MusicLibrary sharedLibrary] playlistNames];
    NSUInteger added = 0;
    for (NSString *name in names) {
        if ([excluded containsObject:name]) continue;
        NSMenuItem *it = [sub addItemWithTitle:name
            action:@selector(_addToPlaylistAction:) keyEquivalent:@""];
        [it setTarget:self];
        [it setRepresentedObject:name];
        added++;
    }
    if (added == 0) {
        NSMenuItem *none = [sub addItemWithTitle:@"No Playlists"
            action:nil keyEquivalent:@""];
        [none setEnabled:NO];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    SEL action = [item action];
    BOOL hasSel = ([[_trackTable selectedRowIndexes] count] > 0);

    if (action == @selector(_trackInfoAction:))                 return hasSel;
    if (action == @selector(_loveAction:))                      return hasSel;
    if (action == @selector(_dislikeAction:))                   return hasSel;
    if (action == @selector(_newPlaylistFromSelectionAction:))  return hasSel;
    if (action == @selector(_addToPlaylistAction:))             return hasSel;
    if (action == @selector(_deleteFromLibraryAction:))         return hasSel;

    if (action == @selector(_removeFromPlaylistAction:)) {
        if (!hasSel) return NO;
        // Active only when the user is browsing a named user playlist.
        return [[[MusicLibrary sharedLibrary] playlistNames]
                    containsObject:_currentSection];
    }
    return YES;
}

// ── Helpers ──

- (NSArray *)_selectedTracks
{
    NSIndexSet *sel = [_trackTable selectedRowIndexes];
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger idx = [sel firstIndex];
    while (idx != NSNotFound) {
        MusicTrack *t = [_trackCtrl trackAtRow:(NSInteger)idx];
        if (t) [result addObject:t];
        idx = [sel indexGreaterThanIndex:idx];
    }
    return result;
}

// ── Action implementations ──

- (void)_trackInfoAction:(id)sender
{
    NSArray *tracks = [self _selectedTracks];
    if ([tracks count] == 0) return;
    [_infoWindowCtrl release];
    _infoWindowCtrl = [[TrackInfoWindowController alloc] initWithTracks:tracks];
    [NSApp runModalForWindow:[_infoWindowCtrl window]];
    // runModal returns after OK/Cancel call stopModal; reload to reflect any edits.
    [_trackTable reloadData];
    [_infoWindowCtrl release];
    _infoWindowCtrl = nil;
}

- (void)_loveAction:(id)sender
{
    for (MusicTrack *t in [self _selectedTracks]) t.rating = 5;
    [_trackTable reloadData];
    [[MusicLibrary sharedLibrary] save];
}

- (void)_dislikeAction:(id)sender
{
    for (MusicTrack *t in [self _selectedTracks]) t.rating = 0;
    [_trackTable reloadData];
    [[MusicLibrary sharedLibrary] save];
}

- (void)_addToPlaylistAction:(id)sender
{
    NSString *name = [(NSMenuItem *)sender representedObject];
    if (!name) return;
    MusicLibrary *lib = [MusicLibrary sharedLibrary];
    for (MusicTrack *t in [self _selectedTracks])
        [lib addTrack:t toPlaylist:name];
    [lib save];
}

- (void)_newPlaylistFromSelectionAction:(id)sender
{
    // Simple modal input dialog
    NSWindow *dlg = [[[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 320, 118)
                  styleMask:NSTitledWindowMask | NSClosableWindowMask
                    backing:NSBackingStoreBuffered
                      defer:NO] autorelease];
    [dlg setTitle:@"New Playlist"];
    [dlg center];
    NSView *v = [dlg contentView];

    // "Playlist name:" label
    NSTextField *lbl = [[[NSTextField alloc]
        initWithFrame:NSMakeRect(16, 82, 130, 18)] autorelease];
    [lbl setStringValue:@"Playlist name:"];
    [lbl setBezeled:NO]; [lbl setDrawsBackground:NO];
    [lbl setEditable:NO]; [lbl setSelectable:NO];
    [[lbl cell] setFont:[NSFont systemFontOfSize:12]];
    [v addSubview:lbl];

    // Name text field
    NSTextField *nameField = [[[NSTextField alloc]
        initWithFrame:NSMakeRect(16, 56, 288, 24)] autorelease];
    [[nameField cell] setPlaceholderString:@"Untitled Playlist"];
    [v addSubview:nameField];
    [dlg makeFirstResponder:nameField];

    // Buttons
    GTunesModalHelper *helper = [[[GTunesModalHelper alloc] init] autorelease];

    NSButton *cancelBtn = [[[NSButton alloc]
        initWithFrame:NSMakeRect(148, 14, 80, 26)] autorelease];
    [cancelBtn setTitle:@"Cancel"];
    [cancelBtn setBezelStyle:NSRoundedBezelStyle];
    [cancelBtn setKeyEquivalent:@"\033"];
    [cancelBtn setTarget:helper];
    [cancelBtn setAction:@selector(cancelAction:)];
    [v addSubview:cancelBtn];

    NSButton *createBtn = [[[NSButton alloc]
        initWithFrame:NSMakeRect(232, 14, 72, 26)] autorelease];
    [createBtn setTitle:@"Create"];
    [createBtn setBezelStyle:NSRoundedBezelStyle];
    [createBtn setKeyEquivalent:@"\r"];
    [createBtn setTarget:helper];
    [createBtn setAction:@selector(okAction:)];
    [v addSubview:createBtn];

    NSInteger code = [NSApp runModalForWindow:dlg];
    [dlg orderOut:nil];

    if (code == NSAlertFirstButtonReturn) {
        NSString *name = [[nameField stringValue]
            stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([name length] > 0) {
            MusicLibrary *lib = [MusicLibrary sharedLibrary];
            [lib createPlaylist:name];
            for (MusicTrack *t in [self _selectedTracks])
                [lib addTrack:t toPlaylist:name];
            [lib save];
            // _libraryChanged: notification will reload the sidebar automatically
        }
    }
}

- (void)_removeFromPlaylistAction:(id)sender
{
    MusicLibrary *lib = [MusicLibrary sharedLibrary];
    for (MusicTrack *t in [self _selectedTracks])
        [lib removeTrack:t fromPlaylist:_currentSection];
    [lib save];
}

- (void)_deleteFromLibraryAction:(id)sender
{
    NSArray *tracks = [self _selectedTracks];
    if ([tracks count] == 0) return;

    NSString *msg, *detail;
    if ([tracks count] == 1) {
        msg    = @"Delete from Library?";
        detail = [NSString stringWithFormat:
            @"“%@” will be permanently deleted from disk.",
            [(MusicTrack *)tracks[0] displayTitle]];
    } else {
        msg    = @"Delete from Library?";
        detail = [NSString stringWithFormat:
            @"%lu tracks will be permanently deleted from disk.",
            (unsigned long)[tracks count]];
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:msg];
    [alert setInformativeText:detail];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        MusicLibrary *lib = [MusicLibrary sharedLibrary];
        for (MusicTrack *t in tracks)
            [lib removeTrack:t deleteFile:YES];
    }
}

@end
