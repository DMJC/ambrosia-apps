// LibrarySidebarController.h
#import <AppKit/AppKit.h>

@protocol LibrarySidebarDelegate
- (void)sidebarSelectedSection:(NSString *)section;  // e.g. "Music", playlist name
@end

@interface LibrarySidebarController : NSObject
    <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    NSOutlineView *_outlineView;
    NSArray       *_sections;     // top-level groups
    id<LibrarySidebarDelegate> _delegate;
}
@property (nonatomic, assign) id<LibrarySidebarDelegate> delegate;
- (void)setOutlineView:(NSOutlineView *)ov;
- (void)reload;
@end
