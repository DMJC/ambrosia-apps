include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = gTunes

gTunes_OBJCC_FILES =  Source/main.mm \
    Source/AppDelegate.mm \
    Source/Preferences.mm \
    Source/PreferencesWindowController.mm \
    Source/MusicTrack.mm \
    Source/MusicLibrary.mm \
    Source/AudioPlayer.mm \
    Source/MainWindowController.mm \
    Source/LibrarySidebarController.mm \
    Source/BrowserController.mm \
    Source/TrackListController.mm \
    Source/NowPlayingBar.mm \
    Source/RatingCell.mm

gTunes_APPLICATION_ICON = gTunes.tiff

gTunes_RESOURCE_FILES = gTunes.tiff \
    Resources/no_volume.tiff \
    Resources/full_volume.tiff \

gTunes_CPPFLAGS  = $(shell pkg-config --cflags gstreamer-1.0 taglib) -std=c++17
gTunes_LDFLAGS   = $(shell pkg-config --libs   gstreamer-1.0 taglib)
gTunes_OBJCCFLAGS = -std=c++17 -fobjc-arc-exceptions

include $(GNUSTEP_MAKEFILES)/application.make
