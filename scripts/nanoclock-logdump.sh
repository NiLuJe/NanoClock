#!/bin/sh

# Settings
SCRIPT_NAME="$(basename "${0}")"
LOGFILE="/mnt/onboard/.adds/nanoclock/nanoclock.log"
CRASHLOG="/usr/local/NanoClock/crash.log"

# Log that we're dumping the log ;o)
logger -p "DAEMON.NOTICE" -t "${SCRIPT_NAME}[$$]" "Dumping NanoClock's log to onboard"

# Start with the actual log
logread | grep '\(nanoclock\|nanoclock\.sh\)\[[[:digit:]]\+\]' > "${LOGFILE}"

# Then with the crash log, if there's one
if [ -f "${CRASHLOG}" ] && [ "$(stat -c %s "${CRASHLOG}")" -gt 0 ] ; then
	cat >> "${LOGFILE}" << EoF

	Also found a crash log from: $(stat -c %y "${CRASHLOG}")

EoF

	cat "${CRASHLOG}" >> "${LOGFILE}"
fi
