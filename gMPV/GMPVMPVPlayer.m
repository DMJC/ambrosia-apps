#import "GMPVMPVPlayer.h"

#import "GMPVVideoView.h"

#include <inttypes.h>
#include <dlfcn.h>
#include <string.h>
#include <unistd.h>

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
    void *_eglLibraryHandle;
  #endif
#endif
  __weak GMPVVideoView *_videoView;
  BOOL _paused;
}

@property (nonatomic, readwrite, getter=isReady) BOOL ready;

#if GMPV_HAS_LIBMPV && GMPV_HAS_RENDER_GL
- (void *)lookupGLProcAddress:(const char *)name;
- (void)requestVideoRedrawOnMainThread;
#endif
- (void)logVAAPIAvailability;
- (void)logEGLExtensions;

@end

#if GMPV_HAS_LIBMPV && GMPV_HAS_RENDER_GL
static void *gmpvGetProcAddress(void *ctx, const char *name)
{
  GMPVMPVPlayer *player = (__bridge GMPVMPVPlayer *)ctx;
  return [player lookupGLProcAddress:name];
}

static void gmpvRenderUpdateCallback(void *ctx)
{
  GMPVMPVPlayer *player = (__bridge GMPVMPVPlayer *)ctx;
  if (player == nil)
    {
      return;
    }

  [player requestVideoRedrawOnMainThread];
}
#endif

@implementation GMPVMPVPlayer

#if GMPV_HAS_LIBMPV && GMPV_HAS_RENDER_GL
- (void *)lookupGLProcAddress:(const char *)name
{
  if (name == NULL)
    return NULL;

  /* EGL path: needed when mpv uses MPV_RENDER_PARAM_WL_DISPLAY (Wayland/EGL).
     eglGetProcAddress resolves both EGL entry points and GL extension functions. */
  if (_eglLibraryHandle == NULL)
    _eglLibraryHandle = dlopen("libEGL.so.1", RTLD_LAZY | RTLD_LOCAL);

  if (_eglLibraryHandle != NULL)
    {
      typedef void *(*EGLGetProcType)(const char *);
      EGLGetProcType eglGetProc = (EGLGetProcType)dlsym(_eglLibraryHandle, "eglGetProcAddress");
      if (eglGetProc != NULL)
        {
          void *sym = eglGetProc(name);
          if (sym != NULL)
            return sym;
        }
      void *sym = dlsym(_eglLibraryHandle, name);
      if (sym != NULL)
        return sym;
    }

  /* GLX / desktop-GL path: fallback for X11 / XWayland contexts. */
  if (_glLibraryHandle == NULL)
    {
      _glLibraryHandle = dlopen("libGL.so.1", RTLD_LAZY | RTLD_LOCAL);
      if (_glLibraryHandle == NULL)
        _glLibraryHandle = dlopen("libOpenGL.so.0", RTLD_LAZY | RTLD_LOCAL);
    }

  if (_glLibraryHandle != NULL)
    {
      void *sym = dlsym(_glLibraryHandle, name);
      if (sym != NULL)
        return sym;
    }

  return dlsym(RTLD_DEFAULT, name);
}

- (void)requestVideoRedrawOnMainThread
{
  /* Intentional no-op: GNUstep's performSelectorOnMainThread: uses
     NSPortMessage internally and crashes when called from mpv's unregistered
     C threads.  Redraws are driven by the timer in GMPVVideoView instead. */
}
#endif

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
  if (_eglLibraryHandle != NULL)
    {
      dlclose(_eglLibraryHandle);
      _eglLibraryHandle = NULL;
    }
#endif
#endif
}

- (void)logVAAPIAvailability
{
  void *lib = dlopen("libva.so.2", RTLD_LAZY | RTLD_LOCAL);
  if (lib == NULL)
    lib = dlopen("libva.so.1", RTLD_LAZY | RTLD_LOCAL);
  BOOL libFound = (lib != NULL);
  if (lib != NULL)
    dlclose(lib);

  /* Check the most common DRM render node; scan D128–D135 to catch systems
     where the primary GPU is not at D128. */
  NSString *foundNode = nil;
  int n;
  for (n = 128; n <= 135; n++)
    {
      char path[32];
      snprintf(path, sizeof(path), "/dev/dri/renderD%d", n);
      if (access(path, R_OK | W_OK) == 0)
        {
          foundNode = [NSString stringWithUTF8String:path];
          break;
        }
    }

  NSLog(@"[gMPV] VAAPI probe: libva=%@  DRM node=%@",
        libFound ? @"found" : @"NOT FOUND",
        foundNode != nil ? foundNode : @"none accessible");
  if (libFound && foundNode != nil)
    NSLog(@"[gMPV] VAAPI: available — hwdec=vaapi-copy should work");
  else
    NSLog(@"[gMPV] VAAPI: unavailable — software decode will be used");
}

- (void)logEGLExtensions
{
#if GMPV_HAS_RENDER_GL
  /* Use the already-loaded EGL library handle if available, otherwise open
     it transiently just for this probe. */
  void *handle = _eglLibraryHandle;
  BOOL ownHandle = NO;
  if (handle == NULL)
    {
      handle = dlopen("libEGL.so.1", RTLD_LAZY | RTLD_LOCAL);
      ownHandle = YES;
    }

  if (handle == NULL)
    {
      NSLog(@"[gMPV] EGL probe: libEGL not loaded — cannot query extensions");
      return;
    }

  typedef void *EGLDisplayHandle;
  typedef EGLDisplayHandle (*GetCurrDispFn)(void);
  typedef const char   *(*QueryStringFn)(EGLDisplayHandle, int);
  /* EGL_NO_DISPLAY = NULL, EGL_EXTENSIONS = 0x3054 */
  GetCurrDispFn getCurrDisp = (GetCurrDispFn)dlsym(handle, "eglGetCurrentDisplay");
  QueryStringFn queryString = (QueryStringFn)dlsym(handle, "eglQueryString");

  if (getCurrDisp == NULL || queryString == NULL)
    {
      NSLog(@"[gMPV] EGL probe: eglGetCurrentDisplay/eglQueryString not found in libEGL");
      if (ownHandle) dlclose(handle);
      return;
    }

  EGLDisplayHandle dpy = getCurrDisp();
  NSLog(@"[gMPV] EGL probe: current display=%p", dpy);

  if (dpy != NULL)
    {
      const char *exts = queryString(dpy, 0x3055 /* EGL_EXTENSIONS */);
      if (exts != NULL)
        {
          BOOL hasDmaBuf   = strstr(exts, "EGL_EXT_image_dma_buf_import") != NULL;
          BOOL hasModifiers = strstr(exts, "EGL_EXT_image_dma_buf_import_modifiers") != NULL;
          BOOL hasImageBase = strstr(exts, "EGL_KHR_image_base") != NULL;
          NSLog(@"[gMPV] EGL display extensions:");
          NSLog(@"[gMPV]   EGL_EXT_image_dma_buf_import          = %@ %@",
                hasDmaBuf ? @"YES" : @"NO",
                hasDmaBuf ? @"← vaapi direct interop possible"
                          : @"← vaapi-copy required");
          NSLog(@"[gMPV]   EGL_EXT_image_dma_buf_import_modifiers = %@",
                hasModifiers ? @"YES" : @"NO");
          NSLog(@"[gMPV]   EGL_KHR_image_base                     = %@",
                hasImageBase ? @"YES" : @"NO");
        }
      else
        {
          NSLog(@"[gMPV] EGL probe: eglQueryString returned NULL");
        }
    }

  /* Probe client extensions (EGL 1.5+, display-independent).  libglvnd
     returns its version string instead of real extensions for NULL display,
     so only log when the result looks like an actual extension list. */
  const char *clientExts = queryString(NULL /* EGL_NO_DISPLAY */, 0x3055);
  if (clientExts != NULL && strstr(clientExts, "EGL_") != NULL)
    NSLog(@"[gMPV] EGL client extensions: %s", clientExts);
  else
    NSLog(@"[gMPV] EGL client extensions: unavailable (libglvnd dispatch)");

  if (ownHandle)
    dlclose(handle);

  /* Check the GL extensions needed for direct VAAPI→GL texture interop.
     GL_OES_EGL_image / glEGLImageTargetTexture2DOES is required for vaapi
     (zero-copy) but is an OpenGL ES extension — absent from desktop GL core
     profiles.  If missing, vaapi-copy is the only working hwdec mode. */
  const GLubyte *glExts = glGetString(GL_EXTENSIONS);
  if (glExts != NULL)
    {
      const char *s = (const char *)glExts;
      BOOL hasOESImage    = strstr(s, "GL_OES_EGL_image")          != NULL;
      BOOL hasOESExternal = strstr(s, "GL_OES_EGL_image_external") != NULL;
      BOOL hasEXTStorage  = strstr(s, "GL_EXT_EGL_image_storage")  != NULL;
      NSLog(@"[gMPV] GL extensions for VAAPI direct interop:");
      NSLog(@"[gMPV]   GL_OES_EGL_image         = %@%@", hasOESImage ? @"YES" : @"NO",
            hasOESImage ? @"" : @" ← vaapi (direct) will produce black frames");
      NSLog(@"[gMPV]   GL_OES_EGL_image_external = %@", hasOESExternal ? @"YES" : @"NO");
      NSLog(@"[gMPV]   GL_EXT_EGL_image_storage  = %@", hasEXTStorage  ? @"YES" : @"NO");
      if (!hasOESImage && !hasEXTStorage)
        NSLog(@"[gMPV]   → use hwdec=vaapi-copy or hwdec=no");
    }
  else
    NSLog(@"[gMPV] GL extensions: glGetString returned NULL (core profile — check glGetStringi)");
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
  mpv_set_option_string(_mpv, "log-file", "/tmp/gmpv-mpv.log");
  mpv_set_option_string(_mpv, "msg-level", "all=v");
  /* All required extensions are present (EGL_EXT_image_dma_buf_import,
     GL_OES_EGL_image, GL_EXT_EGL_image_storage) but hwdec=vaapi still
     produces black frames — likely a DRM format/modifier or VAAPI display
     mismatch that is only visible in mpv's own log.  Use vaapi-copy for now;
     it reads decoded frames back to system memory before the GL upload so it
     bypasses the EGL image path entirely and is known to work. */
  mpv_set_option_string(_mpv, "hwdec", "vaapi-copy");

  if (mpv_initialize(_mpv) < 0)
    {
      NSLog(@"Failed to initialize mpv");
      mpv_terminate_destroy(_mpv);
      _mpv = NULL;
      return;
    }

  _initialized = YES;
  self.ready = YES;
  [self logVAAPIAvailability];
#else
  NSLog(@"Built without libmpv headers. Player backend is stubbed.");
  self.ready = NO;
#endif
}

- (BOOL)setupRenderContextWithWaylandDisplay:(void *)waylandDisplay
{
#if GMPV_HAS_LIBMPV && GMPV_HAS_RENDER_GL
  if (_mpv == NULL || !_initialized || _renderContext != NULL)
    return _renderContext != NULL;

  mpv_opengl_init_params glInitParams;
  memset(&glInitParams, 0, sizeof(glInitParams));
  glInitParams.get_proc_address = gmpvGetProcAddress;
  glInitParams.get_proc_address_ctx = (__bridge void *)self;

  int advancedControl = 1;
  /* Do not pass MPV_RENDER_PARAM_WL_DISPLAY: our WaylandGLContext creates
     the EGL display via eglGetDisplay() but mpv validates via
     eglGetPlatformDisplayEXT(), so the handles differ and mpv returns -18.
     Without the hint mpv auto-detects the current EGL context, which works
     for both the Wayland/EGL and X11/GLX backends. */
  mpv_render_param params[] = {
    {MPV_RENDER_PARAM_API_TYPE, (void *)MPV_RENDER_API_TYPE_OPENGL},
    {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glInitParams},
    {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advancedControl},
    {MPV_RENDER_PARAM_INVALID, NULL}
  };

  (void)waylandDisplay;
  int rc = mpv_render_context_create(&_renderContext, _mpv, params);
  if (rc < 0)
    {
      NSLog(@"Failed to create mpv render context (%d)", rc);
      _renderContext = NULL;
      return NO;
    }

  mpv_render_context_set_update_callback(_renderContext,
                                         gmpvRenderUpdateCallback,
                                         (__bridge void *)self);

  /* Log EGL DMA-BUF interop availability now that the EGL context is current
     (mpv's context probe ran during mpv_render_context_create above). */
  [self logEGLExtensions];

  return YES;
#else
  (void)waylandDisplay;
  return NO;
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

  static NSUInteger _renderCount = 0;
  if (++_renderCount <= 5 || _renderCount % 90 == 0)
    NSLog(@"[gMPV] mpv_render_context_render #%lu fbo=%d %dx%d flipY=%d",
          (unsigned long)_renderCount, framebuffer, width, height, flipY);

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

  int rc = mpv_render_context_render(_renderContext, renderParams);
  if ((_renderCount <= 5 || _renderCount % 90 == 0) && rc != 0)
    NSLog(@"[gMPV] mpv_render_context_render returned %d", rc);
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

- (BOOL)isRenderContextReady
{
#if GMPV_HAS_LIBMPV && GMPV_HAS_RENDER_GL
  return _renderContext != NULL;
#else
  return NO;
#endif
}

- (double)currentTimePosition
{
#if GMPV_HAS_LIBMPV
  if (_mpv != NULL && _initialized)
    {
      double pos = 0.0;
      mpv_get_property(_mpv, "time-pos", MPV_FORMAT_DOUBLE, &pos);
      return pos;
    }
#endif
  return 0.0;
}

- (double)duration
{
#if GMPV_HAS_LIBMPV
  if (_mpv != NULL && _initialized)
    {
      double dur = 0.0;
      mpv_get_property(_mpv, "duration", MPV_FORMAT_DOUBLE, &dur);
      return dur;
    }
#endif
  return 0.0;
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
