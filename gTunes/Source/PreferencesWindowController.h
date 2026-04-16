#import <AppKit/AppKit.h>

@interface PreferencesWindowController : NSWindowController
{
    NSTextField *_pathField;
    NSButton    *_browseButton;
    NSButton    *_okButton;
    NSButton    *_cancelButton;
}

+ (PreferencesWindowController *)sharedController;
- (void)showWindow:(id)sender;

@end
