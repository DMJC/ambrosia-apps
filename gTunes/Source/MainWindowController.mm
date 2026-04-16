// MainWindowController.mm
#import "MainWindowController.h"
#import "MusicLibrary.h"
#import "AudioPlayer.h"
#import "Preferences.h"

@interface MainWindowController ()
- (void)_buildMenu;
- (void)_buildWindow;
- (void)_buildNowPlayingBar;
- (void)_buildSidebar;
- (void)_buildBrowser;
- (void)_buildTrackList;
- (void)_buildStatusBar;
- (void)_reloadTrackListForSection:(NSString *)section
                             genre:(NSString *)genre
                            artist:(NSString *)artist
                             album:(NSString *)album;
- (void)_addMusicFolder:(id)sender;
- (void)_rescanDefaultLibrary:(id)sender;
- (void)_doubleClickTrack:(id)sender;
- (void)_libraryChanged:(NSNotification *)note;
- (void)_updateStatusBar;
// Controls
- (void)_toggleShuffle:(id)sender;
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
        _currentSection = [@"Music" retain];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_currentSection release];
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

        NSMenuItem *rescan = [fileMenu addItemWithTitle:@"Rescan Default Music Library"
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
        initWithFrame:NSMakeRect(cw - 170, ch - 54, 160, 22)];
    [_searchField setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    [[_searchField cell] setPlaceholderString:@"Search"];
    [_searchField setContinuous:YES];
    [_searchField setTarget:self]; [_searchField setAction:@selector(_search:)];
    [_searchField setDelegate:(id)self];
    [content addSubview:_searchField];

    // ── Status bar (bottom, 20px) ──
    [self _buildStatusBar];
    NSRect sbRect = NSMakeRect(0, 0, cw, 22);
    [_statusBar setFrame:sbRect];
    [_statusBar setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    [content addSubview:_statusBar];

    // ── Main horizontal split: sidebar (200px) | content ──
    CGFloat splitTop = ch - 62;
    CGFloat splitH   = splitTop - 22;
    _mainSplit = [[NSSplitView alloc]
        initWithFrame:NSMakeRect(0, 22, cw, splitH)];
    [_mainSplit setDividerStyle:NSSplitViewDividerStyleThin];
    [_mainSplit setVertical:YES];
    [_mainSplit setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    // Sidebar
    [self _buildSidebar];
    NSRect sideRect = NSMakeRect(0, 0, 180, splitH);
    [_sidebarScroll setFrame:sideRect];
    [_mainSplit addSubview:_sidebarScroll];

    // Content split (vertical: browser 150px | track list)
    _contentSplit = [[NSSplitView alloc]
        initWithFrame:NSMakeRect(0, 0, cw - 182, splitH)];
    [_contentSplit setDividerStyle:NSSplitViewDividerStyleThin];
    [_contentSplit setVertical:NO]; // horizontal split: browser top, tracks below

    // Browser
    [self _buildBrowser];
    NSRect browserRect = NSMakeRect(0, splitH - 155, cw - 182, 155);
    [_browserSplit setFrame:browserRect];
    [_browserSplit adjustSubviews];
    // NSScrollView does not resize its document view; set each table view width
    // explicitly now that the split has established real scroll view frames.
    {
        NSScrollView *svs[] = { _genreScroll, _artistScroll, _albumScroll };
        NSTableView  *tvs[] = { _genreTable,  _artistTable,  _albumTable  };
        for (int i = 0; i < 3; i++) {
            CGFloat w = NSWidth([svs[i] frame]);
            NSRect tf = [tvs[i] frame];
            tf.size.width = MAX(w, 60);
            [tvs[i] setFrame:tf];
            [[tvs[i] tableColumns][0] setWidth:tf.size.width];
        }
    }
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
    _statusBar = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_statusBar setBezeled:NO];
    [_statusBar setDrawsBackground:YES];
    [_statusBar setBackgroundColor:
        [NSColor colorWithCalibratedWhite:0.85 alpha:1.0]];
    [_statusBar setEditable:NO]; [_statusBar setSelectable:NO];
    [_statusBar setAlignment:NSTextAlignmentCenter];
    [[_statusBar cell] setFont:[NSFont systemFontOfSize:11]];
    [_statusBar setStringValue:@"0 songs"];
}

- (void)_buildSidebar
{
    _sidebarScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_sidebarScroll setBorderType:NSNoBorder];
    [_sidebarScroll setHasVerticalScroller:YES];
    [_sidebarScroll setAutohidesScrollers:YES];

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
    [tv setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
    [tv setAutoresizingMask:NSViewWidthSizable];
    return [tv autorelease];
}

- (void)_buildBrowser
{
    // Three-column browser (Genre | Artist | Album)
    _browserSplit = [[NSSplitView alloc] initWithFrame:NSZeroRect];
    [_browserSplit setDividerStyle:NSSplitViewDividerStyleThin];
    [_browserSplit setVertical:YES];

    NSArray *ids    = @[@"genre",    @"artist",    @"album"];
    NSArray *titles = @[@"Genres",   @"Artists",   @"Albums"];
    NSArray *headers = @[@"Genres",  @"Artists",   @"Albums"];

    _genreTable  = [self _makeColumnTableWithIdentifiers:@[@"genre"]
                                                  titles:@[headers[0]]];
    _artistTable = [self _makeColumnTableWithIdentifiers:@[@"artist"]
                                                  titles:@[headers[1]]];
    _albumTable  = [self _makeColumnTableWithIdentifiers:@[@"album"]
                                                  titles:@[headers[2]]];

    _genreScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_genreScroll setBorderType:NSBezelBorder];
    [_genreScroll setHasVerticalScroller:YES];
    [_genreScroll setAutohidesScrollers:YES];
    [_genreScroll setDocumentView:_genreTable];

    _artistScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_artistScroll setBorderType:NSBezelBorder];
    [_artistScroll setHasVerticalScroller:YES];
    [_artistScroll setAutohidesScrollers:YES];
    [_artistScroll setDocumentView:_artistTable];

    _albumScroll  = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_albumScroll setBorderType:NSBezelBorder];
    [_albumScroll setHasVerticalScroller:YES];
    [_albumScroll setAutohidesScrollers:YES];
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

- (void)_buildTrackList
{
    _trackScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    [_trackScroll setBorderType:NSNoBorder];
    [_trackScroll setHasVerticalScroller:YES];
    [_trackScroll setHasHorizontalScroller:NO];
    [_trackScroll setAutohidesScrollers:YES];

    NSArray *colIds = @[@"name",  @"time",  @"artist", @"album",
                        @"genre", @"rating",@"playCount", @"lastPlayed"];
    NSArray *colTtl = @[@"Name",  @"Time",  @"Artist", @"Album",
                        @"Genre", @"Rating",@"Play Count",@"Last Played"];
    CGFloat colW[]  = {220, 50, 120, 130, 80, 72, 72, 130};

    _trackTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    for (NSUInteger i = 0; i < [colIds count]; i++) {
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:colIds[i]];
        [[col headerCell] setStringValue:colTtl[i]];
        [col setWidth:colW[i]];
        [col setMinWidth:40];
        if (i == 0) [col setResizingMask:NSTableColumnAutoresizingMask];
        [_trackTable addTableColumn:col]; [col release];
    }
    [_trackTable setDoubleAction:@selector(_doubleClickTrack:)];
    [_trackTable setTarget:self];
    [_trackScroll setDocumentView:_trackTable];

    _trackCtrl = [[TrackListController alloc] init];
    [_trackCtrl setTableView:_trackTable];
}

// ──────────── Delegates ────────────

- (void)sidebarSelectedSection:(NSString *)section
{
    [_currentSection release]; _currentSection = [section retain];
    [self _reloadTrackListForSection:section genre:nil artist:nil album:nil];
    [_browserCtrl reload];
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

- (void)_doubleClickTrack:(id)sender
{
    NSInteger row = [_trackTable clickedRow];
    if (row < 0) return;
    MusicTrack *t = [_trackCtrl trackAtRow:row];
    if (!t) return;
    // Build queue from visible tracks
    [[AudioPlayer sharedPlayer] playTrack:t
                                withQueue:[_trackCtrl tracks]];
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
    [[AudioPlayer sharedPlayer] playTrack:t withQueue:[_trackCtrl tracks]];
}
- (void)_next:(id)sender     { [[AudioPlayer sharedPlayer] next]; }
- (void)_previous:(id)sender { [[AudioPlayer sharedPlayer] previous]; }

- (void)_rescanDefaultLibrary:(id)sender
{
    NSString *path = [[Preferences sharedPreferences] musicLibraryPath];
    if (path) [[MusicLibrary sharedLibrary] scanDirectory:path];
}

// ── Controls extras ──

- (void)_toggleShuffle:(id)sender
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    p.shuffle = !p.shuffle;
}

- (void)_cycleRepeat:(id)sender
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    p.repeatMode = (RepeatMode)((p.repeatMode + 1) % 3);
}

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

- (void)_libraryChanged:(NSNotification *)note
{
    [_browserCtrl reload];
    [self _reloadTrackListForSection:_currentSection
                               genre:nil artist:nil album:nil];
    [_sidebarCtrl reload];
}

- (void)_updateStatusBar
{
    NSArray *tracks = [_trackCtrl tracks];
    NSUInteger n    = [tracks count];
    NSTimeInterval totalSecs = 0;
    NSUInteger totalBytes = 0;
    for (MusicTrack *t in tracks) {
        totalSecs  += t.duration;
        // Approximate file size
        NSDictionary *attrs = [[NSFileManager defaultManager]
            attributesOfItemAtPath:t.filePath error:nil];
        totalBytes += [attrs[NSFileSize] unsignedIntegerValue];
    }
    NSUInteger h = (NSUInteger)(totalSecs / 3600);
    NSUInteger m = (NSUInteger)((totalSecs - h * 3600) / 60);
    CGFloat mb = totalBytes / (1024.0 * 1024.0);
    [_statusBar setStringValue:[NSString stringWithFormat:
        @"%lu songs, %lu.%lu hours, %.1f MB",
        (unsigned long)n, (unsigned long)h, (unsigned long)m, mb]];
}

@end
