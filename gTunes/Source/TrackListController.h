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
@property (nonatomic, readonly) NSArray *tracks;        // full set (no search filter)
@property (nonatomic, readonly) NSArray *visibleTracks; // search-filtered set shown in table
- (void)setTableView:(NSTableView *)tv;
- (void)setTracks:(NSArray *)tracks;
- (void)filterBySearchString:(NSString *)s;
- (MusicTrack *)trackAtRow:(NSInteger)row;
@end
