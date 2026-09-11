# XtremeBS focused audit (2026-09-11)

## Scope

Before the fork changes in this branch, the XtremeBS source and its bundled `XtremeBS.zip` matched upstream `Magisk-Modules-Alt-Repo/Xtreme-Battery-Saver` main commit `6d279239b7642631a351eeb5b6871e5dc0ed7170` file-for-file. The baseline repository's only extra archive was `ScreenOff-CoresOff-v2.1-stable.zip`, which is a separate module.

This was a source audit and a Linux fixture test, **not** a substitute for testing the resulting module on a real Android ROM/kernel.

## Confirmed cause of the missing ReSukiSU WebUI button

| Finding | Effect | Fix in this fork |
| --- | --- | --- |
| The package had `webui/index.html`, but no `webroot/index.html`. | KernelSU/ReSukiSU discovers native module UIs from `webroot`, so the installed module reported `web=false` and no WebUI button was shown. | Added `webroot/index.html`, a static native UI, and `xbs-webui.sh` for root-side reads/writes. |
| The old “WebUI” was actually `action.sh` starting BusyBox `httpd` on port 8081. | It requires an Action button, a browser, a working localhost HTTP server, and CGI shebangs that may not exist. It is not a KernelSU native WebUI. | Kept it as a Magisk fallback, but made it use the actual module directory and direct helper/controller paths. |

## Confirmed runtime bugs fixed

| Finding | Why it matters | Fix |
| --- | --- | --- |
| `service.sh` invoked `/system/bin/bash /system/bin/XtremeBSd`. | KernelSU/ReSukiSU may not mount a module's `system/` directory without a metamodule. The daemon could therefore never start, which also explains reports of no `/data/local/tmp/XtremeBS` directory. | Service now runs the bundled files directly from its own module directory and logs startup failures. |
| Service waited for `/sdcard/Android` as well as boot completion. | The daemon does not need external storage; a missing/unavailable shared-storage path could leave it waiting forever. | It waits only for `sys.boot_completed=1`. |
| Event parsing did not trim whitespace around keys. | The upstream README's own indented form (`  disable_cores=cpu6 cpu7`) parsed as a key named `  disable_cores`, silently making the event a no-op. | Event keys and values are trimmed before parsing. |
| `handle_cores` manual mode wrote to `$cpu` instead of `$core`. | A manual governor setting could be written to the last CPU seen during auto-mapping, not the requested CPU. | Replaced the fragile inline CPU code with validated helper functions. |
| `lp_default_govs` was used as an undeclared indexed array with string CPU names. | Governor restoration could use the wrong/default entry. | Uses an associative CPU-to-governor map and verifies governor writes. |
| `disable_cores=auto` used `uniq -u` on frequency values. | A normal pair of equally clocked big cores was not selected as “high power.” | Selects the highest-frequency cluster when there is more than one frequency group; refuses to auto-offline an ambiguous single-cluster SoC. |
| CPU online writes had no confirmation or retry, and cleanup blindly enabled every configured CPU. | A kernel refusal was silent; a CPU that was already offline before XtremeBS could also be incorrectly enabled at screen-on. | Reads the result back and retries each requested CPU up to three times; CPU0 is guarded, and cleanup restores only CPUs this daemon actually offlined. |
| `RFKILL_CMD` sometimes contained a multi-word command such as `toybox rfkill` but was later quoted as one executable path. | Wi-Fi control failed on fallback implementations and silently fell back incorrectly. | Stores command + arguments in a Bash array and invokes it correctly. |
| The controller used `cat "$ctl_file"` followed by truncation. | A command written in the small interval between those operations could be lost. | `XBSctl` and the daemon coordinate through an atomic write plus a short mkdir lock. |
| Safe Mode polling had loops without a sleep and could read a control file before it existed. | Persistent/Safe Mode could consume a CPU core continuously. | Initializes the control file and uses the configured polling delay. |
| Legacy v1 auto mode called an undefined `getstate charging` while turning a profile off. | The legacy release path could emit a shell error and make charging-related cleanup unreliable. | Uses the normalized `is_device charging` helper; v1 auto enable/disable is fixture-tested. |
| A v2 migration printed `ctl_file=…` instead of writing it to the new config; manual migration generated `on_start={}` rather than `manual={}`. | Custom controller paths were lost and manual profiles did not migrate as intended. | Correct atomic migration with a `.v1` backup. |
| An exiting `screen_off` event restored its settings without reapplying another still-active event. | Waking the screen could re-enable CPUs that `low_power` still required offline. This is documented upstream in issue #15. | Remaining active events are synchronously reapplied after an event exits. |

## Validation performed

1. `bash -n` checked the Bash daemon; `sh -n` checked all POSIX scripts and CGI handlers. A fake bundled Bash/daemon fixture also verified that `service.sh` resolves and launches direct module paths rather than `/system/bin`.
2. JavaScript extracted from the native and legacy HTML pages passed `node --check`.
3. A mocked Android fixture supplied `dumpsys`, `settings`, CPU `online` nodes, and CPU frequency/governor nodes. It verified:
   - an indented/whitespace-tolerant `screen_off` block changes its online CPUs offline → online, preserves a CPU that was already offline, and restores a temporary `powersave` governor;
   - a still-active `low_power` event immediately re-offlines overlapping CPUs after `screen_off` exits;
   - legacy v1 auto mode offlines and restores its configured core as Android Battery Saver changes; v1-to-v2 migration preserves `ctl_file` and produces a `manual={}` block;
   - native WebUI helper config save, UTF-8/base64 transfer, CPU0-only preset generation, and command queueing.

## Deliberate limits / follow-up testing needed

- The included Bash binary is an **AArch64 ELF**. It cannot make the module work on a 32-bit ARM-only userspace; the service logs that fact instead of failing silently.
- No root module can force a kernel to offline a CPU that the kernel pins, lacks an `online` node for, or rejects for scheduler/device reasons.
- Reapplying active events fixes the final state after an overlapping event exits, but it is not a fully atomic priority/diff engine. A very aggressive mixed profile may still briefly reset and reapply settings. Test CPU/app/Doze/Wi-Fi combinations one by one.
- `dumpsys deviceidle get screen` and the `dumpsys power` fallback can be OEM- or SELinux-dependent. The separate ScreenOff CoresOff module has an additional backlight-first detector, so it may react faster on some phones.
- The legacy localhost CGI fallback is retained for managers without native WebUI. Prefer the native WebUI on KernelSU/ReSukiSU because it avoids a root HTTP service on localhost.
- `handle_apps=suspend`, GMS killing, forced deep Doze, and `low_ram=true` remain inherently disruptive options; they require device-specific testing and a recovery plan.
