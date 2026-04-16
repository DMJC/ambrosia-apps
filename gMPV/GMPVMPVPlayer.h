#import <Foundation/Foundation.h>

@class GMPVVideoView;

NS_ASSUME_NONNULL_BEGIN

@interface GMPVMPVPlayer : NSObject

@property (nonatomic, readonly, getter=isReady) BOOL ready;
@property (nonatomic, copy, nullable) NSString *currentSource;

- (instancetype)initWithVideoView:(GMPVVideoView *)videoView;
- (void)setNativeWindowID:(int64_t)wid;
- (void)play;
- (void)pause;
- (void)togglePlayback;
- (void)stop;
- (void)loadURLString:(NSString *)urlString;
- (void)loadPaths:(NSArray<NSString *> *)paths;
- (void)setVolume:(float)volume;
- (void)seekToRelativeSeconds:(double)seconds;

@end

NS_ASSUME_NONNULL_END
