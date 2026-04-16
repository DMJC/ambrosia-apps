// NowPlayingBar.h
#import <AppKit/AppKit.h>

@class NowPlayingBar;
@protocol NowPlayingBarDelegate
- (void)nowPlayingBarPlayRequested:(NowPlayingBar *)bar;
@end

@interface NowPlayingBar : NSView
{
    NSButton     *_prevBtn;
    NSButton     *_playPauseBtn;
    NSButton     *_nextBtn;
    NSSlider     *_progressSlider;
    NSSlider     *_volumeSlider;
    NSTextField  *_titleLabel;
    NSTextField  *_artistLabel;
    NSTextField  *_timeLabel;
    NSImageView  *_albumArtView;
    BOOL          _draggingProgress;
    id<NowPlayingBarDelegate> _delegate;
}
@property (nonatomic, assign) id<NowPlayingBarDelegate> delegate;
- (void)update;
@end
