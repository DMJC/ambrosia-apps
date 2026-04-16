#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class GMPVMPVPlayer;

@interface GMPVPlayerWindowController : NSWindowController

@property (nonatomic, readonly) GMPVMPVPlayer *player;
@property (nonatomic, readonly, getter=isPlaylistVisible) BOOL playlistVisible;

- (void)openFiles;
- (void)openURLPrompt;
- (void)openTVStream;
- (void)toggleZoomMode;
- (void)togglePlaylistWindow;
- (void)addPlaylistPaths:(NSArray<NSString *> *)paths autoplay:(BOOL)autoplay;

@end

NS_ASSUME_NONNULL_END
