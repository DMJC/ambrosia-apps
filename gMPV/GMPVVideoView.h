#import <AppKit/AppKit.h>

@class GMPVMPVPlayer;

NS_ASSUME_NONNULL_BEGIN

@interface GMPVVideoView : NSOpenGLView

+ (NSOpenGLPixelFormat *)defaultPixelFormat;
- (void)bindPlayer:(GMPVMPVPlayer *)player
    waylandDisplay:(nullable void *)waylandDisplay;
- (void)requestRedraw;

@end

NS_ASSUME_NONNULL_END
