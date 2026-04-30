#import "GMPVVideoView.h"

#import "GMPVMPVPlayer.h"

#include <math.h>

#if __has_include(<OpenGL/gl.h>)
  #import <OpenGL/gl.h>
#elif __has_include(<GL/gl.h>)
  #import <GL/gl.h>
#endif

@interface GMPVVideoView ()
{
  BOOL _renderContextReady;
  NSTimer *_displayTimer;
}

@property (nonatomic, weak) GMPVMPVPlayer *player;
@property (nonatomic, assign) void *waylandDisplay;

@end

@implementation GMPVVideoView

+ (NSOpenGLPixelFormat *)defaultPixelFormat
{
  NSOpenGLPixelFormatAttribute attrs[] = {
    NSOpenGLPFADoubleBuffer,
    NSOpenGLPFAColorSize, (NSOpenGLPixelFormatAttribute)24,
    NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute)16,
    (NSOpenGLPixelFormatAttribute)0
  };
  return [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
}

- (instancetype)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame pixelFormat:[GMPVVideoView defaultPixelFormat]];
  return self;
}

- (void)dealloc
{
  [_displayTimer invalidate];
  _displayTimer = nil;

  NSOpenGLContext *ctx = [self openGLContext];
  if (ctx != nil)
    {
      [ctx makeCurrentContext];
      [self.player teardownRenderContext];
      [NSOpenGLContext clearCurrentContext];
    }
}

- (BOOL)isFlipped
{
  return YES;
}

- (BOOL)isOpaque
{
  return YES;
}

- (void)ensureRenderContext
{
  /* Caller must have already called makeCurrentContext + update on the GL
     context so that it is drawable-attached when mpv probes it. */
  if (_renderContextReady || self.player == nil)
    return;
  _renderContextReady = [self.player setupRenderContextWithWaylandDisplay:self.waylandDisplay];
}

- (void)bindPlayer:(GMPVMPVPlayer *)player
    waylandDisplay:(void *)waylandDisplay
{
  self.player = player;
  self.waylandDisplay = waylandDisplay;

  [_displayTimer invalidate];
  /* Drive redraws from a main-thread timer (same pattern as the MyGL test).
     GNUstep's performSelectorOnMainThread: routes through NSPortMessage which
     crashes when called from mpv's unregistered C threads, so the callback
     path cannot be used to trigger display.  ~30 fps is sufficient for
     smooth video playback. */
  _displayTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 30.0)
                                                   target:self
                                                 selector:@selector(requestRedraw)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)requestRedraw
{
  /* setNeedsDisplay:YES alone does not trigger drawRect: in GNUstep/Wayland —
     there is no compositor expose event to drive the deferred display cycle.
     Calling display directly forces an immediate synchronous redraw each time
     the timer fires, matching the pattern used by the MyGL test app. */
  static NSUInteger _timerCount = 0;
  ++_timerCount;
  /* Log every tick for the first second, then every 3 s */
  if (_timerCount <= 30 || _timerCount % 90 == 0)
    NSLog(@"[gMPV] requestRedraw #%lu", (unsigned long)_timerCount);

  /* GNUstep's Wayland display server rejects synchronous display calls while
     it is busy processing a drag operation, raising "mouseEvent with wrong
     type".  Catch and discard that exception so the timer survives; the next
     tick will render the skipped frame. */
  @try
    {
      [self display];
    }
  @catch (NSException *e)
    {
      (void)e;
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
  NSOpenGLContext *ctx = [self openGLContext];

  if (ctx == nil)
    {
      [[NSColor blackColor] set];
      NSRectFill(dirtyRect);
      return;
    }

  /* Attach the context to the drawable before anything else, including the
     mpv render context setup, so that mpv sees a fully initialised GL surface
     when it probes the current context. */
  [ctx makeCurrentContext];

  /* On Wayland, makeCurrentContext fails silently when the wl_surface does
     not exist yet (GNUstep calls drawRect: before orderwindow: creates it).
     Skip this frame entirely — the display timer will retry in ~33 ms. */
  if ([NSOpenGLContext currentContext] != ctx)
    {
      static NSUInteger _skipCount = 0;
      if (++_skipCount <= 3)
        NSLog(@"[gMPV] drawRect: skipped — context not current (#%lu)", (unsigned long)_skipCount);
      return;
    }

  [ctx update];

  static BOOL _firstDraw = YES;
  if (_firstDraw)
    {
      _firstDraw = NO;
      /* Ensure vsync is off — eglSwapBuffers with interval=1 blocks on the
         compositor frame callback and starves the main run loop. */
      long zero = 0;
      [ctx setValues:&zero forParameter:NSOpenGLCPSwapInterval];
      NSLog(@"[gMPV] drawRect: first live frame — renderContextReady=%d player=%@",
            _renderContextReady, self.player);
    }

  [self ensureRenderContext];

  GLint fbo = 0;
  glGetIntegerv(GL_FRAMEBUFFER_BINDING, &fbo);

  NSRect bounds = [self bounds];
  CGFloat scale = 1.0;
  if ([self window] != nil)
    {
      scale = [[self window] backingScaleFactor];
      if (scale <= 0.0)
        scale = 1.0;
    }

  int width = (int)lround(NSWidth(bounds) * scale);
  int height = (int)lround(NSHeight(bounds) * scale);

  static NSUInteger _frameCount = 0;
  if (++_frameCount <= 5 || _frameCount % 90 == 0)
    NSLog(@"[gMPV] drawRect: frame %lu fbo=%d %dx%d renderReady=%d",
          (unsigned long)_frameCount, (int)fbo, width, height, _renderContextReady);

  if (self.player != nil && _renderContextReady)
    {
      [self.player renderFrameWithFramebuffer:fbo
                                        width:width
                                       height:height
                                        flipY:[self isFlipped]];
    }
  else
    {
      glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
      glClear(GL_COLOR_BUFFER_BIT);
    }

  [ctx flushBuffer];
}

@end
