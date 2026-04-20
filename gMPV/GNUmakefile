include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = gMPV

gMPV_OBJC_FILES = \
  main.m \
  GMPVAppDelegate.m \
  GMPVPlayerWindowController.m \
  GMPVVideoView.m \
  GMPVMPVPlayer.m \
  GMPVPreferencesWindowController.m

gMPV_HEADER_FILES = \
  GMPVAppDelegate.h \
  GMPVPlayerWindowController.h \
  GMPVVideoView.h \
  GMPVMPVPlayer.h \
  GMPVPreferencesWindowController.h

gMPV_APPLICATION_ICON = gMPV.tiff
gMPV_RESOURCE_FILES = gMPV.tiff

gMPV_GUI_LIBS = -lmpv -lGL

ADDITIONAL_CPPFLAGS += -MMD -MP -DGNUSTEP
ADDITIONAL_OBJCFLAGS += -fobjc-arc

include $(GNUSTEP_MAKEFILES)/application.make
