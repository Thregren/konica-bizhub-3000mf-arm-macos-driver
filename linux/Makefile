# Linux CUPS filter for KONICA MINOLTA bizhub 2600P / 3000MF / 3080MF
#
# This is a Linux build of the open-source brlaser-based CUPS filter that
# converts application/vnd.cups-raster into the PJL + Brother HBP *b1030m
# stream used by these Brother-engine Konica machines.
#
# Note: this build intentionally omits the macOS scan/ICA components.
# Printing only.  Link against libcupsimage (raster API) + libcups.

CXX     ?= c++
CXXFLAGS ?= -O2 -Wall -Wno-missing-braces -std=c++11

PREFIX    ?= /usr
FILTERDIR ?= $(PREFIX)/lib/cups/filter
PPDDIR    ?= $(PREFIX)/share/cups/model/konica
DESTDIR   ?=

SOURCES := src/main.cc src/job.cc src/line.cc src/debug.cc
OBJECTS := $(SOURCES:.cc=.o)

.PHONY: all install uninstall clean

all: rastertobrlaser

rastertobrlaser: $(OBJECTS)
	$(CXX) -o $@ $(OBJECTS) -lcupsimage -lcups

%.o: %.cc
	$(CXX) $(CXXFLAGS) -Isrc -c $< -o $@

install: rastertobrlaser
	install -d $(DESTDIR)$(FILTERDIR)
	install -m 755 rastertobrlaser $(DESTDIR)$(FILTERDIR)/
	install -d $(DESTDIR)$(PPDDIR)
	install -m 644 ppd/*.ppd $(DESTDIR)$(PPDDIR)/

uninstall:
	rm -f $(DESTDIR)$(FILTERDIR)/rastertobrlaser
	rm -f $(DESTDIR)$(PPDDIR)/KONICA\ MINOLTA\ bizhub*.ppd
	rmdir $(DESTDIR)$(PPDDIR) 2>/dev/null || true

clean:
	rm -f $(OBJECTS) rastertobrlaser
