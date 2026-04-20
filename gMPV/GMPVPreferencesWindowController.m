#import "GMPVPreferencesWindowController.h"

static NSString * const kAudioLanguage    = @"AudioLanguage";
static NSString * const kSubtitleLanguage = @"SubtitleLanguage";
static NSString * const kDefaultVolume    = @"DefaultVolume";
static NSString * const kAudioOutput      = @"AudioOutput";
static NSString * const kHardwareDecoding = @"HardwareDecoding";
static NSString * const kDeinterlace      = @"Deinterlace";

@interface GMPVPreferencesWindowController ()
{
  NSTabView    *_tabView;

  /* Language */
  NSTextField  *_audioLanguageField;
  NSTextField  *_subtitleLanguageField;

  /* Sound */
  NSSlider     *_volumeSlider;
  NSTextField  *_volumeValueLabel;
  NSPopUpButton *_audioOutputPopup;

  /* Video */
  NSPopUpButton *_hwdecPopup;
  NSButton      *_deinterlaceCheck;
}
@end

@implementation GMPVPreferencesWindowController

+ (NSString *)preferencesPath
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                       NSUserDomainMask,
                                                       YES);
  NSString *libDir = [paths firstObject];
  if (libDir == nil)
    libDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];
  NSString *prefsDir = [libDir stringByAppendingPathComponent:@"Preferences"];
  return [prefsDir stringByAppendingPathComponent:@"gMPV.plist"];
}

+ (NSDictionary *)loadPreferences
{
  NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:[self preferencesPath]];
  return d ? d : @{};
}

- (instancetype)init
{
  NSUInteger styleMask = NSTitledWindowMask | NSClosableWindowMask;
#ifdef NSWindowStyleMaskTitled
  styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
#endif

  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 360)
                                                  styleMask:styleMask
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
  self = [super initWithWindow:window];
  if (self)
    {
      [window disableCursorRects];
      [window setTitle:@"Preferences"];
      [self buildInterface];
      [self loadCurrentValues];
      [window center];
    }
  return self;
}

- (void)buildInterface
{
  NSView *content = [[self window] contentView];

  /* Tab view leaves 48 px at the bottom for the button row */
  _tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(8, 48, 484, 304)];

  NSTabViewItem *langItem  = [[NSTabViewItem alloc] initWithIdentifier:@"language"];
  NSTabViewItem *soundItem = [[NSTabViewItem alloc] initWithIdentifier:@"sound"];
  NSTabViewItem *videoItem = [[NSTabViewItem alloc] initWithIdentifier:@"video"];

  [langItem  setLabel:@"Language"];
  [soundItem setLabel:@"Sound"];
  [videoItem setLabel:@"Video"];

  [langItem  setView:[self buildLanguageView]];
  [soundItem setView:[self buildSoundView]];
  [videoItem setView:[self buildVideoView]];

  [_tabView addTabViewItem:langItem];
  [_tabView addTabViewItem:soundItem];
  [_tabView addTabViewItem:videoItem];

  [content addSubview:_tabView];

  /* Cancel / Save buttons */
  NSButton *cancelBtn = [self pushButtonWithTitle:@"Cancel"
                                           action:@selector(cancel:)
                                            frame:NSMakeRect(296, 10, 90, 28)];
  NSButton *saveBtn   = [self pushButtonWithTitle:@"Save"
                                           action:@selector(save:)
                                            frame:NSMakeRect(398, 10, 90, 28)];
  [content addSubview:cancelBtn];
  [content addSubview:saveBtn];
}

/* ── Language ── */
- (NSView *)buildLanguageView
{
  NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 484, 270)];
  CGFloat y = 210, x = 16, lw = 150, fw = 270, rh = 24;

  [v addSubview:[self labelWithTitle:@"Audio Language:"
                               frame:NSMakeRect(x, y, lw, rh)]];
  _audioLanguageField = [self editableFieldWithFrame:NSMakeRect(x + lw + 8, y, fw, rh)];
  [v addSubview:_audioLanguageField];

  y -= 40;
  [v addSubview:[self labelWithTitle:@"Subtitle Language:"
                               frame:NSMakeRect(x, y, lw, rh)]];
  _subtitleLanguageField = [self editableFieldWithFrame:NSMakeRect(x + lw + 8, y, fw, rh)];
  [v addSubview:_subtitleLanguageField];

  return v;
}

/* ── Sound ── */
- (NSView *)buildSoundView
{
  NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 484, 270)];
  CGFloat y = 210, x = 16, lw = 150, rh = 24;

  [v addSubview:[self labelWithTitle:@"Default Volume:"
                               frame:NSMakeRect(x, y, lw, rh)]];
  _volumeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(x + lw + 8, y, 190, rh)];
  _volumeSlider.minValue = 0;
  _volumeSlider.maxValue = 100;
  _volumeSlider.target = self;
  _volumeSlider.action = @selector(volumeSliderChanged:);
  [v addSubview:_volumeSlider];
  _volumeValueLabel = [self labelWithTitle:@"80"
                                     frame:NSMakeRect(x + lw + 206, y, 44, rh)];
  [v addSubview:_volumeValueLabel];

  y -= 40;
  [v addSubview:[self labelWithTitle:@"Audio Output:"
                               frame:NSMakeRect(x, y, lw, rh)]];
  _audioOutputPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(x + lw + 8, y, 190, rh)
                                                 pullsDown:NO];
  [_audioOutputPopup addItemsWithTitles:@[@"auto", @"pulse", @"alsa", @"jack"]];
  [v addSubview:_audioOutputPopup];

  return v;
}

/* ── Video ── */
- (NSView *)buildVideoView
{
  NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 484, 270)];
  CGFloat y = 210, x = 16, lw = 150, rh = 24;

  [v addSubview:[self labelWithTitle:@"Hardware Decoding:"
                               frame:NSMakeRect(x, y, lw, rh)]];
  _hwdecPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(x + lw + 8, y, 190, rh)
                                           pullsDown:NO];
  [_hwdecPopup addItemsWithTitles:@[@"auto", @"no", @"vaapi", @"nvdec", @"vdpau"]];
  [v addSubview:_hwdecPopup];

  y -= 40;
  _deinterlaceCheck = [[NSButton alloc] initWithFrame:NSMakeRect(x, y, 280, rh)];
  [_deinterlaceCheck setTitle:@"Enable Deinterlace"];
#ifdef NSButtonTypeSwitch
  [_deinterlaceCheck setButtonType:NSButtonTypeSwitch];
#else
  [_deinterlaceCheck setButtonType:NSSwitchButton];
#endif
  [v addSubview:_deinterlaceCheck];

  return v;
}

/* ── Value loading ── */
- (void)loadCurrentValues
{
  NSDictionary *p = [[self class] loadPreferences];

  _audioLanguageField.stringValue    = p[kAudioLanguage]    ?: @"en";
  _subtitleLanguageField.stringValue = p[kSubtitleLanguage] ?: @"en";

  double vol = p[kDefaultVolume] ? [p[kDefaultVolume] doubleValue] : 80.0;
  _volumeSlider.doubleValue = vol;
  _volumeValueLabel.stringValue = [NSString stringWithFormat:@"%.0f", vol];

  [self selectPopup:_audioOutputPopup value:p[kAudioOutput] ?: @"auto"];
  [self selectPopup:_hwdecPopup       value:p[kHardwareDecoding] ?: @"auto"];

  BOOL deint = p[kDeinterlace] ? [p[kDeinterlace] boolValue] : NO;
#ifdef NSControlStateValueOn
  [_deinterlaceCheck setState:deint ? NSControlStateValueOn : NSControlStateValueOff];
#else
  [_deinterlaceCheck setState:deint ? NSOnState : NSOffState];
#endif
}

- (void)selectPopup:(NSPopUpButton *)popup value:(NSString *)value
{
  [popup selectItemWithTitle:value];
  if ([popup selectedItem] == nil)
    [popup selectItemAtIndex:0];
}

/* ── Actions ── */
- (void)volumeSliderChanged:(NSSlider *)sender
{
  _volumeValueLabel.stringValue = [NSString stringWithFormat:@"%.0f", sender.doubleValue];
}

- (void)save:(id)sender
{
  (void)sender;

  NSString *ao    = [[_audioOutputPopup selectedItem] title] ?: @"auto";
  NSString *hwdec = [[_hwdecPopup selectedItem] title]       ?: @"auto";

#ifdef NSControlStateValueOn
  BOOL deint = (_deinterlaceCheck.state == NSControlStateValueOn);
#else
  BOOL deint = (_deinterlaceCheck.state == NSOnState);
#endif

  NSDictionary *prefs = @{
    kAudioLanguage:    _audioLanguageField.stringValue,
    kSubtitleLanguage: _subtitleLanguageField.stringValue,
    kDefaultVolume:    @(_volumeSlider.doubleValue),
    kAudioOutput:      ao,
    kHardwareDecoding: hwdec,
    kDeinterlace:      @(deint),
  };

  NSString *path = [[self class] preferencesPath];
  NSString *dir  = [path stringByDeletingLastPathComponent];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
  [prefs writeToFile:path atomically:YES];
  [[self window] orderOut:nil];
}

- (void)cancel:(id)sender
{
  (void)sender;
  [[self window] orderOut:nil];
}

/* ── View helpers ── */
- (NSTextField *)labelWithTitle:(NSString *)title frame:(NSRect)frame
{
  NSTextField *tf = [[NSTextField alloc] initWithFrame:frame];
  [tf setStringValue:title];
  [tf setBezeled:NO];
  [tf setDrawsBackground:NO];
  [tf setEditable:NO];
  [tf setSelectable:NO];
  return tf;
}

- (NSTextField *)editableFieldWithFrame:(NSRect)frame
{
  NSTextField *tf = [[NSTextField alloc] initWithFrame:frame];
  [tf setBezeled:YES];
  [tf setEditable:YES];
  return tf;
}

- (NSButton *)pushButtonWithTitle:(NSString *)title action:(SEL)action frame:(NSRect)frame
{
  NSButton *btn = [[NSButton alloc] initWithFrame:frame];
  [btn setTitle:title];
  [btn setBezelStyle:NSRoundedBezelStyle];
  [btn setTarget:self];
  [btn setAction:action];
  return btn;
}

@end
