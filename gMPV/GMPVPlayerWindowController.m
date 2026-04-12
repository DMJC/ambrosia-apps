#import "GMPVPlayerWindowController.h"

#import "GMPVMPVPlayer.h"
#import "GMPVVideoView.h"

@interface GMPVPlayerWindowController ()

@property (nonatomic, strong) GMPVVideoView *videoView;
@property (nonatomic, strong, readwrite) GMPVMPVPlayer *player;
@property (nonatomic, strong) NSSlider *timelineSlider;
@property (nonatomic, strong) NSSlider *volumeSlider;
@property (nonatomic, strong) NSTextField *statusLabel;

@end

@implementation GMPVPlayerWindowController

- (instancetype)init
{
  NSRect frame = NSMakeRect(160, 120, 1280, 780);
  NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:(NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];

  self = [super initWithWindow:window];
  if (self)
    {
      [window setTitle:@"gMPV"]; 
      [self buildInterface];
      _player = [[GMPVMPVPlayer alloc] initWithVideoView:_videoView];
      [self updateStatus:@"Ready"]; 
    }
  return self;
}

- (void)buildInterface
{
  NSView *contentView = self.window.contentView;

  self.videoView = [[GMPVVideoView alloc] initWithFrame:NSZeroRect];
  self.videoView.translatesAutoresizingMaskIntoConstraints = NO;

  NSView *timelineContainer = [[NSView alloc] initWithFrame:NSZeroRect];
  timelineContainer.translatesAutoresizingMaskIntoConstraints = NO;

  NSView *controlsContainer = [[NSView alloc] initWithFrame:NSZeroRect];
  controlsContainer.translatesAutoresizingMaskIntoConstraints = NO;

  [contentView addSubview:self.videoView];
  [contentView addSubview:timelineContainer];
  [contentView addSubview:controlsContainer];

  self.timelineSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
  self.timelineSlider.translatesAutoresizingMaskIntoConstraints = NO;
  self.timelineSlider.minValue = 0.0;
  self.timelineSlider.maxValue = 100.0;
  self.timelineSlider.target = self;
  self.timelineSlider.action = @selector(onSeek:);
  [timelineContainer addSubview:self.timelineSlider];

  NSButton *rewindButton = [self controlButtonWithTitle:@"◀◀" action:@selector(onRewind:)];
  NSButton *playPauseButton = [self controlButtonWithTitle:@"▶" action:@selector(onPlayPause:)];
  NSButton *forwardButton = [self controlButtonWithTitle:@"▶▶" action:@selector(onForward:)];

  self.volumeSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
  self.volumeSlider.translatesAutoresizingMaskIntoConstraints = NO;
  self.volumeSlider.minValue = 0.0;
  self.volumeSlider.maxValue = 100.0;
  self.volumeSlider.doubleValue = 80.0;
  self.volumeSlider.target = self;
  self.volumeSlider.action = @selector(onVolume:);

  NSButton *utilityButton = [self controlButtonWithTitle:@"☰" action:@selector(onUtilityMenu:)];

  self.statusLabel = [NSTextField labelWithString:@"Ready"]; 
  self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

  [controlsContainer addSubview:rewindButton];
  [controlsContainer addSubview:playPauseButton];
  [controlsContainer addSubview:forwardButton];
  [controlsContainer addSubview:self.volumeSlider];
  [controlsContainer addSubview:utilityButton];
  [controlsContainer addSubview:self.statusLabel];

  [NSLayoutConstraint activateConstraints:@[
    [self.videoView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
    [self.videoView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
    [self.videoView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],

    [timelineContainer.topAnchor constraintEqualToAnchor:self.videoView.bottomAnchor],
    [timelineContainer.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
    [timelineContainer.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
    [timelineContainer.heightAnchor constraintEqualToConstant:32.0],

    [controlsContainer.topAnchor constraintEqualToAnchor:timelineContainer.bottomAnchor],
    [controlsContainer.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:8.0],
    [controlsContainer.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-8.0],
    [controlsContainer.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-8.0],
    [controlsContainer.heightAnchor constraintEqualToConstant:42.0],

    [self.videoView.heightAnchor constraintGreaterThanOrEqualToConstant:360.0],

    [self.timelineSlider.leadingAnchor constraintEqualToAnchor:timelineContainer.leadingAnchor constant:12.0],
    [self.timelineSlider.trailingAnchor constraintEqualToAnchor:timelineContainer.trailingAnchor constant:-12.0],
    [self.timelineSlider.centerYAnchor constraintEqualToAnchor:timelineContainer.centerYAnchor],

    [playPauseButton.centerXAnchor constraintEqualToAnchor:controlsContainer.centerXAnchor],
    [playPauseButton.centerYAnchor constraintEqualToAnchor:controlsContainer.centerYAnchor],

    [rewindButton.trailingAnchor constraintEqualToAnchor:playPauseButton.leadingAnchor constant:-8.0],
    [rewindButton.centerYAnchor constraintEqualToAnchor:playPauseButton.centerYAnchor],

    [forwardButton.leadingAnchor constraintEqualToAnchor:playPauseButton.trailingAnchor constant:8.0],
    [forwardButton.centerYAnchor constraintEqualToAnchor:playPauseButton.centerYAnchor],

    [self.volumeSlider.leadingAnchor constraintEqualToAnchor:controlsContainer.leadingAnchor constant:24.0],
    [self.volumeSlider.widthAnchor constraintEqualToConstant:220.0],
    [self.volumeSlider.centerYAnchor constraintEqualToAnchor:controlsContainer.centerYAnchor],

    [utilityButton.trailingAnchor constraintEqualToAnchor:controlsContainer.trailingAnchor constant:-12.0],
    [utilityButton.centerYAnchor constraintEqualToAnchor:controlsContainer.centerYAnchor],

    [self.statusLabel.trailingAnchor constraintEqualToAnchor:utilityButton.leadingAnchor constant:-16.0],
    [self.statusLabel.centerYAnchor constraintEqualToAnchor:controlsContainer.centerYAnchor]
  ]];
}

- (NSButton *)controlButtonWithTitle:(NSString *)title action:(SEL)action
{
  NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  button.bezelStyle = NSBezelStyleTexturedRounded;
  return button;
}

- (void)openFiles
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = YES;

  if ([panel runModal] == NSModalResponseOK)
    {
      NSMutableArray<NSString *> *paths = [NSMutableArray array];
      for (NSURL *url in panel.URLs)
        {
          [paths addObject:url.path ?: url.absoluteString];
        }
      [self.player loadPaths:paths];
      [self updateStatus:[NSString stringWithFormat:@"Loaded %@", paths.firstObject.lastPathComponent ?: @"file"]];
    }
}

- (void)openURLPrompt
{
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"Open URL / Stream";
  alert.informativeText = @"Enter a network URL or stream location.";

  NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 24)];
  input.stringValue = @"https://";
  alert.accessoryView = input;

  [alert addButtonWithTitle:@"Open"];
  [alert addButtonWithTitle:@"Cancel"];

  if ([alert runModal] == NSAlertFirstButtonReturn)
    {
      [self.player loadURLString:input.stringValue];
      [self updateStatus:[NSString stringWithFormat:@"Streaming %@", input.stringValue]];
    }
}

- (void)openTVStream
{
  NSString *tvURL = @"tv://";
  [self.player loadURLString:tvURL];
  [self updateStatus:@"Opening TV source (tv://)"];
}

- (void)updateStatus:(NSString *)status
{
  self.statusLabel.stringValue = status;
}

- (void)onSeek:(NSSlider *)sender
{
  [self.player seekToRelativeSeconds:sender.doubleValue];
}

- (void)onRewind:(id)sender
{
  (void)sender;
  double nextValue = MAX(0.0, self.timelineSlider.doubleValue - 10.0);
  self.timelineSlider.doubleValue = nextValue;
  [self.player seekToRelativeSeconds:nextValue];
}

- (void)onPlayPause:(id)sender
{
  (void)sender;
  [self.player togglePlayback];
}

- (void)onForward:(id)sender
{
  (void)sender;
  double nextValue = MIN(100.0, self.timelineSlider.doubleValue + 10.0);
  self.timelineSlider.doubleValue = nextValue;
  [self.player seekToRelativeSeconds:nextValue];
}

- (void)onVolume:(NSSlider *)sender
{
  [self.player setVolume:(float)sender.doubleValue];
}

- (void)onUtilityMenu:(id)sender
{
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Playback Options"];

  [menu addItemWithTitle:@"Video" action:nil keyEquivalent:@""];
  [menu addItemWithTitle:@"Audio" action:nil keyEquivalent:@""];
  [menu addItemWithTitle:@"Subtitles" action:nil keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Fullscreen" action:@selector(toggleFullScreen:) keyEquivalent:@""];

  NSButton *button = (NSButton *)sender;
  NSRect frame = button.bounds;
  [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(NSMinX(frame), NSMaxY(frame)) inView:button];
}

@end
