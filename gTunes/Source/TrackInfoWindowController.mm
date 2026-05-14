// TrackInfoWindowController.mm
#import "TrackInfoWindowController.h"
#import "MusicLibrary.h"

@interface TrackInfoWindowController ()
- (void)_buildWindow;
- (NSTextField *)_makeLabelWithTitle:(NSString *)title frame:(NSRect)f;
- (NSTextField *)_makeFieldWithFrame:(NSRect)f;
- (void)_populateFields;
- (void)_applyEnabledFieldsToTracks:(NSArray *)tracks;
- (void)_ok:(id)sender;
- (void)_cancel:(id)sender;
- (void)_syncToFiles:(id)sender;
@end

// Returns the common string value for a key across all tracks, or nil if values differ.
// For trackNumber (primitive NSUInteger), KVC boxes it as NSNumber.
static NSString *commonStringForKey(NSArray *tracks, NSString *key)
{
    NSString *common = nil;
    BOOL first = YES;
    for (MusicTrack *t in tracks) {
        NSString *val;
        if ([key isEqualToString:@"trackNumber"]) {
            NSUInteger n = t.trackNumber;
            val = n > 0 ? [NSString stringWithFormat:@"%lu", (unsigned long)n] : @"";
        } else {
            id raw = [t valueForKey:key];
            val = [raw isKindOfClass:[NSString class]] ? (NSString *)raw : @"";
        }
        if (first) { common = val; first = NO; }
        else if (![val isEqualToString:common]) return nil;  // nil == differs
    }
    return common ?: @"";
}

@implementation TrackInfoWindowController

- (id)initWithTracks:(NSArray *)tracks
{
    self = [super initWithWindow:nil];
    if (self) {
        _tracks = [tracks retain];
        [self _buildWindow];
        [self _populateFields];
    }
    return self;
}

- (void)dealloc
{
    [_tracks release];
    [_pathField release];
    [_titleField release]; [_artistField release]; [_albumField release];
    [_genreField release]; [_yearField release];   [_trackNumField release];
    [_syncButton release]; [_okButton release];    [_cancelButton release];
    [super dealloc];
}

// ──────────── Window construction ────────────

- (void)_buildWindow
{
    // Window: 500 × 268 content rect (GNUstep bottom-left origin)
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 500, 268)
                  styleMask:NSTitledWindowMask | NSClosableWindowMask
                    backing:NSBackingStoreBuffered
                      defer:NO];
    [win setTitle:@"Track Info"];
    [win center];
    [self setWindow:win];
    [win release];

    NSView *cv = [win contentView];

    // ── Path / selection info (y=180, h=56) ──
    NSTextField *pathLbl = [self _makeLabelWithTitle:@"File"
                                               frame:NSMakeRect(12, 204, 56, 22)];
    [cv addSubview:pathLbl];

    _pathField = [[NSTextField alloc] initWithFrame:NSMakeRect(72, 178, 416, 48)];
    [_pathField setBezeled:NO]; [_pathField setDrawsBackground:NO];
    [_pathField setEditable:NO]; [_pathField setSelectable:YES];
    [[_pathField cell] setFont:[NSFont systemFontOfSize:11]];
    [[_pathField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [[_pathField cell] setScrollable:NO];
    [_pathField setTextColor:[NSColor darkGrayColor]];
    [cv addSubview:_pathField];

    // ── Title (y=148, h=22) ──
    [cv addSubview:[self _makeLabelWithTitle:@"Title"
                                       frame:NSMakeRect(12, 148, 56, 22)]];
    _titleField = [[self _makeFieldWithFrame:NSMakeRect(72, 148, 416, 22)] retain];
    [cv addSubview:_titleField];

    // ── Artist (y=118) ──
    [cv addSubview:[self _makeLabelWithTitle:@"Artist"
                                       frame:NSMakeRect(12, 118, 56, 22)]];
    _artistField = [[self _makeFieldWithFrame:NSMakeRect(72, 118, 416, 22)] retain];
    [cv addSubview:_artistField];

    // ── Album (y=88) ──
    [cv addSubview:[self _makeLabelWithTitle:@"Album"
                                       frame:NSMakeRect(12, 88, 56, 22)]];
    _albumField = [[self _makeFieldWithFrame:NSMakeRect(72, 88, 416, 22)] retain];
    [cv addSubview:_albumField];

    // ── Genre / Year / Track # (y=58) ──
    [cv addSubview:[self _makeLabelWithTitle:@"Genre"
                                       frame:NSMakeRect(12, 58, 50, 22)]];
    _genreField = [[self _makeFieldWithFrame:NSMakeRect(64, 58, 144, 22)] retain];
    [cv addSubview:_genreField];

    [cv addSubview:[self _makeLabelWithTitle:@"Year"
                                       frame:NSMakeRect(216, 58, 36, 22)]];
    _yearField = [[self _makeFieldWithFrame:NSMakeRect(254, 58, 64, 22)] retain];
    [cv addSubview:_yearField];

    [cv addSubview:[self _makeLabelWithTitle:@"Track #"
                                       frame:NSMakeRect(326, 58, 56, 22)]];
    _trackNumField = [[self _makeFieldWithFrame:NSMakeRect(384, 58, 104, 22)] retain];
    [cv addSubview:_trackNumField];

    // ── Separator (y=44, h=1) ──
    NSBox *sep = [[[NSBox alloc] initWithFrame:NSMakeRect(0, 44, 500, 1)] autorelease];
    [sep setBoxType:NSBoxSeparator];
    [cv addSubview:sep];

    // ── Buttons (y=10, h=26) ──
    // Sync to Files — left side
    _syncButton = [[NSButton alloc] initWithFrame:NSMakeRect(12, 10, 110, 26)];
    [_syncButton setTitle:@"Sync to Files"];
    [_syncButton setButtonType:NSMomentaryPushInButton];
    [_syncButton setBezelStyle:NSRoundedBezelStyle];
    [_syncButton setTarget:self];
    [_syncButton setAction:@selector(_syncToFiles:)];
    [cv addSubview:_syncButton];

    // Cancel — second from right
    _cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(312, 10, 84, 26)];
    [_cancelButton setTitle:@"Cancel"];
    [_cancelButton setButtonType:NSMomentaryPushInButton];
    [_cancelButton setBezelStyle:NSRoundedBezelStyle];
    [_cancelButton setKeyEquivalent:@"\033"];
    [_cancelButton setTarget:self];
    [_cancelButton setAction:@selector(_cancel:)];
    [cv addSubview:_cancelButton];

    // OK — rightmost
    _okButton = [[NSButton alloc] initWithFrame:NSMakeRect(404, 10, 84, 26)];
    [_okButton setTitle:@"OK"];
    [_okButton setButtonType:NSMomentaryPushInButton];
    [_okButton setBezelStyle:NSRoundedBezelStyle];
    [_okButton setKeyEquivalent:@"\r"];
    [_okButton setTarget:self];
    [_okButton setAction:@selector(_ok:)];
    [cv addSubview:_okButton];
}

// ──────────── Helpers ────────────

- (NSTextField *)_makeLabelWithTitle:(NSString *)title frame:(NSRect)f
{
    NSTextField *tf = [[[NSTextField alloc] initWithFrame:f] autorelease];
    [tf setStringValue:title];
    [tf setBezeled:NO]; [tf setDrawsBackground:NO];
    [tf setEditable:NO]; [tf setSelectable:NO];
    [[tf cell] setFont:[NSFont systemFontOfSize:12]];
    [[tf cell] setAlignment:NSTextAlignmentRight];
    return tf;
}

- (NSTextField *)_makeFieldWithFrame:(NSRect)f
{
    NSTextField *tf = [[[NSTextField alloc] initWithFrame:f] autorelease];
    [[tf cell] setFont:[NSFont systemFontOfSize:12]];
    return tf;
}

// ──────────── Population & Application ────────────

- (void)_populateFields
{
    if ([_tracks count] == 1) {
        MusicTrack *t = _tracks[0];
        [[self window] setTitle:@"Track Info"];
        [_pathField setStringValue:t.filePath ?: @""];

        [_titleField    setStringValue:t.title      ?: @""];
        [_artistField   setStringValue:t.artist     ?: @""];
        [_albumField    setStringValue:t.album      ?: @""];
        [_genreField    setStringValue:t.genre      ?: @""];
        [_yearField     setStringValue:t.year       ?: @""];
        [_trackNumField setStringValue:t.trackNumber > 0
            ? [NSString stringWithFormat:@"%lu", (unsigned long)t.trackNumber] : @""];
    } else {
        [[self window] setTitle:[NSString stringWithFormat:
            @"Track Info — %lu tracks", (unsigned long)[_tracks count]]];
        [_pathField setStringValue:[NSString stringWithFormat:
            @"%lu tracks selected", (unsigned long)[_tracks count]]];

        // For each field: show common value or disable + placeholder
        struct { NSString *key; NSTextField *field; } fields[] = {
            { @"title",       _titleField    },
            { @"artist",      _artistField   },
            { @"album",       _albumField    },
            { @"genre",       _genreField    },
            { @"year",        _yearField     },
            { @"trackNumber", _trackNumField },
        };
        for (NSUInteger i = 0; i < 6; i++) {
            NSString *common = commonStringForKey(_tracks, fields[i].key);
            if (common) {
                [fields[i].field setStringValue:common];
                [fields[i].field setEnabled:YES];
            } else {
                [fields[i].field setStringValue:@""];
                [[fields[i].field cell] setPlaceholderString:@"Multiple Values"];
                [fields[i].field setEnabled:NO];
            }
        }
    }
}

// Writes enabled field values into the given track objects (in memory only).
- (void)_applyEnabledFieldsToTracks:(NSArray *)tracks
{
    NSString *title   = [_titleField    isEnabled] ? [_titleField    stringValue] : nil;
    NSString *artist  = [_artistField   isEnabled] ? [_artistField   stringValue] : nil;
    NSString *album   = [_albumField    isEnabled] ? [_albumField    stringValue] : nil;
    NSString *genre   = [_genreField    isEnabled] ? [_genreField    stringValue] : nil;
    NSString *year    = [_yearField     isEnabled] ? [_yearField     stringValue] : nil;
    BOOL     trackEnabled = [_trackNumField isEnabled];
    NSUInteger trackNum = trackEnabled
        ? (NSUInteger)[[_trackNumField stringValue] integerValue] : 0;

    for (MusicTrack *t in tracks) {
        if (title)        t.title       = title;
        if (artist)       t.artist      = artist;
        if (album)        t.album       = album;
        if (genre)        t.genre       = genre;
        if (year)         t.year        = year;
        if (trackEnabled) t.trackNumber = trackNum;
    }
}

// ──────────── Button Actions ────────────

- (void)_ok:(id)sender
{
    [self _applyEnabledFieldsToTracks:_tracks];
    [[MusicLibrary sharedLibrary] save];
    [NSApp stopModal];
    [self close];
}

- (void)_cancel:(id)sender
{
    [NSApp stopModal];
    [self close];
}

// Sync to Files: write current field values to the actual audio file tags using
// TagLib.  Does NOT modify the stored MusicTrack properties or close the window.
// The library is saved so play counts and any other in-flight changes persist.
- (void)_syncToFiles:(id)sender
{
    NSString *title   = [_titleField    isEnabled] ? [_titleField    stringValue] : nil;
    NSString *artist  = [_artistField   isEnabled] ? [_artistField   stringValue] : nil;
    NSString *album   = [_albumField    isEnabled] ? [_albumField    stringValue] : nil;
    NSString *genre   = [_genreField    isEnabled] ? [_genreField    stringValue] : nil;
    NSString *year    = [_yearField     isEnabled] ? [_yearField     stringValue] : nil;
    BOOL     trackEnabled = [_trackNumField isEnabled];
    NSUInteger trackNum = trackEnabled
        ? (NSUInteger)[[_trackNumField stringValue] integerValue] : 0;

    for (MusicTrack *t in _tracks) {
        [t saveMetadataWithTitle:  title  ?: t.title
                          artist: artist ?: t.artist
                           album: album  ?: t.album
                           genre: genre  ?: t.genre
                            year: year   ?: t.year
                     trackNumber: trackEnabled ? trackNum : t.trackNumber];
    }
    [[MusicLibrary sharedLibrary] save];
    // Window stays open so the user can continue editing or click OK.
}

@end
