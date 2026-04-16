#import "GMPVMPVPlayer.h"

#import "GMPVVideoView.h"

#include <inttypes.h>
#include <dlfcn.h>

#if __has_include(<OpenGL/gl.h>)
  #import <OpenGL/gl.h>
#elif __has_include(<GL/gl.h>)
  #import <GL/gl.h>
#endif

#if __has_include(<mpv/client.h>)
  #import <mpv/client.h>
  #define GMPV_HAS_LIBMPV 1
  #if __has_include(<mpv/render_gl.h>)
    #import <mpv/render.h>
    #import <mpv/render_gl.h>
    #define GMPV_HAS_RENDER_GL 1
  #else
    #define GMPV_HAS_RENDER_GL 0
    typedef struct mpv_render_context mpv_render_context;
  #endif
#else
  #define GMPV_HAS_LIBMPV 0
  #define GMPV_HAS_RENDER_GL 0
  typedef struct mpv_handle mpv_handle;
  typedef struct mpv_render_context mpv_render_context;
#endif

@interface GMPVMPVPlayer ()
{
#if GMPV_HAS_LIBMPV
  mpv_handle *_mpv;
  BOOL _initialized;
  #if GMPV_HAS_RENDER_GL
    mpv_render_context *_renderContext;
    void *_glLibraryHandle;
  #endif
#endif
  __weak GMPVVideoView *_videoView;
  BOOL _paused;
}

@property (nonatomic, readwrite, getter=isReady) BOOL ready;

@end

#if GMPV_HAS_LIBMPV && GMPV_HAS_RENDER_GL
static void *gmpvGetProcAddress(void *ctx, const char *name)
{
  GMPVMPVPlayer *player = (__bridge GMPVMPVPlayer *)ctx;

  if (player == nil || name == NULL)
    {
      return NULL;
    }

  if (player->_glLibraryHandle == NULL)
    {
      player->_glLibraryHandle = dlopen("libGL.so.1", RTLD_LAZY | RTLD_LOCAL);
      if (player->_glLibraryHandle == NULL)
        {
          player->_glLibraryHandle = dlopen("libOpenGL.so.0", RTLD_LAZY | RTLD_LOCAL);
        }
    }

  if (player->_glLibraryHandle != NULL)
    {
      void *symbol = dlsym(player->_glLibraryHandle, name);
      if (symbol != NULL)
        {
          return symbol;
        }
    }

  return dlsym(RTLD_DEFAULT, name);
}

static void gmpvRenderUpdateCallback(void *ctx)
{
  GMPVMPVPlayer *player = (__bridge GMPVMPVPlayer *)ctx;
  if (player == nil)
    {
      return;
    }

  GMPVVideoView *view = player->_videoView;
  [view performSelectorOnMainThread:@selector(requestRedraw)
                         withObject:nil
                      waitUntilDone:NO];
}
#endif

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
  [self teardownRenderContext];

  if (_mpv != NULL)
    {
      mpv_terminate_destroy(_mpv);
      _mpv = NULL;
    }

#if GMPV_HAS_RENDER_GL
  if (_glLibraryHandle != NULL)
    {
      dlclose(_glLibraryHandle);
      _glLibraryHandle = NULL;
    }
#endif
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

  /* Initialize libmpv once; rendering happens through mpv_render_context. */
  mpv_set_option_string(_mpv, "vo", "libmpv");
  mpv_set_option_string(_mpv, "force-window", "no");
  mpv_set_option_string(_mpv, "idle", "yes");
  mpv_set_option_string(_mpv, "keep-open", "yes");
  mpv_set_option_string(_mpv, "input-default-bindings", "no");
  mpv_set_option_string(_mpv, "input-vo-keyboard", "no");

  if (mpv_initialize(_mpv) < 0)
    {
      NSLog(@"Failed to initialize mpv");
      mpv_terminate_destroy(_mpv);
      _mpv = NULL;
      return;
    }

  _initialized = YES;
  self.ready = YES;
#else
  NSLog(@"Built without libmpv headers. Player backend is stubbed.");
  self.ready = NO;
#endif
}

- (void)setNativeWindowID:(int64_t)wid
{
  (void)wid;
}

- (void)setupRenderContextWithWaylandDisplay:(void *)waylandDisplay
{
#if GMPV_HAS_LIBMPV && GMPV_HAS_RENDER_GL
  if (_mpv == NULL || !_initialized || _renderContext != NULL)
    {
      return;
    }

  mpv_opengl_init_params glInitParams = {
    .get_proc_address = gmpvGetProcAddress,
    .get_proc_address_ctx = (__bridge void *)self,
    .extra_exts = NULL
  };

  int advancedControl = 1;
  mpv_render_param params[] = {
    {MPV_RENDER_PARAM_API_TYPE, (void *)MPV_RENDER_API_TYPE_OPENGL},
    {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glInitParams},
    {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advancedControl},
    {MPV_RENDER_PARAM_INVALID, NULL}
  };

  mpv_render_param paramsWithWayland[] = {
    {MPV_RENDER_PARAM_API_TYPE, (void *)MPV_RENDER_API_TYPE_OPENGL},
    {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glInitParams},
    {MPV_RENDER_PARAM_WL_DISPLAY, waylandDisplay},
    {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advancedControl},
    {MPV_RENDER_PARAM_INVALID, NULL}
  };

  int rc = mpv_render_context_create(&_renderContext,
                                     _mpv,
                                     waylandDisplay != NULL ? paramsWithWayland : params);
  if (rc < 0)
    {
      NSLog(@"Failed to create mpv render context (%d)", rc);
      _renderContext = NULL;
      return;
    }

  mpv_render_context_set_update_callback(_renderContext,
                                         gmpvRenderUpdateCallback,
                                         (__bridge void *)self);
#else
  (void)waylandDisplay;
#endif
}

- (void)teardownRenderContext
{
#if GMPV_HAS_LIBMPV && GMPV_HAS_RENDER_GL
  if (_renderContext != NULL)
    {
      mpv_render_context_set_update_callback(_renderContext, NULL, NULL);
      mpv_render_context_free(_renderContext);
      _renderContext = NULL;
    }
#endif
}

- (void)renderFrameWithFramebuffer:(int)framebuffer
                             width:(int)width
                            height:(int)height
                             flipY:(BOOL)flipY
{
#if GMPV_HAS_LIBMPV && GMPV_HAS_RENDER_GL
  if (_renderContext == NULL || width <= 0 || height <= 0)
    {
      return;
    }

  mpv_opengl_fbo fbo = {
    .fbo = framebuffer,
    .w = width,
    .h = height,
    .internal_format = 0
  };

  int flip = flipY ? 1 : 0;
  mpv_render_param renderParams[] = {
    {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
    {MPV_RENDER_PARAM_FLIP_Y, &flip},
    {MPV_RENDER_PARAM_INVALID, NULL}
  };

  mpv_render_context_render(_renderContext, renderParams);
#else
  (void)framebuffer;
  (void)width;
  (void)height;
  (void)flipY;
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
  if (_mpv != NULL && _initialized)
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
  if (_mpv != NULL && _initialized)
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
  if (_mpv != NULL && _initialized)
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
  if (_mpv != NULL && _initialized)
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
  if (_mpv != NULL && _initialized)
    {
      int flag = pause ? 1 : 0;
      mpv_set_property(_mpv, "pause", MPV_FORMAT_FLAG, &flag);
    }
#endif
}

@end
