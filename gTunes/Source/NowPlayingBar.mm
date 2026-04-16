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

    // ── Info box (centre/right) — contains title, artist, progress, time ──
    _infoBox = [[NSBox alloc] initWithFrame:NSZeroRect];
    [_infoBox setBoxType:NSBoxPrimary];
    [_infoBox setTitlePosition:NSNoTitle];
    [_infoBox setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self addSubview:_infoBox];

    NSView *info = [_infoBox contentView];

    _titleLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_titleLabel setBezeled:NO]; [_titleLabel setDrawsBackground:NO];
    [_titleLabel setEditable:NO]; [_titleLabel setSelectable:NO];
    [_titleLabel setAlignment:NSTextAlignmentCenter];
    [[_titleLabel cell] setFont:[NSFont boldSystemFontOfSize:12]];
    [info addSubview:_titleLabel];

    _artistLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_artistLabel setBezeled:NO]; [_artistLabel setDrawsBackground:NO];
    [_artistLabel setEditable:NO]; [_artistLabel setSelectable:NO];
    [_artistLabel setAlignment:NSTextAlignmentCenter];
    [[_artistLabel cell] setFont:[NSFont systemFontOfSize:11]];
    [[_artistLabel cell] setTextColor:[NSColor grayColor]];
    [info addSubview:_artistLabel];

    _progressSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    [_progressSlider setMinValue:0.0]; [_progressSlider setMaxValue:1.0];
    [_progressSlider setDoubleValue:0];
    [_progressSlider setTarget:self]; [_progressSlider setAction:@selector(_seek:)];
    [info addSubview:_progressSlider];

    _timeLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_timeLabel setBezeled:NO]; [_timeLabel setDrawsBackground:NO];
    [_timeLabel setEditable:NO]; [_timeLabel setSelectable:NO];
    [_timeLabel setAlignment:NSTextAlignmentRight];
    [[_timeLabel cell] setFont:[NSFont systemFontOfSize:10]];
    [info addSubview:_timeLabel];

    _timeLeftLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_timeLeftLabel setBezeled:NO]; [_timeLeftLabel setDrawsBackground:NO];
    [_timeLeftLabel setEditable:NO]; [_timeLeftLabel setSelectable:NO];
    [_timeLeftLabel setAlignment:NSTextAlignmentLeft];
    [[_timeLeftLabel cell] setFont:[NSFont systemFontOfSize:10]];
    [[_timeLeftLabel cell] setTextColor:[NSColor grayColor]];
    [info addSubview:_timeLeftLabel];

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

    // Place the box in the info area.
    // Search field sits at (w - 170); leave a 10px gap before it.
    CGFloat boxW = w - kInfoX - 230;
    if (boxW < 80) boxW = 80;
    [_infoBox setFrame:NSMakeRect(kInfoX, 4, boxW, 52)];

    // Lay out controls inside the box's content view coordinate space.
    // NSBox adds ~5px border on each side; use the content view bounds.
    NSRect inner = [[_infoBox contentView] bounds];
    CGFloat iw   = inner.size.width;
    CGFloat timW = 44;   // width of each time label
    CGFloat slW  = iw - timW * 2 - 8;
    if (slW < 40) slW = 40;

    [_titleLabel     setFrame:NSMakeRect(0,            inner.size.height - 18, iw,  18)];
    [_artistLabel    setFrame:NSMakeRect(0,            inner.size.height - 34, iw,  16)];
    [_timeLabel      setFrame:NSMakeRect(0,            2,                      timW,14)];
    [_progressSlider setFrame:NSMakeRect(timW + 4,     2,                      slW, 12)];
    [_timeLeftLabel  setFrame:NSMakeRect(timW + 4 + slW + 4, 2,               timW,14)];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_prevBtn release]; [_playPauseBtn release]; [_nextBtn release];
    [_progressSlider release]; [_volumeSlider release];
    [_titleLabel release]; [_artistLabel release];
    [_timeLabel release]; [_timeLeftLabel release];
    [_infoBox release];
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
    NSTimeInterval rem = (dur > cur) ? (dur - cur) : 0;
    [_timeLabel setStringValue:[NSString stringWithFormat:@"%lu:%02lu",
        (unsigned long)(cur / 60), (unsigned long)((NSUInteger)cur % 60)]];
    [_timeLeftLabel setStringValue:[NSString stringWithFormat:@"-%lu:%02lu",
        (unsigned long)(rem / 60), (unsigned long)((NSUInteger)rem % 60)]];

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
