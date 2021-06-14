#!/bin/sh

# Start by renicing ourselves to a neutral value, to avoid any mishap...
renice 0 -p $$

# I run early at boot! Do fun stuff here!
# NOTE: onboard *should* be mounted by that point, but if you want to be safe, double-check.
# NOTE: Remember to keep things short & sweet, because we're blocking udev here...
#       Background your stuff if you need to run long-lasting tasks.

# Launch in the background, with a clean env, after a setsid call to make very very sure udev won't kill us ;).
env -i -- setsid /usr/local/NanoClock/bin/nanoclock.sh &

# Done :)
exit 0
