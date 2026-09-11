# Xtreme Battery Saver

A systemless Android battery-saving module originally created by **DethByte64**. This fork keeps the original event-driven XtremeBS features and adds a working native **KernelSU / ReSukiSU WebUI**, safer module-path handling, and CPU hotplug reliability fixes.

> **Important:** this is an advanced module. App suspension, forced Doze, Wi-Fi changes, CPU governor changes, and CPU hotplug can delay notifications, break alarms, slow the device, or make a bad configuration difficult to recover from. Start with one change at a time.

## Why ReSukiSU showed no WebUI button

The upstream package contains a directory named `webui/`, which is only a legacy localhost site started by `action.sh`. KernelSU-family managers discover a native module WebUI from **`webroot/index.html`**, not `webui/`. Therefore ReSukiSU correctly did not mark the original module as having a WebUI.

This fork adds `webroot/index.html` and a root-side helper. After installing **this fork's rebuilt `XtremeBS.zip`** and rebooting, open the module details in ReSukiSU and use its **WebUI** button. It does not depend on a localhost web server.

- **KernelSU / ReSukiSU:** use the native **WebUI** button.
- **Managers without native WebUI:** use the module **Action** button for the old browser-based fallback at `http://127.0.0.1:8081`.
- If the button still is not visible after upgrading, ensure that the installed directory contains `/data/adb/modules/XtremeBS/webroot/index.html`, the module is enabled, then refresh/reopen the manager. Installing the old upstream ZIP will not add that directory.

## Install

1. Download the rebuilt `XtremeBS.zip` from this repository.
2. Install it in Magisk, KernelSU, or ReSukiSU.
3. Reboot once. The service starts only after Android reports boot complete.
4. In ReSukiSU, open **Modules → Xtreme Battery Saver → WebUI**.
5. Before enabling any aggressive setting, open **Dashboard → Run diagnostics** and confirm the daemon and screen-state source are visible.

The runtime files are deliberately kept outside the module folder so an update does not erase them:

```text
/data/local/tmp/XtremeBS/XtremeBS.conf        configuration
/data/local/tmp/XtremeBS/XtremeBS.status      latest status
/data/local/tmp/XtremeBS/XtremeBS.log         default daemon log for new configs
/data/local/tmp/XtremeBS/XtremeBS.service.log service startup/errors
```

Existing configurations that use `/sdcard/XtremeBS.log` keep that location; only new configs use the private runtime directory by default.

## Your ScreenOff CoresOff feature in XtremeBS

**Yes.** XtremeBS has the equivalent feature through the `screen_off` v2 event and `disable_cores` option. It is **not enabled by default** in the upstream module.

For the same behavior as your eight-core ScreenOff CoresOff module—keep `cpu0` online and take `cpu1` through `cpu7` offline while the screen is off—use:

```ini
version=2
delay=1
log_file=/data/local/tmp/XtremeBS/XtremeBS.log
log_level=2
notify=false

boot={
}

charging={
}

low_power={
}

screen_off={
  disable_cores=cpu1 cpu2 cpu3 cpu4 cpu5 cpu6 cpu7
}

manual={
}
```

Or, in the new native WebUI, select **“Replace config with this preset”** under **CPU0-only screen-off preset**. It discovers every available `cpuN/online` node, excludes `cpu0`, and writes the equivalent list for the actual device topology. On a Helio G85 exposing `cpu1`–`cpu7`, that is the same core list as your basic module.

### What to expect

- Screen off → configured CPUs are written to `0` (offline).
- Screen on → CPUs that XtremeBS actually took offline are written back to `1` (online); a CPU that was already offline before the event is left alone.
- The updated daemon verifies each write and retries a refused hotplug operation up to three times.
- `cpu0` is always refused by a safety guard, even if accidentally added to `disable_cores`.
- A kernel may pin a CPU or reject hotplugging a complete cluster. That is a device/kernel restriction, not something a Magisk/KernelSU module can override.

Verify it manually:

```sh
su -c 'cat /sys/devices/system/cpu/online'
```

For the example above, it should normally show `0` while the screen is off and `0-7` after waking. Check the log for an individual CPU if the kernel uses a different online-range format.

### Do not run both modules for the same CPUs

Your `ScreenOff-CoresOff-v2.1-stable.zip` and this XtremeBS screen-off profile both write the same CPU hotplug nodes. Do **not** enable both at once. Keep the small dedicated module if you prefer its backlight-first detection and minimal scope; use the XtremeBS profile if you want it integrated with the rest of XtremeBS.

The dedicated module polls a backlight node first when one exists, so it can react faster on compatible devices. XtremeBS uses `dumpsys deviceidle get screen` and now falls back to `dumpsys power`; with `delay=1`, its normal reaction time is about one polling interval. The end result is equivalent when both screen-state sources work, but the timing mechanism is not identical.

## v2 configuration

XtremeBS v2 is event-based. Each block is activated by a system state or by `XBSctl`:

| Event | Activates when |
| --- | --- |
| `boot` | The daemon starts; remains active for that daemon run. |
| `charging` | External power is connected. |
| `low_power` | Android's AOSP Battery Saver setting is enabled. |
| `screen_off` | The screen is off. |
| `manual` | You run `XBSctl start`. |
| `my_event` | A custom event that you start with `XBSctl start my_event`. |

A minimal safe v2 file is created automatically on a fresh install. Values inside a block may be indented; this fork explicitly supports the indented style shown in the examples.

Common options:

| Option | Values | Meaning |
| --- | --- | --- |
| `delay` | integer seconds, minimum `1` | How often XtremeBS checks events and queued commands. |
| `notify` | `true` / `false` | Enable the XtremeBS status notifications. |
| `disable_cores` | `false`, `auto`, or `cpuN cpuN` | Offline selected CPUs. `auto` selects the highest-frequency cluster when topology is unambiguous; use an explicit list for CPU0-only mode. |
| `handle_cores` | `false`, `auto`, or `cpuN cpuN` | Set selected CPUs to the `powersave` governor when the kernel exposes it. |
| `handle_apps` | `false`, `nice`, `kill`, `suspend` | Apply aggressive user-app handling. `suspend` needs a safe allowlist. |
| `allowlist` / `denylist` | file paths | App package lists used by app handling. |
| `handle_gms` | `false`, `nice`, `kill` | Change Google Play services behavior; `kill` is disruptive. |
| `handle_proc` | `true` / `false` | Reprioritize processes named in `proc_file`. |
| `low_ram` | `true` / `false` | Toggle `ro.config.low_ram`; can destabilize ROMs. |
| `doze` | `false`, `light`, `deep` | Force Android Doze. This can delay alarms and notifications. |
| `kill_wifi` | `true` / `false` | Disable Wi-Fi while the event is active. |
| `keep_on_charge` | `true` / `false` | Keep a non-charging profile active while charging. Use carefully. |

Example low-power profile that only disables the big cores:

```ini
version=2
delay=3
notify=false

low_power={
  disable_cores=cpu6 cpu7
  doze=light
}

screen_off={
}
```

When a screen-off event exits while another event remains active, this fork immediately reapplies the remaining active event(s). That fixes the upstream behavior where waking the phone could leave cores re-enabled even though `low_power` was still active. It is a reconciliation pass, not a full atomic priority system, so avoid mixing conflicting aggressive actions until you have tested them.

## Controller and recovery

The direct controller path works even when KernelSU does not mount `system/bin`:

```sh
XBSCTL=/data/adb/modules/XtremeBS/system/bin/XBSctl
su -c "$XBSCTL reload"
su -c "$XBSCTL start"             # v2 manual event
su -c "$XBSCTL start my_event"    # custom event
su -c "$XBSCTL stop my_event"
su -c "$XBSCTL pause"
su -c "$XBSCTL resume"
su -c "$XBSCTL safe"
su -c "$XBSCTL status"
```

`safe` stops active XtremeBS events and unsuspends apps. If a bad persistent profile applies again at boot, disable or remove the module from the root manager/recovery, then edit or delete:

```text
/data/local/tmp/XtremeBS/XtremeBS.conf
```

The service startup log is especially useful if the config directory or daemon did not appear:

```sh
su -c 'cat /data/local/tmp/XtremeBS/XtremeBS.service.log'
```

## Compatibility and limits

- The bundled Bash executable is **AArch64**. This module is intended for 64-bit ARM Android devices; the service logs a clear warning for another reported ABI.
- KernelSU/ReSukiSU does not need a metamodule for this fork's daemon to run: it invokes the bundled files directly from `/data/adb/modules/XtremeBS/`. A metamodule is only relevant if you want the legacy `/system/bin/XBSctl` mount path.
- CPU names, hotplug permissions, available governors, and `dumpsys` output vary by kernel and ROM. Use Dashboard diagnostics before trusting a profile.
- Xiaomi/MIUI and other OEM Battery Saver implementations may not update AOSP `settings global low_power`; use `screen_off`, `manual`, or an automation-triggered custom event in that case.
- New WebUI code was checked with a simulated Android command/CPU-node fixture. It still needs real-device testing on your ROM before enabling destructive options.

See [AUDIT.md](AUDIT.md) for the focused source audit, fixes, and known remaining limits.

## Credits and license

- Original module: [DethByte64/Xtreme-Battery-Saver](https://github.com/DethByte64/Xtreme-Battery-Saver)
- Upstream mirror: [Magisk-Modules-Alt-Repo/Xtreme-Battery-Saver](https://github.com/Magisk-Modules-Alt-Repo/Xtreme-Battery-Saver)
- This compatibility fork: Rocker14427c

XtremeBS is released under the [GPLv3 License](LICENSE).
