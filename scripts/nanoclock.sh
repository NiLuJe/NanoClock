#!/bin/sh

# Misc helper functions
is_integer()
{
	# Cheap trick ;)
	[ "${1}" -eq "${1}" ] 2>/dev/null
	return $?
}


# Settings
SCRIPT_NAME="$(basename "${0}")"
NANOCLOCK_DIR="/usr/local/NanoClock"
FBINK_BIN="./bin/fbink"

# We expect our PWD to be NanoClock's base folder
if ! cd "${NANOCLOCK_DIR}" ; then
	logger -p "DAEMON.CRIT" -t "${SCRIPT_NAME}[$$]" "NanoClock base folder not found!"
	exit
fi

# Platform checks
eval "$(${FBINK_BIN} -e)"

# If we're not on sunxi, wait until onboard is mounted, nickel is up, and the boot anim is done.
# On sunxi, the timing of the fbdamage module load is of paramount importance, because everything is terrible and race-y...
if [ "${isSunxi}" = 0 ] ; then
	until grep -q /mnt/onboard /proc/mounts && pkill -0 nickel && ! pkill -0 on-animator.sh ; do
		logger -p "DAEMON.NOTICE" -t "${SCRIPT_NAME}[$$]" "Waiting for the boot process to complete . . ."
		sleep 5
	done
fi

# shellcheck disable=SC2154
DEVICE_GEN="mk$(echo "${devicePlatform}" | sed -re 's/^.+([[:digit:]]+)$/\1/')"

PLATFORM="freescale"
if [ "$(dd if=/dev/mmcblk0 bs=512 skip=1024 count=1 2>/dev/null | grep -c "HW CONFIG")" = 1 ] ; then
	CPU="$(ntx_hwconfig -s -p /dev/mmcblk0 CPU 2>/dev/null)"
	PLATFORM="${CPU}-ntx"
fi

# Check the FW version, to see if we can enforce nightmode support in FBInk if we detect a recent enough version...
NICKEL_BUILD="$(awk 'BEGIN {FS=","}; {split($3, FW, "."); print FW[3]};' "/mnt/onboard/.kobo/version")"

# If it's sane, and newer than 4.2.8432, enforce HW inversion support
# This is only useful for the Aura, which used to be crashy on earlier kernels...
# NOTE: Final Aura kernel is r7860_#2049 built 01/09/17 05:33:13;
#       FW 4.2.8432 was released February 2017;
#       the previous FW release was 3.19.5761 in December 2015 (!).
if is_integer "${NICKEL_BUILD}" && [ "${NICKEL_BUILD}" -ge "8432" ] ; then
	export FBINK_ALLOW_HW_INVERT=1
fi

# NOTE: On sunxi, we need to make sure the module is inserted *before* Nickel boots.
#       This here is already too late, so, patch the on-animator script instead,
#       it'll take on the next boot...
# shellcheck disable=SC2154
if [ "${isSunxi}" = 1 ] ; then
	if ! grep -q "nanoclock-load-fbdamage.sh" "/etc/init.d/on-animator.sh" ; then
		# Patch on-animator
		logger -p "DAEMON.NOTICE" -t "${SCRIPT_NAME}[$$]" "Patching on-animator to load fbdamage early..."
		sed '/^#!\/bin\/sh/a \/usr\/local\/NanoClock\/bin\/nanoclock-load-fbdamage.sh' -i "/etc/init.d/on-animator.sh"
	fi

	# Handle fbdamage loader updates...
	FBDAMAGE_LOADER_REV="4"
	if ! grep -q "revision=${FBDAMAGE_LOADER_REV}" "/usr/local/NanoClock/bin/nanoclock-load-fbdamage.sh" 2>/dev/null ; then
		# Generate the script ;).
		cat > "/usr/local/NanoClock/bin/nanoclock-load-fbdamage.sh" <<EoF
#!/bin/sh
# revision=${FBDAMAGE_LOADER_REV}
# Load the right kernel module
KMOD_PATH="${NANOCLOCK_DIR}/kmod/${DEVICE_GEN}/${PLATFORM}/mxc_epdc_fb_damage.ko"
if [ ! -f "\${KMOD_PATH}" ] ; then
	logger -p "DAEMON.CRIT" -t "${SCRIPT_NAME}[\$\$]" "Platform ${DEVICE_GEN}/${PLATFORM} is unsupported: no kernel module!"
	exit
fi

if grep -q "mxc_epdc_fb_damage" "/proc/modules" ; then
	logger -p "DAEMON.NOTICE" -t "${SCRIPT_NAME}[\$\$]" "Kernel module for platform ${DEVICE_GEN}/${PLATFORM} is already loaded!"
else
	if ! insmod "\${KMOD_PATH}" ; then
		logger -p "DAEMON.ERR" -t "${SCRIPT_NAME}[\$\$]" "Platform ${DEVICE_GEN}/${PLATFORM} is unsupported: failed to load the kernel module!"
		exit
	fi
fi
EoF
		chmod a+x "/usr/local/NanoClock/bin/nanoclock-load-fbdamage.sh"
	fi
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
	if ! insmod "${KMOD_PATH}" ; then
		logger -p "DAEMON.ERR" -t "${SCRIPT_NAME}[$$]" "Platform ${DEVICE_GEN}/${PLATFORM} is unsupported: failed to load the kernel module!"
		exit
	fi
fi

# And here we go!
exec ./nanoclock.lua > "crash.log" 2>&1
