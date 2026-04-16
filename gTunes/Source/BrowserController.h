// BrowserController.h – the three-column Genre/Artist/Album browser
#import <AppKit/AppKit.h>
@protocol BrowserControllerDelegate
- (void)browserSelectionChangedWithGenre:(NSString *)genre
                                  artist:(NSString *)artist
                                   album:(NSString *)album;
@end

@interface BrowserController : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
    NSTableView *_genreTable;
    NSTableView *_artistTable;
    NSTableView *_albumTable;
    NSArray     *_genres;
    NSArray     *_artists;
    NSArray     *_albums;
    NSString    *_selectedGenre;
    NSString    *_selectedArtist;
    NSString    *_selectedAlbum;
    id<BrowserControllerDelegate> _delegate;
}
@property (nonatomic, assign) id<BrowserControllerDelegate> delegate;
- (void)setGenreTable:(NSTableView *)g
          artistTable:(NSTableView *)a
           albumTable:(NSTableView *)al;
- (void)reload;
@end
