// NowPlayingBar.mm
#import "NowPlayingBar.h"
#import "AudioPlayer.h"
#import "MusicTrack.h"

// X coordinate where the dynamic info area begins (right of vol-high icon + gap)
static const CGFloat kInfoX = 316.0;

@interface NowPlayingBar ()
- (void)_layout;
@end

@implementation NowPlayingBar
@synthesize delegate = _delegate;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    // ── Album art ──
    _albumArtView = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 4, 52, 52)];
    [_albumArtView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [self addSubview:_albumArtView];

    // ── Transport buttons (left side) ──
    CGFloat bw = 32, bh = 32, by = (60 - bh) / 2.0;
    CGFloat tx = 62;

    _prevBtn = [[NSButton alloc] initWithFrame:NSMakeRect(tx, by, bw, bh)];
    [_prevBtn setBezelStyle:NSCircularBezelStyle];
    [_prevBtn setTitle:@"◀◀"];
    [_prevBtn setTarget:self]; [_prevBtn setAction:@selector(_prev:)];
    [self addSubview:_prevBtn];

    _playPauseBtn = [[NSButton alloc]
        initWithFrame:NSMakeRect(tx + bw + 4, (60 - 36) / 2.0, 36, 36)];
    [_playPauseBtn setBezelStyle:NSCircularBezelStyle];
    [_playPauseBtn setTitle:@"▶"];
    [_playPauseBtn setTarget:self]; [_playPauseBtn setAction:@selector(_playPause:)];
    [self addSubview:_playPauseBtn];

    _nextBtn = [[NSButton alloc]
        initWithFrame:NSMakeRect(tx + bw + 4 + 36 + 4, by, bw, bh)];
    [_nextBtn setBezelStyle:NSCircularBezelStyle];
    [_nextBtn setTitle:@"▶▶"];
    [_nextBtn setTarget:self]; [_nextBtn setAction:@selector(_next:)];
    [self addSubview:_nextBtn];

    // ── Volume control (immediately right of next button) ──
    // nextBtn right edge = tx + bw + 4 + 36 + 4 + bw = 62+32+4+36+4+32 = 170
    CGFloat volX = 170 + 10;
    CGFloat volIconY = (60 - 14) / 2.0;
    CGFloat volSliderY = (60 - 16) / 2.0;

    NSTextField *volLow = [[NSTextField alloc]
        initWithFrame:NSMakeRect(volX, volIconY, 16, 14)];
    [volLow setBezeled:NO]; [volLow setDrawsBackground:NO];
    [volLow setEditable:NO]; [volLow setSelectable:NO];
    [volLow setStringValue:@"🔈"];
    [[volLow cell] setFont:[NSFont systemFontOfSize:11]];
    [self addSubview:volLow]; [volLow release];

    _volumeSlider = [[NSSlider alloc]
        initWithFrame:NSMakeRect(volX + 18, volSliderY, 90, 16)];
    [_volumeSlider setMinValue:0.0]; [_volumeSlider setMaxValue:1.0];
    [_volumeSlider setDoubleValue:[AudioPlayer sharedPlayer].volume];
    [_volumeSlider setTarget:self]; [_volumeSlider setAction:@selector(_volume:)];
    [self addSubview:_volumeSlider];

    NSTextField *volHigh = [[NSTextField alloc]
        initWithFrame:NSMakeRect(volX + 18 + 90 + 4, volIconY, 16, 14)];
    [volHigh setBezeled:NO]; [volHigh setDrawsBackground:NO];
    [volHigh setEditable:NO]; [volHigh setSelectable:NO];
    [volHigh setStringValue:@"🔊"];
    [[volHigh cell] setFont:[NSFont systemFontOfSize:11]];
    [self addSubview:volHigh]; [volHigh release];

    // ── Song info (centre/right — frames set properly in _layout) ──
    _titleLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_titleLabel setBezeled:NO]; [_titleLabel setDrawsBackground:NO];
    [_titleLabel setEditable:NO]; [_titleLabel setSelectable:NO];
    [_titleLabel setAlignment:NSTextAlignmentCenter];
    [[_titleLabel cell] setFont:[NSFont boldSystemFontOfSize:12]];
    [self addSubview:_titleLabel];

    _artistLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_artistLabel setBezeled:NO]; [_artistLabel setDrawsBackground:NO];
    [_artistLabel setEditable:NO]; [_artistLabel setSelectable:NO];
    [_artistLabel setAlignment:NSTextAlignmentCenter];
    [[_artistLabel cell] setFont:[NSFont systemFontOfSize:11]];
    [[_artistLabel cell] setTextColor:[NSColor grayColor]];
    [self addSubview:_artistLabel];

    _progressSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    [_progressSlider setMinValue:0.0]; [_progressSlider setMaxValue:1.0];
    [_progressSlider setDoubleValue:0];
    [_progressSlider setTarget:self]; [_progressSlider setAction:@selector(_seek:)];
    [self addSubview:_progressSlider];

    _timeLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_timeLabel setBezeled:NO]; [_timeLabel setDrawsBackground:NO];
    [_timeLabel setEditable:NO]; [_timeLabel setSelectable:NO];
    [[_timeLabel cell] setFont:[NSFont systemFontOfSize:10]];
    [self addSubview:_timeLabel];

    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(update)
        name:AudioPlayerTrackChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(update)
        name:AudioPlayerStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(update)
        name:AudioPlayerProgressNotification object:nil];

    return self;
}

// Called whenever the bar's frame changes (initial sizing + window resize).
- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    [self _layout];
}

- (void)_layout
{
    CGFloat w = [self bounds].size.width;
    if (w < kInfoX + 80) return;          // too narrow to lay out

    // Leave ~86px on the right for the time label.
    CGFloat infoW = w - kInfoX - 90;
    if (infoW < 80) infoW = 80;

    [_titleLabel    setFrame:NSMakeRect(kInfoX,              38, infoW, 18)];
    [_artistLabel   setFrame:NSMakeRect(kInfoX,              20, infoW, 16)];
    [_progressSlider setFrame:NSMakeRect(kInfoX,              5, infoW, 12)];
    [_timeLabel     setFrame:NSMakeRect(kInfoX + infoW + 4,  4, 84,    14)];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_prevBtn release]; [_playPauseBtn release]; [_nextBtn release];
    [_progressSlider release]; [_volumeSlider release];
    [_titleLabel release]; [_artistLabel release];
    [_timeLabel release]; [_albumArtView release];
    [super dealloc];
}

- (void)drawRect:(NSRect)r
{
    NSGradient *grad = [[NSGradient alloc]
        initWithStartingColor:[NSColor colorWithCalibratedWhite:0.88 alpha:1.0]
                  endingColor:[NSColor colorWithCalibratedWhite:0.76 alpha:1.0]];
    [grad drawInRect:r angle:270];
    [grad release];
    [[NSColor colorWithCalibratedWhite:0.55 alpha:1.0] set];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(r.origin.x, 0)
                              toPoint:NSMakePoint(NSMaxX(r), 0)];
}

- (void)update
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    MusicTrack *t = p.currentTrack;

    [_titleLabel  setStringValue:t ? [t displayTitle] : @""];
    [_artistLabel setStringValue:t ? (t.artist ?: @"") : @""];

    BOOL playing = (p.state == AudioPlayerStatePlaying);
    [_playPauseBtn setTitle:playing ? @"⏸" : @"▶"];

    if (!_draggingProgress)
        [_progressSlider setDoubleValue:p.progress];

    NSTimeInterval cur = p.currentTime;
    NSTimeInterval dur = t ? t.duration : 0;
    [_timeLabel setStringValue:[NSString stringWithFormat:@"%lu:%02lu / %lu:%02lu",
        (unsigned long)(cur / 60), (unsigned long)((NSUInteger)cur % 60),
        (unsigned long)(dur / 60), (unsigned long)((NSUInteger)dur % 60)]];

    if (t.albumArt) [_albumArtView setImage:t.albumArt];
    else            [_albumArtView setImage:nil];
}

- (void)_playPause:(id)s
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    if (p.state == AudioPlayerStatePlaying)     [p pause];
    else if (p.state == AudioPlayerStatePaused) [p resume];
    else [_delegate nowPlayingBarPlayRequested:self];
}
- (void)_prev:(id)s { [[AudioPlayer sharedPlayer] previous]; }
- (void)_next:(id)s
{
    AudioPlayer *p = [AudioPlayer sharedPlayer];
    if (p.state == AudioPlayerStateStopped)
        [_delegate nowPlayingBarPlayRequested:self];
    else
        [p next];
}
- (void)_seek:(id)s
{
    [[AudioPlayer sharedPlayer] seekToPosition:[_progressSlider doubleValue]];
}
- (void)_volume:(id)s
{
    [AudioPlayer sharedPlayer].volume = (float)[_volumeSlider doubleValue];
}

@end
