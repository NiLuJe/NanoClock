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
	mkdir -p Kobo/usr/local/kfmon/bin Kobo/usr/bin Kobo/etc/udev/rules.d Kobo/etc/init.d
	ln -sf $(CURDIR)/scripts/99-kfmon.rules Kobo/etc/udev/rules.d/99-kfmon.rules
	ln -sf $(CURDIR)/scripts/uninstall/kfmon-uninstall.sh Kobo/usr/local/kfmon/bin/kfmon-update.sh
	ln -sf $(CURDIR)/scripts/uninstall/on-animator.sh Kobo/etc/init.d/on-animator.sh
	tar --exclude="./mnt" --exclude="KFMon-*.zip" --owner=root --group=root -cvzhf Release/KoboRoot.tgz -C Kobo .
	pushd Release && zip ../Kobo/KFMon-Uninstaller.zip KoboRoot.tgz && popd
	rm -f Release/KoboRoot.tgz
	rm -rf Kobo/usr/local/kfmon/bin Kobo/etc/udev/rules.d Kobo/etc/init.d
	mkdir -p Kobo/usr/local/kfmon/bin Kobo/mnt/onboard/.kobo Kobo/etc/udev/rules.d Kobo/etc/init.d Kobo/mnt/onboard/.adds/kfmon/config Kobo/mnt/onboard/.adds/kfmon/bin Kobo/mnt/onboard/.adds/kfmon/log Kobo/mnt/onboard/icons
	ln -f $(CURDIR)/resources/koreader.png Kobo/mnt/onboard/koreader.png
	ln -f $(CURDIR)/resources/plato.png Kobo/mnt/onboard/icons/plato.png
	ln -f $(CURDIR)/resources/kfmon.png Kobo/mnt/onboard/kfmon.png
	ln -f $(CURDIR)/Release/kfmon Kobo/usr/local/kfmon/bin/kfmon
	ln -f $(CURDIR)/Release/shim Kobo/usr/local/kfmon/bin/shim
	ln -f $(CURDIR)/Release/kfmon-ipc Kobo/usr/local/kfmon/bin/kfmon-ipc
	ln -sf /usr/local/kfmon/bin/kfmon-ipc Kobo/usr/bin/kfmon-ipc
	ln -f $(CURDIR)/FBInk/Release/fbink Kobo/usr/local/kfmon/bin/fbink
	ln -f $(CURDIR)/README.md Kobo/usr/local/kfmon/README.md
	ln -f $(CURDIR)/LICENSE Kobo/usr/local/kfmon/LICENSE
	ln -f $(CURDIR)/CREDITS Kobo/usr/local/kfmon/CREDITS
	ln -f $(CURDIR)/scripts/99-kfmon.rules Kobo/etc/udev/rules.d/99-kfmon.rules
	ln -f $(CURDIR)/scripts/kfmon-update.sh Kobo/usr/local/kfmon/bin/kfmon-update.sh
	ln -f $(CURDIR)/scripts/on-animator.sh Kobo/etc/init.d/on-animator.sh
	tar --exclude="./mnt" --exclude="KFMon-*.zip" --owner=root --group=root --hard-dereference -cvzf Release/KoboRoot.tgz -C Kobo .
	ln -sf $(CURDIR)/Release/KoboRoot.tgz Kobo/mnt/onboard/.kobo/KoboRoot.tgz
	ln -sf $(CURDIR)/config/kfmon.ini Kobo/mnt/onboard/.adds/kfmon/config/kfmon.ini
	ln -sf $(CURDIR)/config/koreader.ini Kobo/mnt/onboard/.adds/kfmon/config/koreader.ini
	ln -sf $(CURDIR)/config/plato.ini Kobo/mnt/onboard/.adds/kfmon/config/plato.ini
	ln -sf $(CURDIR)/config/kfmon-log.ini Kobo/mnt/onboard/.adds/kfmon/config/kfmon-log.ini
	ln -sf $(CURDIR)/scripts/kfmon-printlog.sh Kobo/mnt/onboard/.adds/kfmon/bin/kfmon-printlog.sh
	pushd Kobo/mnt/onboard && zip -r ../../KFMon-$(KFMON_VERSION).zip . && popd

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
	cd sqlite && \
	make clean && \
	git reset --hard && \
	git clean -fxdq

distclean: clean luajitclean fbinkclean
	rm -rf $(OUT_DIR)
	rm -rf luajit.built
	rm -rf fbink.built

.PHONY: default outdir all nanoclock armcheck clean fbinkclean luajitclean distclean
