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
  NSOpenGLContext *_glContext;
  BOOL _renderContextReady;
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
  self = [super initWithFrame:frame];
  return self;
}

- (void)dealloc
{
  if (_glContext != nil)
    {
      [_glContext makeCurrentContext];
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

- (void)ensureGLContext
{
  if (_glContext != nil)
    return;

  NSOpenGLPixelFormat *fmt = [GMPVVideoView defaultPixelFormat];
  _glContext = [[NSOpenGLContext alloc] initWithFormat:fmt shareContext:nil];
  if (_glContext != nil)
    [_glContext setView:self];
}

- (void)ensureRenderContext
{
  if (_renderContextReady || self.player == nil || _glContext == nil)
    return;

  [_glContext makeCurrentContext];
  [self.player setupRenderContextWithWaylandDisplay:self.waylandDisplay];
  _renderContextReady = YES;
}

- (void)bindPlayer:(GMPVMPVPlayer *)player
    waylandDisplay:(void *)waylandDisplay
{
  self.player = player;
  self.waylandDisplay = waylandDisplay;
  [self setNeedsDisplay:YES];
}

- (void)requestRedraw
{
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
  [self ensureGLContext];

  if (_glContext == nil)
    {
      [[NSColor blackColor] set];
      NSRectFill(dirtyRect);
      return;
    }

  [self ensureRenderContext];
  [_glContext makeCurrentContext];
  [_glContext update];

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

  [_glContext flushBuffer];
}

@end
