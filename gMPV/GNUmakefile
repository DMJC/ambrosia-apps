include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = gMPV

gMPV_OBJC_FILES = \
  main.m \
  GMPVAppDelegate.m \
  GMPVPlayerWindowController.m \
  GMPVVideoView.m \
  GMPVMPVPlayer.m

gMPV_HEADER_FILES = \
  GMPVAppDelegate.h \
  GMPVPlayerWindowController.h \
  GMPVVideoView.h \
  GMPVMPVPlayer.h

gMPV_RESOURCE_FILES =

gMPV_GUI_LIBS = -lmpv

ADDITIONAL_CPPFLAGS += -MMD -MP -DGNUSTEP
ADDITIONAL_OBJCFLAGS += -fobjc-arc

include $(GNUSTEP_MAKEFILES)/application.make
