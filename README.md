# NanoCLock

Licensed under the [GPLv3+](/LICENSE).  
Housed [here on GitHub](https://github.com/NiLuJe/NanoClock).

## What does it do?

In the spirit of [MiniClock](https://www.mobileread.com/forums/showpost.php?p=3762123&postcount=6), this aims to display a *persistent* clock on your Kobo's screen, positioned and formatted to your liking.

Unlike the original MiniClock, or my own [previous take](https://www.mobileread.com/forums/showpost.php?p=3898594&postcount=311) on it, this no longer relies on things that don't really have anything to do with the screen to detect screen updates, which means it no longer suffers from any timing related mishaps, is somewhat simpler, and should basically transparently bake the clock to every meaningful update with no visible lag.

It's also written entirely in Lua, instead of a mix of shell & C, which should also help make it more efficient.

The magic *does* require injecting some [code](https://github.com/NiLuJe/mxc_epdc_fb_damage) into the kernel in order to allow us to directly listen to screen refresh requests. This may affect portability somewhat, although, so far, the current lineup should be supported without issue. Things are still up in the air as far as future devices are concerned (e.g., the Elipsa), in which case we harmlessly abort on startup.

## Installation

Visit the [MobileRead thread](https://www.mobileread.com/forums/showthread.php?t=340047) to download the install package, and simply unpack the ZIP archive to the USB root of your Kobo when it's plugged to a computer. Do *NOT* try to open the archive and drag/copy stuff manually, just "Extract to" the root of your device, and say yes to replacing existing content if/when applicable (the directory structure & content have to be preserved *verbatim*, and there are hidden *nix folders in there that your OS may hide from you)! Then, just eject your device safely, and wait for it to reboot after the "update" process.

If all goes well, you should see the clock appear a few seconds into the boot process, according to the default settings. Take a look at the [`.adds/nanoclock/nanoclock.ini`](config/nanoclock.ini) file on your device to set it up to your liking.  
NOTE: Most settings are compatible with their MiniClock counterparts, but the file itself has changed format, so do double-check things manually.
Changes to the config file should be picked up immediately.


## Uninstallation

Just set the `uninstall` option in the `[global]` section of the config file to `1`.

## Credits

Written in [LuaJIT](https://github.com/LuaJIT/LuaJIT), uses [FBInk](https://github.com/NiLuJe/FBInk) via its [Lua bindings](https://github.com/NiLuJe/lua-fbink).  
Relies on my Kobo fork of the [mxc_epdc_fb_damage](https://github.com/NiLuJe/mxc_epdc_fb_damage) kernel module to provide damage tracking, a module that was originally written by [@pl-semiotics](https://github.com/pl-semiotics) for the [reMarkable](https://github.com/pl-semiotics/mxc_epdc_fb_damage).

<!-- kate: indent-mode cstyle; indent-width 4; replace-tabs on; remove-trailing-spaces none; -->
