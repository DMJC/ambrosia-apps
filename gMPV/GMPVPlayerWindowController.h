#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class GMPVMPVPlayer;

@interface GMPVPlayerWindowController : NSWindowController

@property (nonatomic, readonly) GMPVMPVPlayer *player;

- (void)openFiles;
- (void)openURLPrompt;
- (void)openTVStream;
- (void)toggleZoomMode;

@end

NS_ASSUME_NONNULL_END
