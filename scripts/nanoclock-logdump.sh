#!/bin/sh

# Settings
LOGFILE="/mnt/onboard/.adds/nanoclock/nanoclock.log"
CRASHLOG="/usr/local/NanoClock/crash.log"

# Start with the actual log
logread | grep '\(nanoclock\|nanoclock\.sh\)\[[[:digit:]]\+\]' > "${LOGFILE}"

# Then with the crash log, if there's one
if [ -f "${CRASHLOG}" ] ; then
	cat >> "${LOGFILE}" << EoF

	Also found a crash log from: $(stat -c %y "${CRASHLOG}")

EoF

	cat "${CRASHLOG}" >> "${LOGFILE}"
fi
