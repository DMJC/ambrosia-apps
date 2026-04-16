#import "GMPVMPVPlayer.h"

#import "GMPVVideoView.h"

#if __has_include(<mpv/client.h>)
  #import <mpv/client.h>
  #define GMPV_HAS_LIBMPV 1
  #if __has_include(<mpv/opengl_cb.h>)
    #import <mpv/opengl_cb.h>
    #define GMPV_HAS_OPENGL_CB 1
  #else
    #define GMPV_HAS_OPENGL_CB 0
    typedef struct mpv_opengl_cb_context mpv_opengl_cb_context;
  #endif
#else
  #define GMPV_HAS_LIBMPV 0
  #define GMPV_HAS_OPENGL_CB 0
  typedef struct mpv_handle mpv_handle;
  typedef struct mpv_opengl_cb_context mpv_opengl_cb_context;
#endif

@interface GMPVMPVPlayer ()
{
#if GMPV_HAS_LIBMPV
  mpv_handle *_mpv;
  BOOL _initialized;
  #if GMPV_HAS_OPENGL_CB
    mpv_opengl_cb_context *_openglContext;
  #endif
#endif
  __weak GMPVVideoView *_videoView;
  BOOL _paused;
}

@property (nonatomic, readwrite, getter=isReady) BOOL ready;

@end

@implementation GMPVMPVPlayer

- (instancetype)initWithVideoView:(GMPVVideoView *)videoView
{
  self = [super init];
  if (self)
    {
      _videoView = videoView;
      [self bootstrapMPV];
    }
  return self;
}

- (void)dealloc
{
#if GMPV_HAS_LIBMPV
  if (_mpv != NULL)
    {
      mpv_terminate_destroy(_mpv);
      _mpv = NULL;
    }
#endif
}

- (void)bootstrapMPV
{
#if GMPV_HAS_LIBMPV
  _mpv = mpv_create();
  if (_mpv == NULL)
    {
      NSLog(@"Failed to create mpv instance");
      return;
    }

  mpv_set_option_string(_mpv, "vo", "gpu");

  if (mpv_initialize(_mpv) < 0)
    {
      NSLog(@"Failed to initialize mpv");
      mpv_terminate_destroy(_mpv);
      _mpv = NULL;
      return;
    }

  #if GMPV_HAS_OPENGL_CB
    _openglContext = mpv_get_sub_api(_mpv, MPV_SUB_API_OPENGL_CB);
    if (_openglContext == NULL)
      {
        NSLog(@"mpv OpenGL callback API unavailable");
      }
  #else
    NSLog(@"mpv/opengl_cb.h not found. Building without OpenGL callback integration.");
  #endif

  self.ready = YES;
#else
  NSLog(@"Built without libmpv headers. Player backend is stubbed.");
  self.ready = NO;
#endif
}

- (void)setNativeWindowID:(int64_t)wid
{
#if GMPV_HAS_LIBMPV
  if (_mpv != NULL)
    {
      mpv_set_property(_mpv, "wid", MPV_FORMAT_INT64, &wid);
    }
#else
  (void)wid;
#endif
}

- (void)play
{
  [self setPause:NO];
}

- (void)pause
{
  [self setPause:YES];
}

- (void)togglePlayback
{
  [self setPause:!_paused];
}

- (void)stop
{
#if GMPV_HAS_LIBMPV
  if (_mpv != NULL)
    {
      const char *cmd[] = {"stop", NULL};
      mpv_command(_mpv, cmd);
    }
#endif
}

- (void)loadURLString:(NSString *)urlString
{
  if (urlString.length == 0)
    {
      return;
    }

  self.currentSource = urlString;

#if GMPV_HAS_LIBMPV
  if (_mpv != NULL)
    {
      const char *cmd[] = {"loadfile", [urlString UTF8String], NULL};
      mpv_command(_mpv, cmd);
      _paused = NO;
    }
#endif

  [_videoView requestRedraw];
}

- (void)loadPaths:(NSArray<NSString *> *)paths
{
  if (paths.count == 0)
    {
      return;
    }

  [self loadURLString:paths.firstObject];
}

- (void)setVolume:(float)volume
{
#if GMPV_HAS_LIBMPV
  if (_mpv != NULL)
    {
      double v = MAX(0.0, MIN(100.0, volume));
      mpv_set_property(_mpv, "volume", MPV_FORMAT_DOUBLE, &v);
    }
#else
  (void)volume;
#endif
}

- (void)seekToRelativeSeconds:(double)seconds
{
#if GMPV_HAS_LIBMPV
  if (_mpv != NULL)
    {
      double amount = seconds;
      mpv_set_property(_mpv, "time-pos", MPV_FORMAT_DOUBLE, &amount);
    }
#else
  (void)seconds;
#endif
}

- (void)setPause:(BOOL)pause
{
  _paused = pause;

#if GMPV_HAS_LIBMPV
  if (_mpv != NULL)
    {
      int flag = pause ? 1 : 0;
      mpv_set_property(_mpv, "pause", MPV_FORMAT_FLAG, &flag);
    }
#endif
}

@end
