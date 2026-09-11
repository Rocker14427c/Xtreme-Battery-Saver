### v2.1.5-rs1 — ReSukiSU / KernelSU compatibility and reliability
  - Added `webroot/index.html`, so KernelSU and ReSukiSU show a native WebUI button instead of requiring the legacy localhost Action flow.
  - Made the daemon launch directly from the module directory; it no longer relies on `/system/bin` mounting or waits for `/sdcard/Android`.
  - Added a native CPU0-only screen-off preset that discovers available hotpluggable CPUs and writes the equivalent `screen_off` profile.
  - Fixed indented v2 event keys being ignored, manual governor writes/restores, ambiguous auto core mapping, CPU write verification/retries, preservation of already-offline CPUs, and rfkill multi-word command execution.
  - Fixed controller command races, Safe Mode busy loops, the v1 charging-state cleanup call, v1→v2 controller/manual migration errors, and re-applies remaining events after an overlapping event exits.
  - Kept the old action/httpd UI only as a hardened fallback for managers without a native WebUI.

### v2.1.4
  - Improve Wifi handling - Authored by [vikasmistry](https://github.com/vikasmistry)

### v2.1.3
  - Added a fallback for kill_wifi to support devices that dont have rfkill support

### v2.1.2
  - Improved handling of manual
  - Added `notify` flag for those pesky notifications

### v2.1.1
  - Improved start for v2 configs. Now on boot, it activates events that should be active (charging, screen_off, low_power)
  - Fixed status checks for the WebUI
  - Fixed kill_wifi handling
  - Added bc (1.08.1) binary for upcoming battery prediction update

### v2.1.0
  - Improved WebUI to show the status of a few things
  - Improved WebUI to show the log amd allow copying to storage for easy bug reports
  - Logging will no longer fill up your storage
  - Improved reloading
  - Safe Mode is persistent until its turned off. (also you can enter safe mode using `safemode=1` in your config)
  - other minor improvements and bug fixes

### v2.0.0
  - Add event handling (different triggers, which makes the module dynamic)
  - Added support for custom events
  - Added support for Doze mode
  - Added the ability to disable the wifi radios
  - Added logging and log levels
  - Added a migration function, this will automatically convert your original config into the v2 config. just put `version=2` in your config file and reboot
  - Removed battery prediction, it was buggy and could use some work, it will be back in a later version.
  - Optimized CPU core handling.

### v1.0.6
  - add webui for easy config
  - attempt ksu and apatch support (no testing done, someone with these let me know if it works or not)
  - Samsung devices should no longer have SystemUI crashes

### v1.0.5
  - change low_ram default value to false

### v1.0.4

  - fix a bug where XtremeBS would continually enable when `trigger=boot` is set
  - math changed in battery time prediction
  - process handling now ensures that the
  nice level doesnt get changed behind us
  - proc_file will now take a nice level per process
  if you dont change your file, nice is 10
  nice levels are 0 (normal) - 19 (very nice)
  - added `keep_on_charge` option, this leads to extremely fast charging speeds and is only needed if using `trigger=auto`

### v1.0.3

  - add battery time prediction
  - removed undocumented function
  - removed old function from pre-v0.0.1
  - made app handling faster (still needs to be faster. WIP)

### v1.0.2

  - make requested changes for MMAR
  - configs are now located in `/data/local/tmp/XtremeBS/`

### v1.0.1

  - Add manual control

### v1.0.0

  - FIRST OFFICIAL RELEASE
  - fixed daemon command handling
  - fixed a bug in process handling

### v0.0.3

  - fixed a bug that prevented powersave from starting

### v0.0.2

  - minor improvements
  - fixed a bug.

### v0.0.1

  - initial release
