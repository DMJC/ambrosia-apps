// LibrarySidebarController.mm
#import "LibrarySidebarController.h"
#import "MusicLibrary.h"

// Simple model objects for outline view nodes
@interface SidebarGroup : NSObject
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSMutableArray *children;
@end
@implementation SidebarGroup
@synthesize title, children;
- (void)dealloc { [title release]; [children release]; [super dealloc]; }
@end

@interface SidebarItem : NSObject
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *imageName;
@end
@implementation SidebarItem
@synthesize title, imageName;
- (void)dealloc { [title release]; [imageName release]; [super dealloc]; }
@end

static SidebarItem *item(NSString *t, NSString *img) {
    SidebarItem *i = [[SidebarItem alloc] init];
    i.title = t; i.imageName = img;
    return [i autorelease];
}

@implementation LibrarySidebarController
@synthesize delegate = _delegate;

- (id)init { self = [super init]; [self _buildSections]; return self; }

- (void)dealloc { [_sections release]; [super dealloc]; }

- (void)_buildSections
{
    [_sections release];
    NSMutableArray *all = [NSMutableArray array];

    SidebarGroup *lib = [[SidebarGroup alloc] init];
    lib.title = @"LIBRARY";
    lib.children = [NSMutableArray arrayWithObjects:
        item(@"Music",      @"NSMusicgTunesLibrary"),
        item(@"Podcasts",   @"NSPodcastGTunesLibrary"),
        item(@"Radio",      @"NSRadioGTunesLibrary"),
        nil];
    [all addObject:lib]; [lib release];

    SidebarGroup *shared = [[SidebarGroup alloc] init];
    shared.title = @"SHARED";
    shared.children = [NSMutableArray arrayWithObjects:
        item(@"Home Sharing",    @"NSHomeTemplate"),
        nil];
    [all addObject:shared]; [shared release];

    SidebarGroup *intelligence = [[SidebarGroup alloc] init];
    intelligence.title = @"INTELLIGENCE";
    intelligence.children = [NSMutableArray arrayWithObject:
        item(@"Intelligence",@"NSSmartBadgeTemplate")];
    [all addObject:intelligence]; [intelligence release];

    SidebarGroup *pls = [[SidebarGroup alloc] init];
    pls.title = @"PLAYLISTS";
    pls.children = [NSMutableArray array];
    [pls.children addObject:item(@"iTunes DJ",     @"NSBonjour")];
    [pls.children addObject:item(@"My Top Rated",  @"NSPlaylistTemplate")];
    [pls.children addObject:item(@"Recently Added",@"NSPlaylistTemplate")];
    [pls.children addObject:item(@"Recently Played",@"NSPlaylistTemplate")];
    [pls.children addObject:item(@"Top 25 Most Played",@"NSPlaylistTemplate")];
    // User playlists from library (skip built-in library playlists shown above)
    NSSet *libraryPlaylists = [NSSet setWithObjects:@"Podcasts", @"Radio", nil];
    for (NSString *name in [[MusicLibrary sharedLibrary] playlistNames])
        if (![libraryPlaylists containsObject:name])
            [pls.children addObject:item(name, @"NSPlaylistTemplate")];
    [pls.children addObject:item(@"All", @"NSPlaylistTemplate")];
    [all addObject:pls]; [pls release];

    _sections = [all retain];
}

- (void)setOutlineView:(NSOutlineView *)ov
{
    _outlineView = ov;
    [_outlineView setDataSource:self];
    [_outlineView setDelegate:self];
    [_outlineView setHeaderView:nil];
    [_outlineView setIndentationPerLevel:12];
    if ([[_outlineView tableColumns] count] > 0)
        [_outlineView setOutlineTableColumn:
            [[_outlineView tableColumns] objectAtIndex:0]];
    [_outlineView reloadData];
    // Expand all groups by default
    for (id group in _sections)
        [_outlineView expandItem:group];
    // Select "Music" by default
    [_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:1]
              byExtendingSelection:NO];
}

- (void)reload { [self _buildSections]; [_outlineView reloadData]; }

// ── DataSource ──

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item
{
    if (!item) return (NSInteger)[_sections count];
    if ([item isKindOfClass:[SidebarGroup class]])
        return (NSInteger)[((SidebarGroup *)item).children count];
    return 0;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)index ofItem:(id)item
{
    if (!item) return _sections[index];
    return ((SidebarGroup *)item).children[index];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item
{
    return [item isKindOfClass:[SidebarGroup class]];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)col
           byItem:(id)item
{
    if ([item isKindOfClass:[SidebarGroup class]])
        return ((SidebarGroup *)item).title;
    return ((SidebarItem *)item).title;
}

// ── Delegate ──

- (NSTableRowView *)outlineView:(NSOutlineView *)ov rowViewForItem:(id)item
{
    return nil; // Use default
}

- (NSView *)outlineView:(NSOutlineView *)ov
     viewForTableColumn:(NSTableColumn *)col item:(id)anItem
{
    if ([anItem isKindOfClass:[SidebarGroup class]]) {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSZeroRect];
        [tf setBezeled:NO]; [tf setDrawsBackground:NO];
        [tf setEditable:NO]; [tf setSelectable:NO];
        [tf setStringValue:((SidebarGroup *)anItem).title];
        [[tf cell] setFont:[NSFont boldSystemFontOfSize:10]];
        [[tf cell] setTextColor:[NSColor grayColor]];
        return [tf autorelease];
    }
    SidebarItem *si = (SidebarItem *)anItem;
    NSTableCellView *cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
    // Image
    NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 1, 16, 16)];
    NSImage *img = [NSImage imageNamed:si.imageName];
    if (!img) img = [NSImage imageNamed:NSImageNameMultipleDocuments];
    [iv setImage:img]; [iv setImageScaling:NSImageScaleProportionallyDown];
    [cell addSubview:iv]; [iv release];
    // Label
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 0, 140, 18)];
    [tf setBezeled:NO]; [tf setDrawsBackground:NO];
    [tf setEditable:NO]; [tf setSelectable:NO];
    [tf setStringValue:si.title];
    [[tf cell] setFont:[NSFont systemFontOfSize:12]];
    [cell addSubview:tf]; [tf release];
    return [cell autorelease];
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldSelectItem:(id)item
{
    return [item isKindOfClass:[SidebarItem class]];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)note
{
    id item = [_outlineView itemAtRow:[_outlineView selectedRow]];
    if ([item isKindOfClass:[SidebarItem class]])
        [_delegate sidebarSelectedSection:((SidebarItem *)item).title];
}

@end
