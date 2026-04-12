#import "GMPVPlayerWindowController.h"

#import "GMPVMPVPlayer.h"
#import "GMPVVideoView.h"

@interface GMPVPlayerWindowController ()

@property (nonatomic, strong) GMPVVideoView *videoView;
@property (nonatomic, strong, readwrite) GMPVMPVPlayer *player;
@property (nonatomic, strong) NSView *timelineContainer;
@property (nonatomic, strong) NSView *controlsContainer;
@property (nonatomic, strong) NSSlider *timelineSlider;
@property (nonatomic, strong) NSSlider *volumeSlider;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *rewindButton;
@property (nonatomic, strong) NSButton *playPauseButton;
@property (nonatomic, strong) NSButton *forwardButton;
@property (nonatomic, strong) NSButton *utilityButton;
@property (nonatomic, assign) NSInteger urlPromptResult;

@end

@implementation GMPVPlayerWindowController

- (instancetype)init
{
  NSRect frame = NSMakeRect(160, 120, 1280, 780);

  NSUInteger styleMask = NSTitledWindowMask |
                         NSClosableWindowMask |
                         NSMiniaturizableWindowMask |
                         NSResizableWindowMask;

#ifdef NSWindowStyleMaskTitled
  styleMask = NSWindowStyleMaskTitled |
              NSWindowStyleMaskClosable |
              NSWindowStyleMaskMiniaturizable |
              NSWindowStyleMaskResizable;
#endif

  NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:styleMask
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];

  self = [super initWithWindow:window];
  if (self)
    {
      [window setTitle:@"gMPV"];
      [self buildInterface];
      _player = [[GMPVMPVPlayer alloc] initWithVideoView:_videoView];
      [self updateStatus:@"Ready"];

      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(windowDidResize:)
                                                   name:NSWindowDidResizeNotification
                                                 object:window];
      [self layoutInterface];
    }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidResize:(NSNotification *)notification
{
  (void)notification;
  [self layoutInterface];
}

- (void)buildInterface
{
  NSView *contentView = self.window.contentView;

  self.videoView = [[GMPVVideoView alloc] initWithFrame:NSZeroRect];
  self.timelineContainer = [[NSView alloc] initWithFrame:NSZeroRect];
  self.controlsContainer = [[NSView alloc] initWithFrame:NSZeroRect];

  [contentView addSubview:self.videoView];
  [contentView addSubview:self.timelineContainer];
  [contentView addSubview:self.controlsContainer];

  self.timelineSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
  self.timelineSlider.minValue = 0.0;
  self.timelineSlider.maxValue = 100.0;
  self.timelineSlider.target = self;
  self.timelineSlider.action = @selector(onSeek:);
  [self.timelineContainer addSubview:self.timelineSlider];

  self.rewindButton = [self controlButtonWithTitle:@"◀◀" action:@selector(onRewind:)];
  self.playPauseButton = [self controlButtonWithTitle:@"▶" action:@selector(onPlayPause:)];
  self.forwardButton = [self controlButtonWithTitle:@"▶▶" action:@selector(onForward:)];

  self.volumeSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
  self.volumeSlider.minValue = 0.0;
  self.volumeSlider.maxValue = 100.0;
  self.volumeSlider.doubleValue = 80.0;
  self.volumeSlider.target = self;
  self.volumeSlider.action = @selector(onVolume:);

  self.utilityButton = [self controlButtonWithTitle:@"☰" action:@selector(onUtilityMenu:)];

  self.statusLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
  [self.statusLabel setBezeled:NO];
  [self.statusLabel setDrawsBackground:NO];
  [self.statusLabel setEditable:NO];
  [self.statusLabel setSelectable:NO];
  [self.statusLabel setStringValue:@"Ready"];

  [self.controlsContainer addSubview:self.rewindButton];
  [self.controlsContainer addSubview:self.playPauseButton];
  [self.controlsContainer addSubview:self.forwardButton];
  [self.controlsContainer addSubview:self.volumeSlider];
  [self.controlsContainer addSubview:self.utilityButton];
  [self.controlsContainer addSubview:self.statusLabel];
}

- (void)layoutInterface
{
  NSView *contentView = self.window.contentView;
  NSRect bounds = [contentView bounds];

  CGFloat controlsHeight = 42.0;
  CGFloat timelineHeight = 32.0;
  NSRect controlsFrame = NSMakeRect(0.0, 0.0, NSWidth(bounds), controlsHeight);
  NSRect timelineFrame = NSMakeRect(0.0, controlsHeight, NSWidth(bounds), timelineHeight);
  NSRect videoFrame = NSMakeRect(0.0,
                                 controlsHeight + timelineHeight,
                                 NSWidth(bounds),
                                 NSHeight(bounds) - controlsHeight - timelineHeight);

  [self.controlsContainer setFrame:controlsFrame];
  [self.timelineContainer setFrame:timelineFrame];
  [self.videoView setFrame:videoFrame];

  [self.timelineSlider setFrame:NSMakeRect(12.0,
                                           6.0,
                                           NSWidth(timelineFrame) - 24.0,
                                           NSHeight(timelineFrame) - 12.0)];

  CGFloat centerY = floor((controlsHeight - 24.0) / 2.0);
  CGFloat centerX = NSWidth(controlsFrame) / 2.0;

  [self.playPauseButton setFrame:NSMakeRect(centerX - 20.0, centerY, 40.0, 24.0)];
  [self.rewindButton setFrame:NSMakeRect(centerX - 68.0, centerY, 40.0, 24.0)];
  [self.forwardButton setFrame:NSMakeRect(centerX + 28.0, centerY, 40.0, 24.0)];

  [self.volumeSlider setFrame:NSMakeRect(24.0, centerY, 220.0, 24.0)];
  [self.utilityButton setFrame:NSMakeRect(NSWidth(controlsFrame) - 52.0, centerY, 36.0, 24.0)];
  [self.statusLabel setFrame:NSMakeRect(NSWidth(controlsFrame) - 320.0, centerY + 2.0, 250.0, 20.0)];

  [self.controlsContainer setNeedsDisplay:YES];
}

- (NSButton *)controlButtonWithTitle:(NSString *)title action:(SEL)action
{
  NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 24)];
  [button setTitle:title];
  [button setTarget:self];
  [button setAction:action];
  [button setBezelStyle:NSRoundedBezelStyle];
  return button;
}

- (void)openFiles
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = YES;

  if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
      NSMutableArray *paths = [NSMutableArray array];
      NSEnumerator *urlEnumerator = [panel.URLs objectEnumerator];
      NSURL *url = nil;
      while ((url = [urlEnumerator nextObject]) != nil)
        {
          NSString *path = [url path];
          if (path == nil)
            {
              path = [url absoluteString];
            }
          [paths addObject:path];
        }
      [self.player loadPaths:paths];
      [self updateStatus:[NSString stringWithFormat:@"Loaded %@", [[paths objectAtIndex:0] lastPathComponent]]];
    }
}

- (void)openURLPrompt
{
  NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 420, 120)
                                               styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];
#ifdef NSWindowStyleMaskTitled
  [panel setStyleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)];
#endif
  [panel setTitle:@"Open URL / Stream"];

  NSView *content = [panel contentView];

  NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 80, 380, 20)];
  [label setBezeled:NO];
  [label setDrawsBackground:NO];
  [label setEditable:NO];
  [label setSelectable:NO];
  [label setStringValue:@"Enter a network URL or stream location:"];

  NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 50, 380, 24)];
  [input setStringValue:@"https://"];

  NSButton *openButton = [[NSButton alloc] initWithFrame:NSMakeRect(240, 12, 80, 28)];
  [openButton setTitle:@"Open"];
  [openButton setButtonType:NSMomentaryPushInButton];
  [openButton setBezelStyle:NSRoundedBezelStyle];
  [openButton setKeyEquivalent:@"\r"];

  NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(326, 12, 80, 28)];
  [cancelButton setTitle:@"Cancel"];
  [cancelButton setButtonType:NSMomentaryPushInButton];
  [cancelButton setBezelStyle:NSRoundedBezelStyle];
  [cancelButton setKeyEquivalent:@"\e"];

  [openButton setTarget:self];
  [openButton setAction:@selector(onURLPromptOpen:)];

  [cancelButton setTarget:self];
  [cancelButton setAction:@selector(onURLPromptCancel:)];

  [content addSubview:label];
  [content addSubview:input];
  [content addSubview:openButton];
  [content addSubview:cancelButton];

  self.urlPromptResult = NSAlertSecondButtonReturn;
  [panel center];
  [panel makeKeyAndOrderFront:nil];
  [NSApp runModalForWindow:panel];
  NSInteger response = self.urlPromptResult;
  [panel orderOut:nil];

  if (response == NSAlertFirstButtonReturn)
    {
      [self.player loadURLString:[input stringValue]];
      [self updateStatus:[NSString stringWithFormat:@"Streaming %@", [input stringValue]]];
    }
}

- (void)onURLPromptOpen:(id)sender
{
  (void)sender;
  self.urlPromptResult = NSAlertFirstButtonReturn;
  [NSApp stopModal];
}

- (void)onURLPromptCancel:(id)sender
{
  (void)sender;
  self.urlPromptResult = NSAlertSecondButtonReturn;
  [NSApp stopModal];
}

- (void)openTVStream
{
  NSString *tvURL = @"tv://";
  [self.player loadURLString:tvURL];
  [self updateStatus:@"Opening TV source (tv://)"];
}

- (void)toggleZoomMode
{
  [[self window] performZoom:nil];
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

  [menu addItemWithTitle:@"Video" action:NULL keyEquivalent:@""];
  [menu addItemWithTitle:@"Audio" action:NULL keyEquivalent:@""];
  [menu addItemWithTitle:@"Subtitles" action:NULL keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Fullscreen" action:@selector(toggleZoomMode) keyEquivalent:@""];

  NSMenuItem *lastItem = [menu itemAtIndex:[menu numberOfItems] - 1];
  [lastItem setTarget:self];

  NSButton *button = (NSButton *)sender;
  NSRect frame = [button bounds];
  [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(NSMinX(frame), NSMaxY(frame)) inView:button];
}

@end
