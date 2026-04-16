#import "AudioPlayer.h"
#include <gst/gst.h>

NSString * const AudioPlayerTrackChangedNotification = @"AudioPlayerTrackChanged";
NSString * const AudioPlayerStateChangedNotification = @"AudioPlayerStateChanged";
NSString * const AudioPlayerProgressNotification     = @"AudioPlayerProgress";

@interface AudioPlayer ()
- (void)_buildPipeline;
- (void)_teardownPipeline;
- (void)_playURI:(NSString *)uri;
- (void)_handleEOS;
- (void)_pollProgress:(NSTimer *)t;
@end

@implementation AudioPlayer

@synthesize state        = _state;
@synthesize currentTrack = _currentTrack;
@synthesize repeatMode   = _repeatMode;
@synthesize shuffle      = _shuffle;

+ (AudioPlayer *)sharedPlayer
{
    static AudioPlayer *p = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ p = [[AudioPlayer alloc] init]; });
    return p;
}

+ (void)initialize
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{ gst_init(NULL, NULL); });
}

- (id)init
{
    self = [super init];
    if (self) {
        _queue      = [[NSMutableArray alloc] init];
        _queueIndex = -1;
        _state      = AudioPlayerStateStopped;
        _volume     = 1.0f;
        _repeatMode = RepeatModeNone;
        _shuffle    = NO;
        [self _buildPipeline];
    }
    return self;
}

- (void)dealloc
{
    [self _teardownPipeline];
    [_queue        release];
    [_currentTrack release];
    [_progressTimer invalidate];
    [_progressTimer release];
    [super dealloc];
}

// ──────────── Pipeline ────────────

- (void)_buildPipeline
{
    GstElement *pipe = gst_element_factory_make("playbin", "gtunes-playbin");
    if (!pipe) {
        NSLog(@"[gTunes] Could not create GStreamer playbin element.");
        return;
    }
    g_object_set(pipe, "volume", (gdouble)_volume, NULL);

    // Retain the bus for manual polling in _pollProgress:.
    // gst_bus_add_watch() requires the GLib main loop which does not run under
    // GNUstep's NSRunLoop, so we poll instead.
    GstBus *bus = gst_pipeline_get_bus(GST_PIPELINE(pipe));
    _busSource = (void *)bus;   // takes the ref returned by gst_pipeline_get_bus

    _pipeline = (void *)pipe;
}

- (void)_teardownPipeline
{
    if (_busSource) {
        gst_object_unref((GstBus *)_busSource);
        _busSource = NULL;
    }
    if (_pipeline) {
        gst_element_set_state((GstElement *)_pipeline, GST_STATE_NULL);
        gst_object_unref((GstElement *)_pipeline);
        _pipeline = NULL;
    }
}

// ──────────── Playback ────────────

- (void)_playURI:(NSString *)uri
{
    NSLog(@"[gTunes] playing URI: %@", uri);
    if (!_pipeline) [self _buildPipeline];
    GstElement *pipe = (GstElement *)_pipeline;
    gst_element_set_state(pipe, GST_STATE_NULL);
    g_object_set(pipe, "uri", [uri UTF8String],
                       "volume", (gdouble)_volume, NULL);
    gst_element_set_state(pipe, GST_STATE_PLAYING);
    _state = AudioPlayerStatePlaying;

    if (!_progressTimer) {
        _progressTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5
            target:self selector:@selector(_pollProgress:)
            userInfo:nil repeats:YES] retain];
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:AudioPlayerTrackChangedNotification object:self];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AudioPlayerStateChangedNotification object:self];
}

// Called every 0.5 s by NSTimer.  Drains the GStreamer bus (EOS, errors) and
// fires a progress notification so the UI can update the scrubber.
- (void)_pollProgress:(NSTimer *)t
{
    if (_pipeline && _busSource) {
        GstBus *bus = (GstBus *)_busSource;
        GstMessage *msg;
        while ((msg = gst_bus_pop(bus)) != NULL) {
            switch (GST_MESSAGE_TYPE(msg)) {
                case GST_MESSAGE_EOS:
                    gst_message_unref(msg);
                    [self _handleEOS];
                    // _handleEOS may start a new track; stop draining this
                    // pipeline's stale messages.
                    return;

                case GST_MESSAGE_ERROR: {
                    GError *err = NULL;
                    gst_message_parse_error(msg, &err, NULL);
                    NSLog(@"[gTunes GStreamer] %s", err ? err->message : "unknown error");
                    g_clear_error(&err);
                    gst_message_unref(msg);
                    [self stop];
                    return;
                }

                default:
                    gst_message_unref(msg);
                    break;
            }
        }
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:AudioPlayerProgressNotification object:self];
}

// ──────────── Public API ────────────

- (void)playTrack:(MusicTrack *)track
{
    [self playTrack:track withQueue:@[track]];
}

- (void)playTrack:(MusicTrack *)track withQueue:(NSArray *)queue
{
    NSLog(@"[gTunes] playTrack: \"%@\" by %@  (queue: %lu tracks)",
        track.title ?: track.filePath,
        track.artist ?: @"Unknown",
        (unsigned long)[queue count]);

    [_currentTrack release];
    _currentTrack = [track retain];
    if ((id)queue != (id)_queue)
        [_queue setArray:queue];
    _queueIndex = [_queue indexOfObject:track];

    NSString *uri = [NSString stringWithFormat:@"file://%@",
        [track.filePath stringByAddingPercentEncodingWithAllowedCharacters:
            [NSCharacterSet URLPathAllowedCharacterSet]]];
    [self _playURI:uri];

    track.playCount++;
    track.lastPlayed = [NSDate date];
}

- (void)pause
{
    if (_state != AudioPlayerStatePlaying) return;
    NSLog(@"[gTunes] playback paused: \"%@\"", _currentTrack.title ?: _currentTrack.filePath);
    gst_element_set_state((GstElement *)_pipeline, GST_STATE_PAUSED);
    _state = AudioPlayerStatePaused;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AudioPlayerStateChangedNotification object:self];
}

- (void)resume
{
    if (_state != AudioPlayerStatePaused) return;
    NSLog(@"[gTunes] playback resumed: \"%@\"", _currentTrack.title ?: _currentTrack.filePath);
    gst_element_set_state((GstElement *)_pipeline, GST_STATE_PLAYING);
    _state = AudioPlayerStatePlaying;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AudioPlayerStateChangedNotification object:self];
}

- (void)stop
{
    if (!_pipeline) return;
    NSLog(@"[gTunes] playback stopped: \"%@\"", _currentTrack.title ?: _currentTrack.filePath);
    gst_element_set_state((GstElement *)_pipeline, GST_STATE_NULL);
    _state = AudioPlayerStateStopped;
    [_progressTimer invalidate];
    [_progressTimer release];
    _progressTimer = nil;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AudioPlayerStateChangedNotification object:self];
}

- (void)next
{
    if ([_queue count] == 0) return;
    NSInteger next = _shuffle
        ? (NSInteger)arc4random_uniform((uint32_t)[_queue count])
        : _queueIndex + 1;

    if (next >= (NSInteger)[_queue count]) {
        if (_repeatMode == RepeatModeAll) next = 0;
        else { [self stop]; return; }
    }
    _queueIndex = next;
    [self playTrack:_queue[_queueIndex] withQueue:_queue];
}

- (void)previous
{
    if ([_queue count] == 0) return;
    if ([self currentTime] > 3.0) {
        [self seekToPosition:0.0];
        return;
    }
    NSInteger prev = _queueIndex - 1;
    if (prev < 0) prev = (_repeatMode == RepeatModeAll)
        ? (NSInteger)[_queue count] - 1 : 0;
    _queueIndex = prev;
    [self playTrack:_queue[_queueIndex] withQueue:_queue];
}

- (void)seekToPosition:(double)fraction
{
    if (!_pipeline) return;
    gint64 dur = 0;
    if (gst_element_query_duration((GstElement *)_pipeline, GST_FORMAT_TIME, &dur)) {
        gint64 pos = (gint64)(fraction * dur);
        gst_element_seek_simple((GstElement *)_pipeline,
            GST_FORMAT_TIME,
            (GstSeekFlags)(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT),
            pos);
    }
}

- (NSTimeInterval)currentTime
{
    if (!_pipeline) return 0;
    gint64 pos = 0;
    gst_element_query_position((GstElement *)_pipeline, GST_FORMAT_TIME, &pos);
    return (NSTimeInterval)(pos / GST_SECOND);
}

- (NSTimeInterval)duration
{
    if (!_pipeline) return 0;
    gint64 dur = 0;
    gst_element_query_duration((GstElement *)_pipeline, GST_FORMAT_TIME, &dur);
    return (NSTimeInterval)(dur / GST_SECOND);
}

- (double)progress
{
    NSTimeInterval dur = [self duration];
    if (dur <= 0) return 0;
    return [self currentTime] / dur;
}

- (float)volume { return _volume; }
- (void)setVolume:(float)v
{
    _volume = MAX(0.0f, MIN(1.0f, v));
    if (_pipeline) g_object_set(_pipeline, "volume", (gdouble)_volume, NULL);
}

- (void)_handleEOS
{
    NSLog(@"[gTunes] track finished: \"%@\"", _currentTrack.title ?: _currentTrack.filePath);
    if (_repeatMode == RepeatModeOne && _currentTrack) {
        NSLog(@"[gTunes] repeat-one: restarting \"%@\"", _currentTrack.title ?: _currentTrack.filePath);
        [self playTrack:_currentTrack withQueue:_queue];
        return;
    }
    [self next];
}

@end
