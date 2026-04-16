include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = gMPV gTunes

.PHONY: all clean install $(SUBPROJECTS)

all: $(SUBPROJECTS)

$(SUBPROJECTS):
	$(MAKE) -C $@

clean:
	for dir in $(SUBPROJECTS); do \
		$(MAKE) -C $$dir clean; \
	done

install:
	for dir in $(SUBPROJECTS); do \
		$(MAKE) -C $$dir install; \
	done
