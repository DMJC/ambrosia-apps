#import <AppKit/AppKit.h>

@class MainWindowController;
@class PreferencesWindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    MainWindowController       *_mainWindowController;
    PreferencesWindowController *_prefsWindowController;
}

- (void)showAboutPanel:(id)sender;
- (void)openPreferences:(id)sender;

@end
