#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class GMPVPreferencesWindowController;

@interface GMPVAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) GMPVPreferencesWindowController *preferencesController;

@end

NS_ASSUME_NONNULL_END
