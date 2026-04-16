#import "GMPVVideoView.h"

#import "GMPVMPVPlayer.h"

#include <math.h>

#if __has_include(<OpenGL/gl.h>)
  #import <OpenGL/gl.h>
#elif __has_include(<GL/gl.h>)
  #import <GL/gl.h>
#endif

@interface GMPVVideoView ()

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

  NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
  return format;
}

- (instancetype)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame pixelFormat:[GMPVVideoView defaultPixelFormat]];
  if (self)
    {
    }
  return self;
}

- (void)dealloc
{
  [self.openGLContext makeCurrentContext];
  [self.player teardownRenderContext];
}

- (BOOL)isFlipped
{
  return YES;
}

- (void)prepareOpenGL
{
  [super prepareOpenGL];
  [self.openGLContext makeCurrentContext];
  [self.player setupRenderContextWithWaylandDisplay:self.waylandDisplay];
}

- (void)reshape
{
  [super reshape];
  [self requestRedraw];
}

- (void)bindPlayer:(GMPVMPVPlayer *)player
    waylandDisplay:(void *)waylandDisplay
{
  self.player = player;
  self.waylandDisplay = waylandDisplay;

  if (self.openGLContext != nil)
    {
      [self.openGLContext makeCurrentContext];
      [self.player setupRenderContextWithWaylandDisplay:self.waylandDisplay];
      [self requestRedraw];
    }
}

- (void)requestRedraw
{
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
  [self.openGLContext makeCurrentContext];

  GLint fbo = 0;
  glGetIntegerv(GL_FRAMEBUFFER_BINDING, &fbo);

  NSRect bounds = [self bounds];
  CGFloat scale = 1.0;
  if ([self window] != nil)
    {
      scale = [[self window] backingScaleFactor];
      if (scale <= 0.0)
        {
          scale = 1.0;
        }
    }

  int width = (int)lround(NSWidth(bounds) * scale);
  int height = (int)lround(NSHeight(bounds) * scale);
  [self.player renderFrameWithFramebuffer:fbo
                                    width:width
                                   height:height
                                    flipY:[self isFlipped]];
  [self.openGLContext flushBuffer];

  if (self.player == nil)
    {
      [super drawRect:dirtyRect];
    }
}

@end
