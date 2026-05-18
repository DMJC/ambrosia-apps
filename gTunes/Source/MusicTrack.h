#import <Foundation/Foundation.h>
#import <AppKit/NSImage.h>

@interface MusicTrack : NSObject
{
    NSString      *_filePath;
    NSString      *_title;
    NSString      *_artist;
    NSString      *_album;
    NSString      *_genre;
    NSString      *_year;
    NSUInteger     _trackNumber;
    NSTimeInterval _duration;
    NSUInteger     _playCount;
    NSDate        *_lastPlayed;
    NSInteger      _rating;      // 0–5
    NSImage       *_albumArt;
    NSData        *_artData;        // raw JPEG/PNG bytes – used for plist persistence
    NSDate            *_dateAdded;   // when the track was added to the library
    BOOL               _metadataLoaded;
    unsigned long long _fileSize;   // cached so status bar avoids per-track stat() calls
}

@property (nonatomic, retain) NSString      *filePath;
@property (nonatomic, retain) NSString      *title;
@property (nonatomic, retain) NSString      *artist;
@property (nonatomic, retain) NSString      *album;
@property (nonatomic, retain) NSString      *genre;
@property (nonatomic, retain) NSString      *year;
@property (nonatomic, assign) NSUInteger     trackNumber;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSUInteger     playCount;
@property (nonatomic, retain) NSDate        *lastPlayed;
@property (nonatomic, retain) NSDate        *dateAdded;
@property (nonatomic, assign) NSInteger      rating;
@property (nonatomic, retain) NSImage       *albumArt;
@property (nonatomic, retain) NSData        *artData;
@property (nonatomic, assign) unsigned long long fileSize;

- (id)initWithFilePath:(NSString *)path;
- (void)loadMetadata;          // synchronous – call off main thread
- (void)saveMetadata;          // write stored properties back to audio file tags
- (void)saveMetadataWithTitle:(NSString *)title  // write explicit values to tags
                       artist:(NSString *)artist  // without mutating stored properties
                        album:(NSString *)album
                        genre:(NSString *)genre
                         year:(NSString *)year
                  trackNumber:(NSUInteger)trackNumber;
- (NSString *)durationString;
- (NSString *)displayTitle;

@end
