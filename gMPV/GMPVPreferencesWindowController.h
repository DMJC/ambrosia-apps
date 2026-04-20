#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface GMPVPreferencesWindowController : NSWindowController

+ (NSString *)preferencesPath;
+ (NSDictionary *)loadPreferences;

@end

NS_ASSUME_NONNULL_END
