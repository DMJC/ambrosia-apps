// BrowserController.mm
#import "BrowserController.h"
#import "MusicLibrary.h"
#import "MusicTrack.h"

// Returns sorted unique non-empty string values for `key` across `tracks`.
static NSArray *uniqueSortedValues(NSArray *tracks, NSString *key)
{
    NSMutableSet *set = [NSMutableSet setWithCapacity:[tracks count]];
    for (MusicTrack *t in tracks) {
        NSString *val = [t valueForKey:key];
        if ([val length]) [set addObject:val];
    }
    return [[set allObjects]
        sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

@interface BrowserController ()
{
    NSArray *_baseTracks;   // tracks for the current section (nil = whole library)
}
- (void)_rebuildLists;
- (NSArray *)_tracksForGenre:(NSString *)genre artist:(NSString *)artist;
@end

@implementation BrowserController
@synthesize delegate = _delegate;

- (id)init
{
    self = [super init];
    if (self) {
        _genres  = [@[@"All Genres"]  retain];
        _artists = [@[@"All Artists"] retain];
        _albums  = [@[@"All Albums"]  retain];
    }
    return self;
}

- (void)dealloc
{
    [_genres  release]; [_artists release]; [_albums  release];
    [_selectedGenre  release]; [_selectedArtist release]; [_selectedAlbum  release];
    [_baseTracks release];
    [super dealloc];
}

- (void)setGenreTable:(NSTableView *)g artistTable:(NSTableView *)a
           albumTable:(NSTableView *)al
{
    _genreTable  = g;  [_genreTable  setDataSource:self]; [_genreTable  setDelegate:self];
    _artistTable = a;  [_artistTable setDataSource:self]; [_artistTable setDelegate:self];
    _albumTable  = al; [_albumTable  setDataSource:self]; [_albumTable  setDelegate:self];
    [self reload];
}

// Rebuild lists using the current _baseTracks (or all library data when nil).
- (void)reload
{
    [self _rebuildLists];
}

// Set a new base track set and rebuild.  Resets all column selections.
- (void)reloadWithTracks:(NSArray *)tracks
{
    [_baseTracks release];
    _baseTracks = [tracks retain];
    [self _rebuildLists];
}

// ── Private ──

- (void)_rebuildLists
{
    NSArray *genres, *artists, *albums;

    if (_baseTracks) {
        genres  = uniqueSortedValues(_baseTracks, @"genre");
        artists = uniqueSortedValues(_baseTracks, @"artist");
        albums  = uniqueSortedValues(_baseTracks, @"album");
    } else {
        MusicLibrary *lib = [MusicLibrary sharedLibrary];
        genres  = [lib allGenres];
        artists = [lib allArtists];
        albums  = [lib allAlbums];
    }

    NSMutableArray *g = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"All (%lu Genres)",
            (unsigned long)[genres count]]];
    [g addObjectsFromArray:genres];
    [_genres release]; _genres = [g retain];

    NSMutableArray *ar = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"All (%lu Artists)",
            (unsigned long)[artists count]]];
    [ar addObjectsFromArray:artists];
    [_artists release]; _artists = [ar retain];

    NSMutableArray *al = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"All (%lu Albums)",
            (unsigned long)[albums count]]];
    [al addObjectsFromArray:albums];
    [_albums release]; _albums = [al retain];

    [_selectedGenre  release]; _selectedGenre  = nil;
    [_selectedArtist release]; _selectedArtist = nil;
    [_selectedAlbum  release]; _selectedAlbum  = nil;

    [_genreTable  reloadData];
    [_artistTable reloadData];
    [_albumTable  reloadData];
}

// Returns _baseTracks filtered by the given genre and/or artist.
// Passing nil for either skips that filter.
- (NSArray *)_tracksForGenre:(NSString *)genre artist:(NSString *)artist
{
    NSArray *tracks = _baseTracks
        ?: [[MusicLibrary sharedLibrary] allTracks];
    if (genre)
        tracks = [tracks filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"genre ==[c] %@", genre]];
    if (artist)
        tracks = [tracks filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"artist ==[c] %@", artist]];
    return tracks;
}

// ── NSTableViewDataSource ──

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
    if (tv == _genreTable)  return (NSInteger)[_genres  count];
    if (tv == _artistTable) return (NSInteger)[_artists count];
    if (tv == _albumTable)  return (NSInteger)[_albums  count];
    return 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)col
            row:(NSInteger)row
{
    if (row < 0) return nil;
    if (tv == _genreTable  && row < (NSInteger)[_genres  count]) return _genres [row];
    if (tv == _artistTable && row < (NSInteger)[_artists count]) return _artists[row];
    if (tv == _albumTable  && row < (NSInteger)[_albums  count]) return _albums [row];
    return nil;
}

// ── NSTableViewDelegate ──

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
    if (_updating) return;
    _updating = YES;

    NSTableView *tv = note.object;
    NSInteger row = [tv selectedRow];
    if (row < 0) { _updating = NO; return; }

    if (tv == _genreTable) {
        [_selectedGenre release];
        _selectedGenre = row == 0 ? nil : [_genres[row] retain];

        // Artists scoped to selected genre (within base tracks)
        NSArray *filteredByGenre = [self _tracksForGenre:_selectedGenre artist:nil];
        NSArray *artists = uniqueSortedValues(filteredByGenre, @"artist");
        NSMutableArray *ar = [NSMutableArray arrayWithObject:
            [NSString stringWithFormat:@"All (%lu Artists)",
                (unsigned long)[artists count]]];
        [ar addObjectsFromArray:artists];
        [_artists release]; _artists = [ar retain];
        [_artistTable reloadData];
        [_artistTable deselectAll:nil];
        [_selectedArtist release]; _selectedArtist = nil;

        // Albums scoped to selected genre (within base tracks)
        NSArray *albums = uniqueSortedValues(filteredByGenre, @"album");
        NSMutableArray *al = [NSMutableArray arrayWithObject:
            [NSString stringWithFormat:@"All (%lu Albums)",
                (unsigned long)[albums count]]];
        [al addObjectsFromArray:albums];
        [_albums release]; _albums = [al retain];
        [_albumTable reloadData];
        [_albumTable deselectAll:nil];
        [_selectedAlbum release]; _selectedAlbum = nil;
    }
    else if (tv == _artistTable) {
        [_selectedArtist release];
        _selectedArtist = row == 0 ? nil : [_artists[row] retain];

        // Albums scoped to selected genre + artist (within base tracks)
        NSArray *filtered = [self _tracksForGenre:_selectedGenre artist:_selectedArtist];
        NSArray *albums = uniqueSortedValues(filtered, @"album");
        NSMutableArray *al = [NSMutableArray arrayWithObject:
            [NSString stringWithFormat:@"All (%lu Albums)",
                (unsigned long)[albums count]]];
        [al addObjectsFromArray:albums];
        [_albums release]; _albums = [al retain];
        [_albumTable reloadData];
        [_albumTable deselectAll:nil];
        [_selectedAlbum release]; _selectedAlbum = nil;
    }
    else if (tv == _albumTable) {
        [_selectedAlbum release];
        _selectedAlbum = row == 0 ? nil : [_albums[row] retain];
    }

    [_delegate browserSelectionChangedWithGenre:_selectedGenre
                                         artist:_selectedArtist
                                          album:_selectedAlbum];
    _updating = NO;
}
@end
