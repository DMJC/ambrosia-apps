// TrackListController.h
#import <AppKit/AppKit.h>
#import "MusicTrack.h"

@interface TrackListController : NSObject
    <NSTableViewDataSource, NSTableViewDelegate>
{
    NSTableView    *_tableView;
    NSMutableArray *_tracks;
    NSArray        *_sortDescriptors;
    NSString       *_searchString;
}
@property (nonatomic, readonly) NSArray *tracks;
- (void)setTableView:(NSTableView *)tv;
- (void)setTracks:(NSArray *)tracks;
- (void)filterBySearchString:(NSString *)s;
- (MusicTrack *)trackAtRow:(NSInteger)row;
@end
