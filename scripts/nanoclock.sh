#!/bin/sh

# Settings
SCRIPT_NAME="$(basename "${0}")"
NANOCLOCK_DIR="/usr/local/NanoClock"
FBINK_BIN="./bin/fbink"

# We expect our PWD to be NanoClock's base folder
cd "${NANOCLOCK_DIR}" || logger -p "DAEMON.CRIT" -t "${SCRIPT_NAME}[$$]" "NanoClock base folder not found!" && exit

# Wait until nickel is up
while ! pidof nickel >/dev/null 2>&1 || ! grep -q /mnt/onboard /proc/mounts ; do
	sleep 5
done

# Platform checks
eval "$(${FBINK_BIN} -e)"
# shellcheck disable=SC2154
DEVICE_GEN="mk$(echo "${devicePlatform}" | sed -re 's/^.+([[:digit:]]+)$/\1/')"

PLATFORM="freescale"
if [ "$(dd if=/dev/mmcblk0 bs=512 skip=1024 count=1 | grep -c "HW CONFIG")" = 1 ] ; then
	CPU="$(ntx_hwconfig -s -p /dev/mmcblk0 CPU)"
	PLATFORM="${CPU}-ntx"
fi

# Load the right kernel module
KMOD_PATH="./kmod/${DEVICE_GEN}/${PLATFORM}/mxc_epdc_fb_damage.ko"
if [ ! -f "${KMOD_PATH}" ] ; then
	logger -p "DAEMON.CRIT" -t "${SCRIPT_NAME}[$$]" "Platform ${DEVICE_GEN}/${PLATFORM} is unsupported: no kernel module!"
	exit
fi

if grep -q "mxc_epdc_fb_damage" "/proc/modules" ; then
	logger -p "DAEMON.NOTICE" -t "${SCRIPT_NAME}[$$]" "Kernel module for platform ${DEVICE_GEN}/${PLATFORM} is already loaded!"
else
	insmod "${KMOD_PATH}" || logger -p "DAEMON.ERR" -t "${SCRIPT_NAME}[$$]" "Platform ${DEVICE_GEN}/${PLATFORM} is unsupported: failed to load the kernel module!" && exit
fi

# And here we go!
exec ./nanoclock.lua
