#import "Preferences.h"

NSString * const GTunesMusicLibraryPathKey = @"GTunesMusicLibraryPath";
static NSString * const kHasConfiguredLibraryKey = @"GTunesHasConfiguredLibrary";

@implementation Preferences

+ (Preferences *)sharedPreferences
{
    static Preferences *prefs = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ prefs = [[Preferences alloc] init]; });
    return prefs;
}

- (id)init
{
    self = [super init];
    if (self) {
        NSString *defaultPath =
            [NSHomeDirectory() stringByAppendingPathComponent:@"Music"];
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            GTunesMusicLibraryPathKey : defaultPath,
            kHasConfiguredLibraryKey  : @NO,
        }];
    }
    return self;
}

- (NSString *)musicLibraryPath
{
    return [[NSUserDefaults standardUserDefaults]
            stringForKey:GTunesMusicLibraryPathKey];
}

- (void)setMusicLibraryPath:(NSString *)path
{
    [[NSUserDefaults standardUserDefaults]
        setObject:path forKey:GTunesMusicLibraryPathKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)hasConfiguredLibrary
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:kHasConfiguredLibraryKey];
}

- (void)setHasConfiguredLibrary:(BOOL)flag
{
    [[NSUserDefaults standardUserDefaults]
        setBool:flag forKey:kHasConfiguredLibraryKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
