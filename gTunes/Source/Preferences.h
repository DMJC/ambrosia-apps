#import <Foundation/Foundation.h>

extern NSString * const GTunesMusicLibraryPathKey;

/// Thin wrapper around NSUserDefaults.
/// On GNUstep the backing plist is ~/GNUstep/Defaults/gTunes.plist.
@interface Preferences : NSObject

+ (Preferences *)sharedPreferences;

/// Absolute path to the root music folder (default: ~/Music).
@property (nonatomic, copy) NSString *musicLibraryPath;

/// YES after the user has explicitly set (or confirmed) the library path.
@property (nonatomic, assign) BOOL hasConfiguredLibrary;

/// Playback settings persisted to gTunes.plist via NSUserDefaults.
@property (nonatomic, assign) BOOL shuffle;
@property (nonatomic, assign) BOOL repeat;

@end
