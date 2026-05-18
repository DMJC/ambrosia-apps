// LibrarySidebarController.h
#import <AppKit/AppKit.h>

@protocol LibrarySidebarDelegate
- (void)sidebarSelectedSection:(NSString *)section;  // e.g. "Music", playlist name
@optional
- (void)sidebarRenamedPlaylist:(NSString *)oldName to:(NSString *)newName;
@end

@interface LibrarySidebarController : NSObject
    <NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate>
{
    NSOutlineView *_outlineView;
    NSArray       *_sections;     // top-level groups
    id<LibrarySidebarDelegate> _delegate;
}
@property (nonatomic, assign) id<LibrarySidebarDelegate> delegate;
- (void)setOutlineView:(NSOutlineView *)ov;
- (void)reload;
@end
