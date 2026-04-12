#import "GMPVAppDelegate.h"

#import "GMPVPlayerWindowController.h"

@interface GMPVAppDelegate ()

@property (nonatomic, strong) GMPVPlayerWindowController *windowController;

@end

@implementation GMPVAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  (void)notification;

  [self buildMainMenu];

  self.windowController = [[GMPVPlayerWindowController alloc] init];
  [self.windowController showWindow:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
  (void)sender;
  return YES;
}

- (void)buildMainMenu
{
  NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];

  NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"gMPV" action:nil keyEquivalent:@""];
  [mainMenu addItem:appMenuItem];
  [appMenuItem setSubmenu:[self gmpvMenu]];

  NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
  [mainMenu addItem:editMenuItem];
  [editMenuItem setSubmenu:[self editMenu]];

  NSMenuItem *viewMenuItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
  [mainMenu addItem:viewMenuItem];
  [viewMenuItem setSubmenu:[self viewMenu]];

  NSMenuItem *helpMenuItem = [[NSMenuItem alloc] initWithTitle:@"Help" action:nil keyEquivalent:@""];
  [mainMenu addItem:helpMenuItem];
  [helpMenuItem setSubmenu:[self helpMenu]];

  [NSApp setMainMenu:mainMenu];
}

- (NSMenu *)gmpvMenu
{
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"gMPV"];

  [menu addItem:[self menuItemWithTitle:@"Open Files…"
                                action:@selector(openFiles:)
                          keyEquivalent:@"o"]];

  [menu addItem:[self menuItemWithTitle:@"Open URL / Stream…"
                                action:@selector(openURLStream:)
                          keyEquivalent:@"u"]];

  [menu addItem:[self menuItemWithTitle:@"Open TV://"
                                action:@selector(openTV:)
                          keyEquivalent:@"t"]];

  [menu addItem:[NSMenuItem separatorItem]];

  NSMenuItem *quit = [self menuItemWithTitle:@"Quit gMPV"
                                      action:@selector(terminate:)
                                keyEquivalent:@"q"];
  quit.target = NSApp;
  [menu addItem:quit];

  return menu;
}

- (NSMenu *)editMenu
{
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Edit"];

  [menu addItem:[self menuItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"]];
  [menu addItem:[self menuItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"]];
  [menu addItem:[self menuItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"]];
  [menu addItem:[self menuItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"]];

  return menu;
}

- (NSMenu *)viewMenu
{
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"View"];

  [menu addItem:[self menuItemWithTitle:@"Toggle Fullscreen"
                                action:@selector(toggleFullscreen:)
                          keyEquivalent:@"f"]];

  return menu;
}

- (NSMenu *)helpMenu
{
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Help"];

  [menu addItem:[self menuItemWithTitle:@"gMPV Help"
                                action:@selector(showHelp:)
                          keyEquivalent:@"?"]];

  return menu;
}

- (NSMenuItem *)menuItemWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)keyEquivalent
{
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:keyEquivalent];
  item.target = self;
  return item;
}

- (void)openFiles:(id)sender
{
  (void)sender;
  [self.windowController openFiles];
}

- (void)openURLStream:(id)sender
{
  (void)sender;
  [self.windowController openURLPrompt];
}

- (void)openTV:(id)sender
{
  (void)sender;
  [self.windowController openTVStream];
}

- (void)toggleFullscreen:(id)sender
{
  (void)sender;
  [self.windowController.window toggleFullScreen:nil];
}

- (void)showHelp:(id)sender
{
  (void)sender;

  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"gMPV";
  alert.informativeText = @"GNUstep front-end for libmpv with Wayland-targeted GPU context.";
  [alert runModal];
}

@end
