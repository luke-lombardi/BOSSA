.DEFAULT_GOAL := all

#
# Version
#
VERSION=1.7.0
WXVERSION=3.0

#
# Source files
#
COMMON_SRCS=Samba.cpp Flash.cpp NvmFlash.cpp EfcFlash.cpp EefcFlash.cpp FlashFactory.cpp Applet.cpp WordCopyApplet.cpp Flasher.cpp
APPLET_SRCS=WordCopyArm.asm
BOSSAC_SRCS=bossac.cpp CmdOpts.cpp

#
# Build directories
#
BINDIR=bin
OBJDIR=obj
SRCDIR=src
RESDIR=res
INSTALLDIR=install

#
# Determine OS
#
OS:=$(shell uname -s | cut -c -7)

#
# Linux rules
#
ifeq ($(OS),Linux)
COMMON_SRCS+=PosixSerialPort.cpp LinuxPortFactory.cpp
COMMON_LIBS=-Wl,--as-needed
WX_LIBS+=-lX11

MACHINE:=$(shell uname -m)

install: strip
	tar cvzf $(BINDIR)/bossa-$(MACHINE)-$(VERSION).tgz -C $(BINDIR) bossa$(EXE) bossac$(EXE) bossash$(EXE)
endif

#
# Object files
#
COMMON_OBJS=$(foreach src,$(COMMON_SRCS),$(OBJDIR)/$(src:%.cpp=%.o))
APPLET_OBJS=$(foreach src,$(APPLET_SRCS),$(OBJDIR)/$(src:%.asm=%.o))
ifdef BOSSA_RC
BOSSA_OBJS+=$(OBJDIR)/$(BOSSA_RC:%.rc=%.o)
endif
BOSSAC_OBJS=$(APPLET_OBJS) $(COMMON_OBJS) $(foreach src,$(BOSSAC_SRCS),$(OBJDIR)/$(src:%.cpp=%.o))

#
# Dependencies
#
DEPENDS=$(COMMON_SRCS:%.cpp=$(OBJDIR)/%.d)
DEPENDS+=$(APPLET_SRCS:%.asm=$(OBJDIR)/%.d)
DEPENDS+=$(BOSSAC_SRCS:%.cpp=$(OBJDIR)/%.d)

#
# Tools
#
#Q=@
CXX?=g++
ARM=arm-none-eabi-
ARMAS=$(ARM)as
ARMOBJCOPY=$(ARM)objcopy

#
# CXX Flags
#
# COMMON_CXXFLAGS+=-Wall -Werror -MT $@ -MD -MP -MF $(@:%.o=%.d) -DVERSION=\"$(VERSION)\" -g -O2
COMMON_CXXFLAGS+=-Wall -MT $@ -MD -MP -MF $(@:%.o=%.d) -DVERSION=\"$(VERSION)\" -g -O2 $(CXXFLAGS)
WX_CXXFLAGS:=$(shell wx-config --cxxflags --version=$(WXVERSION)) -DWX_PRECOMP -Wno-ctor-dtor-privacy -O2 -fno-strict-aliasing
BOSSAC_CXXFLAGS=$(COMMON_CXXFLAGS)

#
# LD Flags
#
COMMON_LDFLAGS+=-g $(LDFLAGS)
BOSSAC_LDFLAGS=$(COMMON_LDFLAGS)

#
# Libs
#
COMMON_LIBS+=
WX_LIBS:=$(shell wx-config --libs --version=$(WXVERSION)) $(WX_LIBS)
BOSSAC_LIBS=$(COMMON_LIBS)

#
# Main targets
#
all: $(BINDIR)/bossa$(EXE) $(BINDIR)/bossac$(EXE)

#
# Common rules
#
define common_obj
$(OBJDIR)/$(1:%.cpp=%.o): $(SRCDIR)/$(1)
	@echo CPP COMMON $$<
	$$(Q)$$(CXX) $$(COMMON_CXXFLAGS) -c -o $$@ $$<
endef
$(foreach src,$(COMMON_SRCS),$(eval $(call common_obj,$(src))))

#
# Resource rules
#
ifeq ($(OS),MINGW32)
$(OBJDIR)/$(BOSSA_RC:%.rc=%.o): $(RESDIR)/$(BOSSA_RC)
	@echo RC $<
	$(Q)`wx-config --rescomp --version=$(WXVERSION)` -o $@ $<
endif

#
# Applet rules
#
define applet_obj
$(SRCDIR)/$(1:%.asm=%.cpp): $(SRCDIR)/$(1)
	@echo APPLET $(1:%.asm=%)
	$$(Q)$$(ARMAS) -o $$(@:%.o=%.obj) $$<
	$$(Q)$$(ARMOBJCOPY) -O binary $$(@:%.o=%.obj) $$(@:%.o=%.bin)
	$$(Q)appletgen $(1:%.asm=%) $(SRCDIR) $(OBJDIR)
$(OBJDIR)/$(1:%.asm=%.o): $(SRCDIR)/$(1:%.asm=%.cpp)
	@echo CPP APPLET $$<
	$$(Q)$$(CXX) $$(COMMON_CXXFLAGS) -c -o $$(@) $$(<:%.asm=%.cpp)
endef
$(foreach src,$(APPLET_SRCS),$(eval $(call applet_obj,$(src))))

#
# BOSSAC rules
#
define bossac_obj
$(OBJDIR)/$(1:%.cpp=%.o): $(SRCDIR)/$(1)
	@echo CPP BOSSAC $$<
	$$(Q)$$(CXX) $$(BOSSAC_CXXFLAGS) -c -o $$@ $$<
endef
$(foreach src,$(BOSSAC_SRCS),$(eval $(call bossac_obj,$(src))))

#
# Directory rules
#
$(OBJDIR):
	@mkdir $@

$(BINDIR):
	@mkdir $@

#
# Target rules
#
$(BOSSAC_OBJS): | $(OBJDIR)
$(BINDIR)/bossac$(EXE): $(BOSSAC_OBJS) | $(BINDIR)
	@echo LD $@
	$(Q)$(CXX) $(BOSSAC_LDFLAGS) -o $@ $(BOSSAC_OBJS) $(BOSSAC_LIBS)

strip-bossac: $(BINDIR)/bossac$(EXE)
	@echo STRIP $^
	$(Q)strip $^

strip: strip-bossac

clean:
	@echo CLEAN
	$(Q)rm -rf $(BINDIR) $(OBJDIR)

build-container:
	docker build -f docker/Dockerfile -t proteus-bossa-dev .

start-container:
	docker-compose -f docker/docker-compose.yml up -d

shell:
	docker exec -it $(shell docker ps | grep bossa | cut -d ' ' -f 1) /bin/bash

#
# Include dependencies
#
-include $(DEPENDS)
