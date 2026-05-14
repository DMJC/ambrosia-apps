// MainWindowController.h
#import <AppKit/AppKit.h>
#import "LibrarySidebarController.h"
#import "BrowserController.h"
#import "TrackListController.h"
#import "NowPlayingBar.h"
#import "TrackInfoWindowController.h"

@interface MainWindowController : NSWindowController
    <LibrarySidebarDelegate, BrowserControllerDelegate,
     NowPlayingBarDelegate, NSMenuDelegate>
{
    // ── Toolbar / Now Playing ──
    NowPlayingBar              *_nowPlayingBar;

    // ── Main split: sidebar | content ──
    NSSplitView                *_mainSplit;

    // ── Sidebar ──
    NSView                     *_sidebarContainer;
    NSScrollView               *_sidebarScroll;
    NSOutlineView              *_sidebarOutline;
    LibrarySidebarController   *_sidebarCtrl;
    NSImageView                *_sidebarArtView;

    // ── Content area (vertical split: browser | tracklist) ──
    NSSplitView                *_contentSplit;

    // ── Browser (3-column: Genre/Artist/Album) ──
    NSView                     *_browserSplit;
    NSScrollView               *_genreScroll;
    NSScrollView               *_artistScroll;
    NSScrollView               *_albumScroll;
    NSTableView                *_genreTable;
    NSTableView                *_artistTable;
    NSTableView                *_albumTable;
    BrowserController          *_browserCtrl;

    // ── Track list ──
    NSScrollView               *_trackScroll;
    NSTableView                *_trackTable;
    TrackListController        *_trackCtrl;

    // ── Status bar ──
    NSTextField                *_statusBar;

    // ── Search ──
    NSSearchField              *_searchField;

    // Current section
    NSString                   *_currentSection;

    // Re-entrance guard for browser column layout (prevents notification loops during resize)
    BOOL                        _inBrowserLayout;

    // Track Info window (retained while open)
    TrackInfoWindowController  *_infoWindowCtrl;

    // Weak refs into the context menu — the menu (owned by _trackTable) retains these
    NSMenuItem                 *_addToPlaylistItem;
    NSMenuItem                 *_removeFromPlaylistItem;
}

- (id)init;
@end
