#import "GMPVVideoView.h"

@implementation GMPVVideoView

- (instancetype)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
    {
    }
  return self;
}

- (BOOL)isFlipped
{
  return YES;
}

- (void)requestRedraw
{
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
  [super drawRect:dirtyRect];

  [[NSColor blackColor] setFill];
  NSRectFill(dirtyRect);

  NSDictionary *attrs = @{
    NSForegroundColorAttributeName: NSColor.lightGrayColor,
    NSFontAttributeName: [NSFont systemFontOfSize:13.0]
  };
  NSString *placeholder = @"libmpv OpenGL video output";
  NSSize size = [placeholder sizeWithAttributes:attrs];
  NSRect bounds = self.bounds;
  NSPoint p = NSMakePoint((NSWidth(bounds) - size.width) / 2.0,
                          (NSHeight(bounds) - size.height) / 2.0);
  [placeholder drawAtPoint:p withAttributes:attrs];
}

@end
