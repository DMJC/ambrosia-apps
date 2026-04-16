#import <Foundation/Foundation.h>
#import "MusicTrack.h"

extern NSString * const AudioPlayerTrackChangedNotification;
extern NSString * const AudioPlayerStateChangedNotification;
extern NSString * const AudioPlayerProgressNotification;

typedef NS_ENUM(NSInteger, AudioPlayerState) {
    AudioPlayerStateStopped,
    AudioPlayerStatePlaying,
    AudioPlayerStatePaused,
};

typedef NS_ENUM(NSInteger, RepeatMode) {
    RepeatModeNone,
    RepeatModeOne,
    RepeatModeAll,
};

@interface AudioPlayer : NSObject
{
    // GStreamer opaque handle stored as void* to avoid C++ leakage into .h
    void          *_pipeline;
    void          *_busSource;

    MusicTrack    *_currentTrack;
    NSMutableArray *_queue;
    NSInteger      _queueIndex;
    AudioPlayerState _state;
    float          _volume;         // 0.0 – 1.0
    RepeatMode     _repeatMode;
    BOOL           _shuffle;
    NSTimer        *_progressTimer;
}

+ (AudioPlayer *)sharedPlayer;

@property (nonatomic, readonly) AudioPlayerState state;
@property (nonatomic, readonly) MusicTrack       *currentTrack;
@property (nonatomic, assign)   float             volume;       // 0–1
@property (nonatomic, assign)   RepeatMode        repeatMode;
@property (nonatomic, assign)   BOOL              shuffle;

- (void)playTrack:(MusicTrack *)track;
- (void)playTrack:(MusicTrack *)track withQueue:(NSArray *)queue;
- (void)pause;
- (void)resume;
- (void)stop;
- (void)next;
- (void)previous;
- (void)seekToPosition:(double)fraction;   // 0.0 – 1.0

- (NSTimeInterval)currentTime;
- (NSTimeInterval)duration;
- (double)progress;   // 0.0 – 1.0

@end
