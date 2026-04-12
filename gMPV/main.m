#import <AppKit/AppKit.h>

#import "GMPVAppDelegate.h"

int main(int argc, const char **argv)
{
  @autoreleasepool
    {
      NSApplication *application = [NSApplication sharedApplication];
      GMPVAppDelegate *delegate = [[GMPVAppDelegate alloc] init];
      application.delegate = delegate;
      return NSApplicationMain(argc, argv);
    }
}
