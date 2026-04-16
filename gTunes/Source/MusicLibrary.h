#import <Foundation/Foundation.h>
#import "MusicTrack.h"

extern NSString * const MusicLibraryDidChangeNotification;

@interface MusicLibrary : NSObject
{
    NSMutableArray      *_tracks;
    NSMutableDictionary *_playlistDict;   // name -> NSMutableArray
    NSMutableArray      *_playlistNames;
    dispatch_queue_t     _scanQueue;
    NSMutableDictionary *_artCache;       // hash key -> NSData  (shared art bytes)
    NSMutableDictionary *_artImageCache;  // hash key -> NSImage (shared art image)
}

+ (MusicLibrary *)sharedLibrary;

- (void)scanDirectory:(NSString *)path;

- (NSArray *)allTracks;
- (NSArray *)tracksForArtist:(NSString *)artist;
- (NSArray *)tracksForAlbum:(NSString *)album;
- (NSArray *)tracksForGenre:(NSString *)genre;

- (NSArray *)allArtists;
- (NSArray *)allAlbums;
- (NSArray *)allGenres;
- (NSArray *)albumsForArtist:(NSString *)artist;

- (NSArray *)playlistNames;
- (NSArray *)tracksForPlaylist:(NSString *)name;
- (void)createPlaylist:(NSString *)name;
- (void)deletePlaylist:(NSString *)name;
- (void)addTrack:(MusicTrack *)track toPlaylist:(NSString *)name;
- (void)removeTrack:(MusicTrack *)track fromPlaylist:(NSString *)name;

- (void)save;
- (void)load;

@end
