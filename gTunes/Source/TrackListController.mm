// TrackListController.mm
#import "TrackListController.h"
#import "AudioPlayer.h"
#import "RatingCell.h"

@implementation TrackListController

@synthesize tracks = _tracks;

- (id)init
{
    self = [super init];
    if (self) {
        _tracks = [[NSMutableArray alloc] init];
        _sortDescriptors = [@[
            [NSSortDescriptor sortDescriptorWithKey:@"artist" ascending:YES
                selector:@selector(caseInsensitiveCompare:)],
            [NSSortDescriptor sortDescriptorWithKey:@"album" ascending:YES
                selector:@selector(caseInsensitiveCompare:)],
            [NSSortDescriptor sortDescriptorWithKey:@"trackNumber" ascending:YES],
        ] retain];
    }
    return self;
}

- (void)dealloc
{
    [_tracks release]; [_sortDescriptors release];
    [_searchString release]; [super dealloc];
}

- (void)setTableView:(NSTableView *)tv
{
    _tableView = tv;
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setAllowsMultipleSelection:YES];
    [_tableView setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
    [_tableView setUsesAlternatingRowBackgroundColors:YES];
    [_tableView setRowHeight:17.0];

    for (NSTableColumn *col in [_tableView tableColumns]) {
        [col setEditable:NO];
        if ([[col identifier] isEqualToString:@"rating"]) {
            RatingCell *rc = [[RatingCell alloc] init];
            [col setDataCell:rc];
            [rc release];
        }
    }
}

- (void)setTracks:(NSArray *)tracks
{
    NSArray *sorted = [tracks sortedArrayUsingDescriptors:_sortDescriptors];
    [_tracks setArray:sorted];
    [self _applySearch];
}

- (void)filterBySearchString:(NSString *)s
{
    [_searchString release];
    _searchString = [s length] ? [s retain] : nil;
    [self _applySearch];
}

- (void)_applySearch
{
    // (tracks are already stored; search just filters display)
    [_tableView reloadData];
}

- (NSArray *)_visibleTracks
{
    if (!_searchString) return _tracks;
    NSPredicate *p = [NSPredicate predicateWithFormat:
        @"title CONTAINS[cd] %@ OR artist CONTAINS[cd] %@ OR album CONTAINS[cd] %@",
        _searchString, _searchString, _searchString];
    return [_tracks filteredArrayUsingPredicate:p];
}

- (MusicTrack *)trackAtRow:(NSInteger)row
{
    NSArray *v = [self _visibleTracks];
    if (row < 0 || row >= (NSInteger)[v count]) return nil;
    return v[row];
}

// ── DataSource ──

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
    return (NSInteger)[[self _visibleTracks] count];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)col
            row:(NSInteger)row
{
    MusicTrack *t = [self trackAtRow:row];
    if (!t) return nil;
    NSString *ident = [col identifier];
    if ([ident isEqualToString:@"name"])      return [t displayTitle];
    if ([ident isEqualToString:@"time"])      return [t durationString];
    if ([ident isEqualToString:@"artist"])    return t.artist;
    if ([ident isEqualToString:@"album"])     return t.album;
    if ([ident isEqualToString:@"genre"])     return t.genre;
    if ([ident isEqualToString:@"rating"])    return @(t.rating);
    if ([ident isEqualToString:@"playCount"]) return @(t.playCount);
    if ([ident isEqualToString:@"lastPlayed"])
        return t.lastPlayed ? [t.lastPlayed descriptionWithCalendarFormat:
            @"%m/%d/%y %H:%M" timeZone:nil locale:nil] : @"";
    return nil;
}

// ── Delegate ──

- (BOOL)tableView:(NSTableView *)tv shouldEditTableColumn:(NSTableColumn *)col
              row:(NSInteger)row
{
    return NO;
}

// ── Delegate – column sort ──

- (void)tableView:(NSTableView *)tv didClickTableColumn:(NSTableColumn *)col
{
    // Toggle sort direction
    NSSortDescriptor *sd = [NSSortDescriptor
        sortDescriptorWithKey:[col identifier] ascending:YES
        selector:@selector(caseInsensitiveCompare:)];
    [_sortDescriptors release];
    _sortDescriptors = [@[sd] retain];
    [_tracks sortUsingDescriptors:_sortDescriptors];
    [tv reloadData];
}

@end
