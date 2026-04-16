// RatingCell.mm
#import "RatingCell.h"

@implementation RatingCell

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view
{
    NSInteger rating = [self integerValue];  // 0–5
    CGFloat starSize = 10.0;
    CGFloat gap = 1.0;
    CGFloat totalW = 5 * starSize + 4 * gap;
    CGFloat x = frame.origin.x + (frame.size.width - totalW) / 2.0;
    CGFloat y = frame.origin.y + (frame.size.height - starSize) / 2.0;

    for (NSInteger i = 0; i < 5; i++) {
        NSRect r = NSMakeRect(x + i * (starSize + gap), y, starSize, starSize);
        NSColor *c = (i < rating)
            ? [NSColor colorWithCalibratedRed:0.0 green:0.47 blue:1.0 alpha:1.0]
            : [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
        [c set];
        // Draw a simple filled diamond as a star substitute
        NSBezierPath *star = [NSBezierPath bezierPath];
        CGFloat cx = NSMidX(r), cy = NSMidY(r), hr = starSize * 0.5;
        [star moveToPoint:NSMakePoint(cx, cy + hr)];
        [star lineToPoint:NSMakePoint(cx + hr * 0.4, cy + hr * 0.3)];
        [star lineToPoint:NSMakePoint(cx + hr, cy + hr * 0.1)];
        [star lineToPoint:NSMakePoint(cx + hr * 0.5, cy - hr * 0.3)];
        [star lineToPoint:NSMakePoint(cx + hr * 0.6, cy - hr)];
        [star lineToPoint:NSMakePoint(cx, cy - hr * 0.5)];
        [star lineToPoint:NSMakePoint(cx - hr * 0.6, cy - hr)];
        [star lineToPoint:NSMakePoint(cx - hr * 0.5, cy - hr * 0.3)];
        [star lineToPoint:NSMakePoint(cx - hr, cy + hr * 0.1)];
        [star lineToPoint:NSMakePoint(cx - hr * 0.4, cy + hr * 0.3)];
        [star closePath];
        [star fill];
    }
}

- (void)setObjectValue:(id)obj { [super setObjectValue:obj]; }

@end
