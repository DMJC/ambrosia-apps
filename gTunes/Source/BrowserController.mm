// BrowserController.mm
#import "BrowserController.h"
#import "MusicLibrary.h"

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

- (void)reload
{
    MusicLibrary *lib = [MusicLibrary sharedLibrary];
    NSMutableArray *g = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"All (%lu Genres)",
            (unsigned long)[[lib allGenres] count]]];
    [g addObjectsFromArray:[lib allGenres]];
    [_genres release]; _genres = [g retain];

    NSMutableArray *ar = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"All (%lu Artists)",
            (unsigned long)[[lib allArtists] count]]];
    [ar addObjectsFromArray:[lib allArtists]];
    [_artists release]; _artists = [ar retain];

    NSMutableArray *al = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"All (%lu Albums)",
            (unsigned long)[[lib allAlbums] count]]];
    [al addObjectsFromArray:[lib allAlbums]];
    [_albums release]; _albums = [al retain];

    [_genreTable  reloadData];
    [_artistTable reloadData];
    [_albumTable  reloadData];
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

    MusicLibrary *lib = [MusicLibrary sharedLibrary];

    if (tv == _genreTable) {
        [_selectedGenre release];
        _selectedGenre = row == 0 ? nil : [_genres[row] retain];
        // Refresh artists filtered by genre
        NSArray *artists;
        if (_selectedGenre) {
            NSArray *tracks = [lib tracksForGenre:_selectedGenre];
            NSMutableSet *set = [NSMutableSet set];
            for (MusicTrack *t in tracks) [set addObject:t.artist];
            artists = [[set allObjects]
                sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        } else artists = [lib allArtists];
        NSMutableArray *ar = [NSMutableArray arrayWithObject:
            [NSString stringWithFormat:@"All (%lu Artists)",
                (unsigned long)[artists count]]];
        [ar addObjectsFromArray:artists];
        [_artists release]; _artists = [ar retain];
        [_artistTable reloadData];
        [_artistTable deselectAll:nil];
        [_selectedArtist release]; _selectedArtist = nil;
        // Reset album table to match the genre change
        NSArray *allAlbums = [lib allAlbums];
        NSMutableArray *al = [NSMutableArray arrayWithObject:
            [NSString stringWithFormat:@"All (%lu Albums)",
                (unsigned long)[allAlbums count]]];
        [al addObjectsFromArray:allAlbums];
        [_albums release]; _albums = [al retain];
        [_albumTable reloadData];
        [_albumTable deselectAll:nil];
        [_selectedAlbum release]; _selectedAlbum = nil;
    }
    else if (tv == _artistTable) {
        [_selectedArtist release];
        _selectedArtist = row == 0 ? nil : [_artists[row] retain];
        NSArray *albums;
        if (_selectedArtist)
            albums = [lib albumsForArtist:_selectedArtist];
        else albums = [lib allAlbums];
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
