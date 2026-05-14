// TrackInfoWindowController.h
#import <AppKit/AppKit.h>
#import "MusicTrack.h"

@interface TrackInfoWindowController : NSWindowController
{
    NSArray       *_tracks;

    // Top: path (single) or "N tracks selected" label
    NSTextField   *_pathField;

    // Editable metadata fields
    NSTextField   *_titleField;
    NSTextField   *_artistField;
    NSTextField   *_albumField;
    NSTextField   *_genreField;
    NSTextField   *_yearField;
    NSTextField   *_trackNumField;

    // Buttons
    NSButton      *_syncButton;
    NSButton      *_okButton;
    NSButton      *_cancelButton;
}

- (id)initWithTracks:(NSArray *)tracks;

@end
