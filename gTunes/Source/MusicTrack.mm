#import "MusicTrack.h"
#import <AppKit/NSBitmapImageRep.h>

#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/flacfile.h>
#include <taglib/flacpicture.h>
#include <taglib/mp4file.h>
#include <taglib/mp4tag.h>
#include <taglib/mp4coverart.h>
#include <taglib/vorbisfile.h>
#include <taglib/xiphcomment.h>
#include <taglib/asffile.h>
#include <taglib/asftag.h>
#include <taglib/wavfile.h>

@implementation MusicTrack

@synthesize filePath    = _filePath;
@synthesize title       = _title;
@synthesize artist      = _artist;
@synthesize album       = _album;
@synthesize genre       = _genre;
@synthesize year        = _year;
@synthesize trackNumber = _trackNumber;
@synthesize duration    = _duration;
@synthesize playCount   = _playCount;
@synthesize lastPlayed  = _lastPlayed;
@synthesize rating      = _rating;
@synthesize albumArt    = _albumArt;
@synthesize artData     = _artData;
@synthesize fileSize    = _fileSize;

- (id)initWithFilePath:(NSString *)path
{
    self = [super init];
    if (self) {
        _filePath     = [path retain];
        _title        = [[[path lastPathComponent]
                            stringByDeletingPathExtension] retain];
        _artist       = [@"Unknown Artist" retain];
        _album        = [@"Unknown Album"  retain];
        _genre        = [@"Unknown"        retain];
        _year         = [@""              retain];
        _trackNumber  = 0;
        _duration     = 0;
        _playCount    = 0;
        _rating       = 0;
        _metadataLoaded = NO;
    }
    return self;
}

- (void)dealloc
{
    [_filePath   release];
    [_title      release];
    [_artist     release];
    [_album      release];
    [_genre      release];
    [_year       release];
    [_lastPlayed release];
    [_albumArt   release];
    [_artData    release];
    [super dealloc];
}

static inline NSString *tlStr(const TagLib::String &s) {
    if (s.isEmpty()) return nil;
    return [NSString stringWithUTF8String:s.toCString(true)];
}

static inline TagLib::String nsToTL(NSString *s) {
    if (!s || [s length] == 0) return TagLib::String();
    return TagLib::String([s UTF8String], TagLib::String::UTF8);
}

- (void)loadMetadata
{
    if (_metadataLoaded) return;
    _metadataLoaded = YES;

    // Cache file size so callers don't need repeated stat() calls on the main thread.
    NSDictionary *fattrs = [[NSFileManager defaultManager]
                            attributesOfItemAtPath:_filePath error:nil];
    _fileSize = [fattrs[NSFileSize] unsignedLongLongValue];

    const char *cp = [_filePath fileSystemRepresentation];
    TagLib::FileRef fr(cp, true, TagLib::AudioProperties::Fast);
    if (fr.isNull()) return;

    if (TagLib::Tag *t = fr.tag()) {
        if (NSString *s = tlStr(t->title()))  { [_title  release]; _title  = [s retain]; }
        if (NSString *s = tlStr(t->artist())) { [_artist release]; _artist = [s retain]; }
        if (NSString *s = tlStr(t->album()))  { [_album  release]; _album  = [s retain]; }
        if (NSString *s = tlStr(t->genre()))  { [_genre  release]; _genre  = [s retain]; }
        if (t->year() > 0) {
            [_year release];
            _year = [[NSString stringWithFormat:@"%u", t->year()] retain];
        }
        _trackNumber = t->track();
    }
    if (fr.audioProperties())
        _duration = (NSTimeInterval)fr.audioProperties()->lengthInSeconds();

    // ---------- Per-format album art ----------
    NSString *ext = [[_filePath pathExtension] lowercaseString];
    NSData   *artData = nil;

    if ([ext isEqualToString:@"mp3"]) {
        TagLib::MPEG::File f(cp);
        if (f.ID3v2Tag()) {
            auto &frames = f.ID3v2Tag()->frameListMap()["APIC"];
            if (!frames.isEmpty()) {
                if (auto *p = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(
                        frames.front())) {
                    auto bv = p->picture();
                    artData = [NSData dataWithBytes:bv.data() length:bv.size()];
                }
            }
        }
    }
    else if ([ext isEqualToString:@"flac"]) {
        TagLib::FLAC::File f(cp);
        auto pics = f.pictureList();
        if (!pics.isEmpty()) {
            auto bv = pics.front()->data();
            artData = [NSData dataWithBytes:bv.data() length:bv.size()];
        }
    }
    else if ([ext isEqualToString:@"m4a"] || [ext isEqualToString:@"alac"]
          || [ext isEqualToString:@"m4p"]) {
        TagLib::MP4::File f(cp);
        if (f.tag()) {
            auto item = f.tag()->item("covr");
            if (item.isValid()) {
                auto covers = item.toCoverArtList();
                if (!covers.isEmpty()) {
                    auto bv = covers.front().data();
                    artData = [NSData dataWithBytes:bv.data() length:bv.size()];
                }
            }
        }
    }
    else if ([ext isEqualToString:@"wma"] || [ext isEqualToString:@"asf"]) {
        TagLib::ASF::File f(cp);
        if (f.tag()) {
            auto attrMap = f.tag()->attributeListMap();
            if (attrMap.contains("WM/Picture")) {
                auto &attrs = attrMap["WM/Picture"];
                if (!attrs.isEmpty()) {
                    auto pic = attrs.front().toPicture();
                    auto bv  = pic.picture();
                    artData = [NSData dataWithBytes:bv.data() length:bv.size()];
                }
            }
        }
    }

    if (artData && [artData length] > 0) {
        [_artData release]; _artData = [artData retain];
        NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:artData];
        if (rep) {
            NSImage *img = [[NSImage alloc] initWithSize:[rep size]];
            [img addRepresentation:rep];
            [_albumArt release]; _albumArt = img;
        }
    }
}

- (void)saveMetadata
{
    [self saveMetadataWithTitle:_title artist:_artist album:_album
                          genre:_genre year:_year trackNumber:_trackNumber];
}

- (void)saveMetadataWithTitle:(NSString *)title
                       artist:(NSString *)artist
                        album:(NSString *)album
                        genre:(NSString *)genre
                         year:(NSString *)year
                  trackNumber:(NSUInteger)trackNumber
{
    const char *cp = [_filePath fileSystemRepresentation];
    // readAudioProperties=false — write-only path, skip audio scan for speed
    TagLib::FileRef fr(cp, false);
    if (fr.isNull() || !fr.tag()) return;
    TagLib::Tag *tag = fr.tag();
    tag->setTitle(nsToTL(title));
    tag->setArtist(nsToTL(artist));
    tag->setAlbum(nsToTL(album));
    tag->setGenre(nsToTL(genre));
    tag->setYear(year ? (unsigned int)[year intValue] : 0);
    tag->setTrack((unsigned int)trackNumber);
    fr.save();
}

- (NSString *)durationString
{
    NSUInteger s = (NSUInteger)_duration;
    return [NSString stringWithFormat:@"%lu:%02lu",
            (unsigned long)(s / 60), (unsigned long)(s % 60)];
}

- (NSString *)displayTitle
{
    return (_title && [_title length]) ? _title
        : [[_filePath lastPathComponent] stringByDeletingPathExtension];
}

@end
