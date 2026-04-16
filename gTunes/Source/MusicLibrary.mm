#import "MusicLibrary.h"
#import <AppKit/NSBitmapImageRep.h>

NSString * const MusicLibraryDidChangeNotification = @"MusicLibraryDidChange";

static NSArray *kSupportedExtensions = nil;

@implementation MusicLibrary

+ (void)initialize
{
    kSupportedExtensions = [@[@"mp3",@"ogg",@"flac",@"wav",@"m4a",
                               @"alac",@"wma",@"aac",@"ape"] retain];
}

+ (MusicLibrary *)sharedLibrary
{
    static MusicLibrary *lib = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ lib = [[MusicLibrary alloc] init]; });
    return lib;
}

- (id)init
{
    self = [super init];
    if (self) {
        _tracks        = [[NSMutableArray alloc] init];
        _playlistDict  = [[NSMutableDictionary alloc] init];
        _playlistNames = [[NSMutableArray alloc] init];
        _artCache      = [[NSMutableDictionary alloc] init];
        _artImageCache = [[NSMutableDictionary alloc] init];
        _scanQueue     = dispatch_queue_create("org.gtunes.scan",
                             DISPATCH_QUEUE_SERIAL);
        [self load];
        // Ensure built-in playlists always exist
        for (NSString *name in @[@"Podcasts", @"Radio"]) {
            if (!_playlistDict[name]) {
                _playlistDict[name] = [NSMutableArray array];
                [_playlistNames addObject:name];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [_tracks        release];
    [_playlistDict  release];
    [_playlistNames release];
    [_artCache      release];
    [_artImageCache release];
    dispatch_release(_scanQueue);
    [super dealloc];
}

// ──────────── Art deduplication ────────────

// Returns a cheap hash key for art data: length + NSData hash.
// Collisions are theoretically possible but practically negligible for album art.
- (NSString *)_artKeyForData:(NSData *)data
{
    return [NSString stringWithFormat:@"%lu-%lu",
            (unsigned long)[data length], (unsigned long)[data hash]];
}

// Replaces a track's artData and albumArt with shared (interned) instances.
// Must be called on the main thread (no extra locking needed for the caches).
- (void)_internArtForTrack:(MusicTrack *)track
{
    NSData *data = track.artData;
    if (!data || [data length] == 0) return;

    NSString *key = [self _artKeyForData:data];

    NSData *sharedData = _artCache[key];
    if (!sharedData) {
        sharedData = data;
        _artCache[key] = sharedData;
    }

    NSImage *sharedImage = _artImageCache[key];
    if (!sharedImage) {
        NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:sharedData];
        if (rep) {
            sharedImage = [[NSImage alloc] initWithSize:[rep size]];
            [sharedImage addRepresentation:rep];
            _artImageCache[key] = sharedImage;
            [sharedImage release];
        }
    }

    track.artData  = sharedData;
    track.albumArt = sharedImage;
}

// ──────────── Scanning ────────────

- (void)scanDirectory:(NSString *)root
{
    NSLog(@"gTunes: library rescan triggered for path: %@", root);
    dispatch_async(_scanQueue, ^{
        @autoreleasepool {
            NSFileManager *fm = [NSFileManager defaultManager];
            NSDirectoryEnumerator *en =
                [fm enumeratorAtPath:root];
            NSString *rel;
            NSMutableArray *found = [NSMutableArray array];
            while ((rel = [en nextObject])) {
                NSString *ext = [[rel pathExtension] lowercaseString];
                if (![kSupportedExtensions containsObject:ext]) continue;
                NSString *full = [root stringByAppendingPathComponent:rel];
                // Skip if already indexed
                BOOL exists = NO;
                @synchronized(_tracks) {
                    for (MusicTrack *t in _tracks)
                        if ([t.filePath isEqualToString:full]) { exists=YES; break; }
                }
                if (exists) continue;
                MusicTrack *track = [[MusicTrack alloc] initWithFilePath:full];
                [track loadMetadata];
                [found addObject:track];
                [track release];
            }
            if ([found count] > 0) {
                // Flush to main thread in batches of 1000 so the library is
                // saved periodically during large scans rather than only at end.
                NSUInteger batchSize = 1000;
                for (NSUInteger i = 0; i < [found count]; i += batchSize) {
                    NSUInteger len = MIN(batchSize, [found count] - i);
                    NSArray *batch = [found subarrayWithRange:NSMakeRange(i, len)];
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        for (MusicTrack *t in batch)
                            [self _internArtForTrack:t];
                        @synchronized(_tracks) { [_tracks addObjectsFromArray:batch]; }
                        NSLog(@"[gTunes] scanned %lu files so far",
                              (unsigned long)[_tracks count]);
                        [[NSNotificationCenter defaultCenter]
                            postNotificationName:MusicLibraryDidChangeNotification
                                          object:self];
                        [self save];
                    });
                }
            }
        }
    });
}

// ──────────── Queries ────────────

- (NSArray *)allTracks
{
    @synchronized(_tracks) { return [NSArray arrayWithArray:_tracks]; }
}

- (NSArray *)tracksForArtist:(NSString *)artist
{
    @synchronized(_tracks) {
        return [_tracks filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"artist ==[c] %@", artist]];
    }
}

- (NSArray *)tracksForAlbum:(NSString *)album
{
    @synchronized(_tracks) {
        return [_tracks filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"album ==[c] %@", album]];
    }
}

- (NSArray *)tracksForGenre:(NSString *)genre
{
    @synchronized(_tracks) {
        return [_tracks filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"genre ==[c] %@", genre]];
    }
}

- (NSArray *)allArtists
{
    NSMutableSet *set = [NSMutableSet set];
    @synchronized(_tracks) {
        for (MusicTrack *t in _tracks) [set addObject:t.artist];
    }
    return [[set allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSArray *)allAlbums
{
    NSMutableSet *set = [NSMutableSet set];
    @synchronized(_tracks) {
        for (MusicTrack *t in _tracks) [set addObject:t.album];
    }
    return [[set allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSArray *)allGenres
{
    NSMutableSet *set = [NSMutableSet set];
    @synchronized(_tracks) {
        for (MusicTrack *t in _tracks) [set addObject:t.genre];
    }
    return [[set allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSArray *)albumsForArtist:(NSString *)artist
{
    NSMutableSet *set = [NSMutableSet set];
    @synchronized(_tracks) {
        for (MusicTrack *t in _tracks)
            if ([t.artist caseInsensitiveCompare:artist] == NSOrderedSame)
                [set addObject:t.album];
    }
    return [[set allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

// ──────────── Playlists ────────────

- (NSArray *)playlistNames { return [NSArray arrayWithArray:_playlistNames]; }

- (NSArray *)tracksForPlaylist:(NSString *)name
{
    return [NSArray arrayWithArray:_playlistDict[name] ?: @[]];
}

- (void)createPlaylist:(NSString *)name
{
    if (!_playlistDict[name]) {
        _playlistDict[name] = [NSMutableArray array];
        [_playlistNames addObject:name];
        [[NSNotificationCenter defaultCenter]
            postNotificationName:MusicLibraryDidChangeNotification object:self];
    }
}

- (void)deletePlaylist:(NSString *)name
{
    [_playlistDict removeObjectForKey:name];
    [_playlistNames removeObject:name];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:MusicLibraryDidChangeNotification object:self];
}

- (void)addTrack:(MusicTrack *)track toPlaylist:(NSString *)name
{
    NSMutableArray *pl = _playlistDict[name];
    if (pl && ![pl containsObject:track]) {
        [pl addObject:track];
        [[NSNotificationCenter defaultCenter]
            postNotificationName:MusicLibraryDidChangeNotification object:self];
    }
}

- (void)removeTrack:(MusicTrack *)track fromPlaylist:(NSString *)name
{
    [_playlistDict[name] removeObject:track];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:MusicLibraryDidChangeNotification object:self];
}

// ──────────── Persistence ────────────

- (NSString *)_savePath
{
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(
        NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *dir = [[dirs firstObject]
                     stringByAppendingPathComponent:@"gTunes"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
        withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"library.plist"];
}

- (void)save
{
    // Build deduplicated artwork dict: hash key -> NSData
    NSMutableDictionary *artworkDict = [NSMutableDictionary dictionary];
    NSMutableArray *trackDicts = [NSMutableArray array];
    @synchronized(_tracks) {
        for (MusicTrack *t in _tracks) {
            NSString *artHash = @"";
            if (t.artData && [t.artData length] > 0) {
                artHash = [self _artKeyForData:t.artData];
                if (!artworkDict[artHash])
                    artworkDict[artHash] = t.artData;
            }
            [trackDicts addObject:@{
                @"filePath"   : t.filePath   ?: @"",
                @"title"      : t.title      ?: @"",
                @"artist"     : t.artist     ?: @"",
                @"album"      : t.album      ?: @"",
                @"genre"      : t.genre      ?: @"",
                @"year"       : t.year       ?: @"",
                @"trackNumber": @(t.trackNumber),
                @"duration"   : @(t.duration),
                @"playCount"  : @(t.playCount),
                @"rating"     : @(t.rating),
                @"lastPlayed" : t.lastPlayed ?: [NSDate dateWithTimeIntervalSince1970:0],
                @"artHash"    : artHash,
            }];
        }
    }

    NSMutableDictionary *plists = [NSMutableDictionary dictionary];
    for (NSString *name in _playlistNames) {
        NSMutableArray *paths = [NSMutableArray array];
        for (MusicTrack *t in _playlistDict[name])
            [paths addObject:t.filePath];
        plists[name] = paths;
    }

    NSDictionary *root = @{
        @"tracks"        : trackDicts,
        @"artwork"       : artworkDict,
        @"playlists"     : plists,
        @"playlistOrder" : _playlistNames,
    };
    BOOL ok = [root writeToFile:[self _savePath] atomically:YES];
    NSLog(@"[gTunes] library saved to %@ (%lu tracks, %lu unique art) %@",
          [self _savePath], (unsigned long)[_tracks count],
          (unsigned long)[artworkDict count],
          ok ? @"OK" : @"FAILED");
}

- (void)load
{
    NSDictionary *root = [NSDictionary dictionaryWithContentsOfFile:[self _savePath]];
    if (!root) return;

    // Load deduplicated artwork table (new format).
    // Falls back gracefully if the key is absent (old format).
    NSDictionary *artworkDict = root[@"artwork"];

    NSArray *trackDicts = root[@"tracks"];
    for (NSDictionary *d in trackDicts) {
        NSString *path = d[@"filePath"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) continue;
        MusicTrack *t = [[MusicTrack alloc] initWithFilePath:path];
        t.title       = d[@"title"];
        t.artist      = d[@"artist"];
        t.album       = d[@"album"];
        t.genre       = d[@"genre"];
        t.year        = d[@"year"];
        t.trackNumber = [d[@"trackNumber"] unsignedIntegerValue];
        t.duration    = [d[@"duration"]    doubleValue];
        t.playCount   = [d[@"playCount"]   unsignedIntegerValue];
        t.rating      = [d[@"rating"]      integerValue];
        id lp = d[@"lastPlayed"];
        if ([lp isKindOfClass:[NSDate class]] && [lp timeIntervalSince1970] > 0)
            t.lastPlayed = lp;

        // Resolve art: new format uses artHash ref, old format has inline artData.
        NSData *artData = nil;
        NSString *artHash = d[@"artHash"];
        if ([artHash isKindOfClass:[NSString class]] && [artHash length] > 0)
            artData = artworkDict[artHash];
        if (!artData) {
            // Old format fallback
            id inlineart = d[@"artData"];
            if ([inlineart isKindOfClass:[NSData class]] && [inlineart length] > 0)
                artData = inlineart;
        }
        if (artData) {
            t.artData = artData;
            [_artCache setObject:artData
                          forKey:artHash ?: [self _artKeyForData:artData]];
        }

        [_tracks addObject:t];
        [t release];
    }

    // Build shared NSImage instances for all interned art data.
    for (NSString *key in _artCache) {
        if (_artImageCache[key]) continue;
        NSData *data = _artCache[key];
        NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:data];
        if (rep) {
            NSImage *img = [[NSImage alloc] initWithSize:[rep size]];
            [img addRepresentation:rep];
            _artImageCache[key] = img;
            [img release];
        }
    }

    // Point every track at its shared NSImage.
    for (MusicTrack *t in _tracks) {
        if (!t.artData || [t.artData length] == 0) continue;
        NSString *key = [self _artKeyForData:t.artData];
        NSImage *img = _artImageCache[key];
        if (img) t.albumArt = img;
    }

    NSArray *order = root[@"playlistOrder"];
    NSDictionary *plists = root[@"playlists"];
    for (NSString *name in order) {
        [_playlistNames addObject:name];
        NSMutableArray *pl = [NSMutableArray array];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *path in plists[name]) {
            if (![fm fileExistsAtPath:path]) continue;
            for (MusicTrack *t in _tracks)
                if ([t.filePath isEqualToString:path]) { [pl addObject:t]; break; }
        }
        _playlistDict[name] = pl;
    }
}

@end
