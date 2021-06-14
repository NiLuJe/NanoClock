# SPDX-License-Identifier: GPL-3.0-or-later
#
# Pickup our cross-toolchains automatically...
# c.f., http://trac.ak-team.com/trac/browser/niluje/Configs/trunk/Kindle/Misc/x-compile.sh
#       https://github.com/NiLuJe/crosstool-ng
#       https://github.com/koreader/koxtoolchain
# NOTE: We want the "bare" variant of the TC env, to make sure we vendor the right stuff...
#       i.e., source ~SVN/Configs/trunk/Kindle/Misc/x-compile.sh kobo env bare
ifdef CROSS_TC
	CC:=$(CROSS_TC)-gcc
	STRIP:=$(CROSS_TC)-strip
else
	CC?=gcc
	STRIP?=strip
endif

DEBUG_CFLAGS:=-Og -fno-omit-frame-pointer -pipe -g
# Fallback CFLAGS, we honor the env first and foremost!
OPT_CFLAGS:=-O2 -fomit-frame-pointer -pipe

ifdef DEBUG
	CFLAGS:=$(DEBUG_CFLAGS)
	EXTRA_CPPFLAGS+=-DDEBUG
else
	CFLAGS?=$(OPT_CFLAGS)
	EXTRA_CPPFLAGS+=-DNDEBUG
endif

# Chuck our binaries in there
OUT_DIR:=build

# Detect whether our TC is cross (at least as far as the target arch is concerned)
HOST_ARCH:=$(shell uname -m)
TARGET_ARCH:=$(shell $(CC) $(CFLAGS) -dumpmachine 2>/dev/null)
CC_IS_CROSS:=0
# Host doesn't match target, assume it's a cross TC
ifeq (,$(findstring $(HOST_ARCH),$(TARGET_ARCH)))
	CC_IS_CROSS:=1
endif

# A version tag...
NANOCLOCK_VERSION:=$(shell git describe)
# A timestamp, in YYYY-MM-DD format (for the latest commit)...
NANOCLOCK_TIMESTAMP:=$(shell git show -s --format=%cs)

# NOTE: Always use as-needed to avoid unecessary DT_NEEDED entries :)
LDFLAGS?=-Wl,--as-needed

# We're Linux-bound...
EXTRA_CPPFLAGS+=-D_GNU_SOURCE

# For LuaFileSystem
LUA_INCDIR:=$(CURDIR)/LuaJIT/src
LFS_CPPFLAGS:=-I$(LUA_INCDIR)
LFS_CFLAGS:=-fpic
LFS_LDFLAGS:=-shared

##
# Now that we're done fiddling with flags, let's build stuff!
LFS_SRCS:=luafilesystem/src/lfs.c

default: all

LFS_OBJS:=$(addprefix $(OUT_DIR)/, $(LFS_SRCS:.c=.o))

$(OUT_DIR)/%.o: %.c
	$(CC) $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(LFS_CPPFLAGS) $(CFLAGS) $(EXTRA_CFLAGS) $(LFS_CFLAGS) -o $@ -c $<

outdir:
	mkdir -p $(OUT_DIR)/luafilesystem/src/

# Make absolutely sure we create our output directories first, even with unfortunate // timings!
# c.f., https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html#Prerequisite-Types
$(LFS_OBJS): | outdir

all: nanoclock

armcheck:
ifeq (,$(findstring arm-,$(CC)))
	$(error You forgot to setup a cross TC, you dummy!)
endif

nanoclock: armcheck fbink.built luajit.built lfs
	mkdir -p Kobo/usr/local/NanoClock/etc Kobo/usr/local/NanoClock/bin Kobo/usr/local/NanoClock/lib Kobo/usr/local/NanoClock/kmod Kobo/etc/udev/rules.d Kobo/mnt/onboard/.adds/nanoclock Kobo/mnt/onboard/.kobo
	ln -sf $(CURDIR)/scripts/99-nanoclock.rules Kobo/etc/udev/rules.d/99-nanoclock.rules
	ln -sf $(CURDIR)/scripts/nanoclock-launcher.sh Kobo/usr/local/NanoClock/bin/nanoclock-launcher.sh
	ln -sf $(CURDIR)/scripts/nanoclock.sh Kobo/usr/local/NanoClock/bin/nanoclock.sh
	ln -sf $(CURDIR)/config/nanoclock.ini Kobo/usr/local/NanoClock/etc/nanoclock.ini
	ln -sf $(CURDIR)/lib Kobo/usr/local/NanoClock/lib
	ln -sf $(CURDIR)/kmod Kobo/usr/local/NanoClock/kmod
	ln -sf $(CURDIR)/$(OUT_DIR)/fbink Kobo/usr/local/NanoClock/bin/fbink
	ln -sf $(CURDIR)/$(OUT_DIR)/luajit Kobo/usr/local/NanoClock/bin/luajit
	ln -sf $(CURDIR)/$(OUT_DIR)/libfbink.so.1.0.0 Kobo/usr/local/NanoClock/lib/libfbink.so.1.0.0
	ln -sf $(CURDIR)/$(OUT_DIR)/lfs.so Kobo/usr/local/NanoClock/lib/lfs.so
	tar --exclude="./mnt" --exclude="NanoClock-*.zip" --owner=root --group=root --hard-dereference -cvzhf $(OUT_DIR)/KoboRoot.tgz -C Kobo .
	ln -sf $(CURDIR)/$(OUT_DIR)/KoboRoot.tgz Kobo/mnt/onboard/.kobo/KoboRoot.tgz
	pushd Kobo/mnt/onboard && zip -r ../../NanoClock-$(NANOCLOCK_VERSION)-$(NANOCLOCK_TIMESTAMP).zip . && popd

clean:
	rm -rf Kobo

fbink.built: | outdir
	# Minimal CLI first
	cd FBInk && \
	$(MAKE) strip KOBO=true MINIMAL=true
	cp -av FBInk/Release/fbink $(OUT_DIR)/fbink

	# Then our shared library
	cd FBInk && \
	$(MAKE) clean
	cd FBInk && \
	$(MAKE) release KOBO=true MINIMAL=true FONTS=true OPENTYPE=true
	cp -av FBInk/Release/libfbink.so.1.0.0 $(OUT_DIR)/libfbink.so.1.0.0

	touch fbink.built

luajit.built: | outdir
	cd LuaJIT && \
	$(MAKE) HOST_CC="gcc -m32" CFLAGS="" CCOPT="" HOST_CFLAGS="-O2 -march=native -pipe" CROSS="$(CROSS_PREFIX)" TARGET_CFLAGS="$(CFLAGS)" clean
	cd LuaJIT && \
	$(MAKE) HOST_CC="gcc -m32" CFLAGS="" CCOPT="" HOST_CFLAGS="-O2 -march=native -pipe" CROSS="$(CROSS_PREFIX)" TARGET_CFLAGS="$(CFLAGS)" amalg
	cp -av LuaJIT/src/luajit $(OUT_DIR)/luajit

	touch luajit.built

lfs: | outdir luajit.built $(LFS_OBJS)
	$(CC) $(CPPFLAGS) $(EXTRA_CPPFLAGS) $(LFS_CPPFLAGS) $(CFLAGS) $(EXTRA_CFLAGS) $(LFS_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) $(LFS_LDFLAGS) -o$(OUT_DIR)/lfs.so $(LFS_OBJS)
	$(STRIP) --strip-unneeded $(OUT_DIR)/lfs.so

fbinkclean:
	cd FBInk && \
	$(MAKE) clean

luajitclean:
	cd LuaJIT && \
	make clean && \
	git reset --hard && \
	git clean -fxdq

distclean: clean luajitclean fbinkclean
	rm -rf $(OUT_DIR)
	rm -rf luajit.built
	rm -rf fbink.built

.PHONY: default outdir all nanoclock armcheck clean fbinkclean luajitclean distclean
