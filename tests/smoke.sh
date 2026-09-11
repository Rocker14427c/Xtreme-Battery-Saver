#!/usr/bin/env bash
# Host-side regression smoke test. It simulates the Android commands and sysfs
# CPU nodes needed by the daemon; it never writes to real /sys or /data.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
DAEMON_PID=""
cleanup() {
  [[ -n "$DAEMON_PID" ]] && kill "$DAEMON_PID" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "expected '$2', got '$1'"; }

bash -n "$ROOT/system/bin/XtremeBSd"
for script in "$ROOT/action.sh" "$ROOT/customize.sh" "$ROOT/service.sh" \
  "$ROOT/xbs-webui.sh" "$ROOT/system/bin/XBSctl" "$ROOT"/webui/cgi-bin/*.cgi; do
  sh -n "$script"
done

python3 - "$ROOT/webroot/index.html" "$TMP/webui.js" <<'PY'
from pathlib import Path
import re, sys
html = Path(sys.argv[1]).read_text()
script = '\n'.join(re.findall(r'<script>(.*?)</script>', html, re.S))
Path(sys.argv[2]).write_text(script)
assert script
PY
command -v node >/dev/null && node --check "$TMP/webui.js"

# Package checks use a temporary output and prove webroot is included.
"$ROOT/tools/build.sh" "$TMP/XtremeBS.zip" >/dev/null
unzip -tqq "$TMP/XtremeBS.zip"
zip_entries=$(unzip -Z1 "$TMP/XtremeBS.zip")
grep -qx 'webroot/index.html' <<< "$zip_entries"
grep -qx 'xbs-webui.sh' <<< "$zip_entries"

mkdir -p "$TMP/bin" "$TMP/cpu"
cat > "$TMP/bin/getprop" <<'EOF'
#!/bin/sh
[ "$1" = sys.boot_completed ] && printf '1\n'
EOF
cat > "$TMP/bin/settings" <<'EOF'
#!/bin/sh
if [ -n "${TEST_LOWPOWER:-}" ]; then
  cat "$TEST_LOWPOWER"
else
  printf '0\n'
fi
EOF
cat > "$TMP/bin/dumpsys" <<'EOF'
#!/bin/sh
if [ "$1" = deviceidle ] && [ "$2" = get ]; then
  case "$3" in
    screen) cat "$TEST_SCREEN" ;;
    charging) printf 'false\n' ;;
    light|deep) printf 'ACTIVE\n' ;;
  esac
elif [ "$1" = power ]; then
  printf 'mWakefulness=Awake\n'
fi
EOF
for command in su resetprop pm am svc; do
  printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/$command"
done
chmod 755 "$TMP/bin"/*

# service.sh must invoke bundled files by their module path, not the optional
# /system overlay. A tiny fake Bash/daemon pair proves the resolved paths and
# the XBS_MODDIR handoff without starting a real long-running service.
mkdir -p "$TMP/service-module/system/bin"
sed '1s|/system/bin/sh|/bin/sh|' "$ROOT/service.sh" > "$TMP/service-module/service.sh"
cat > "$TMP/service-module/system/bin/bash" <<'EOF'
#!/bin/sh
exec "$@"
EOF
cat > "$TMP/service-module/system/bin/XtremeBSd" <<'EOF'
#!/bin/sh
printf 'daemon=%s
moddir=%s
' "$0" "$XBS_MODDIR" > "$TEST_SERVICE_RECORD"
EOF
chmod 755 "$TMP/service-module/service.sh" "$TMP/service-module/system/bin/bash"   "$TMP/service-module/system/bin/XtremeBSd"
PATH="$TMP/bin:$PATH" TEST_SERVICE_RECORD="$TMP/service-record" XBS_STATE_DIR="$TMP/service-state"   "$TMP/service-module/service.sh"
sleep 1
grep -qx "daemon=$TMP/service-module/system/bin/XtremeBSd" "$TMP/service-record"
grep -qx "moddir=$TMP/service-module" "$TMP/service-record"
grep -q 'Starting XtremeBS from module directory' "$TMP/service-state/XtremeBS.service.log"

# Build a four-core big.LITTLE test topology. cpu0 has no online node, just as
# the boot CPU commonly does on Android.
for cpu in 0 1 2 3; do
  mkdir -p "$TMP/cpu/cpu$cpu/cpufreq"
  if (( cpu < 2 )); then
    printf 1000 > "$TMP/cpu/cpu$cpu/cpufreq/cpuinfo_max_freq"
  else
    printf 2000 > "$TMP/cpu/cpu$cpu/cpufreq/cpuinfo_max_freq"
  fi
  printf schedutil > "$TMP/cpu/cpu$cpu/cpufreq/scaling_governor"
  printf 'schedutil powersave performance' > "$TMP/cpu/cpu$cpu/cpufreq/scaling_available_governors"
  if (( cpu != 0 )); then
    # cpu3 represents a CPU that was already offlined by the kernel/user.
    # XtremeBS must not claim or re-enable it during profile cleanup.
    if (( cpu == 3 )); then printf 0 > "$TMP/cpu/cpu$cpu/online"; else printf 1 > "$TMP/cpu/cpu$cpu/online"; fi
  fi
done

mkdir -p "$TMP/state"
printf 'true\n' > "$TMP/screen"
printf '0\n' > "$TMP/lowpower"
cat > "$TMP/state/XtremeBS.conf" <<EOF
version=2
delay=1
log_file=$TMP/state/XtremeBS.log
log_level=3
notify=false
boot={
}
charging={
}
low_power={
}
  screen_off = {
    disable_cores = cpu1 cpu2 cpu3
    handle_cores = cpu1
  }
manual={
}
EOF

PATH="$TMP/bin:$PATH" TEST_SCREEN="$TMP/screen" TEST_LOWPOWER="$TMP/lowpower" XBS_STATE_DIR="$TMP/state" \
  XBS_CPU_BASE_PATH="$TMP/cpu" XBS_BASH=/bin/bash \
  /bin/bash "$ROOT/system/bin/XtremeBSd" > "$TMP/daemon.out" 2>&1 &
DAEMON_PID=$!
sleep 2
printf 'false\n' > "$TMP/screen"
sleep 2
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu1/online")" 0
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu2/online")" 0
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu3/online")" 0
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu1/cpufreq/scaling_governor")" powersave
printf 'true\n' > "$TMP/screen"
sleep 2
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu1/online")" 1
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu2/online")" 1
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu3/online")" 0
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu1/cpufreq/scaling_governor")" schedutil
grep -q 'cpu1 -> OFFLINE' "$TMP/state/XtremeBS.log"
grep -q 'Leaving cpu3 offline: it was not offlined by this daemon' "$TMP/state/XtremeBS.log"
grep -q 'cpu1 -> ONLINE' "$TMP/state/XtremeBS.log"
kill "$DAEMON_PID" 2>/dev/null || true
DAEMON_PID=""

# v1 remains a supported compatibility path. This specifically exercises the
# charging-state call made while legacy auto mode releases its profile.
printf '1\n' > "$TMP/cpu/cpu1/online"
printf '1\n' > "$TMP/lowpower"
cat > "$TMP/state/XtremeBS.conf" <<EOF
version=1
delay=1
log_file=$TMP/state/XtremeBS-v1.log
log_level=3
notify=false
trigger=auto
keep_on_charge=false
disable_cores=cpu1
handle_cores=false
handle_apps=false
handle_gms=false
handle_proc=false
low_ram=false
doze=false
kill_wifi=false
EOF
PATH="$TMP/bin:$PATH" TEST_SCREEN="$TMP/screen" TEST_LOWPOWER="$TMP/lowpower" XBS_STATE_DIR="$TMP/state" \
  XBS_CPU_BASE_PATH="$TMP/cpu" XBS_BASH=/bin/bash \
  /bin/bash "$ROOT/system/bin/XtremeBSd" > "$TMP/daemon-v1.out" 2>&1 &
DAEMON_PID=$!
sleep 2
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu1/online")" 0
printf '0\n' > "$TMP/lowpower"
sleep 2
assert_eq "$(tr -d '\n' < "$TMP/cpu/cpu1/online")" 1
grep -q 'Disabled XtremeBS' "$TMP/state/XtremeBS-v1.log"
kill "$DAEMON_PID" 2>/dev/null || true
DAEMON_PID=""

# Test the root WebUI helper using temporary /bin/sh shebangs. This verifies
# UTF-8/base64 config writes and the generated CPU0-only profile without an
# Android device.
mkdir -p "$TMP/module/system/bin"
sed '1s|/system/bin/sh|/bin/sh|' "$ROOT/xbs-webui.sh" > "$TMP/module/xbs-webui.sh"
sed '1s|/system/bin/sh|/bin/sh|' "$ROOT/system/bin/XBSctl" > "$TMP/module/system/bin/XBSctl"
chmod 755 "$TMP/module/xbs-webui.sh" "$TMP/module/system/bin/XBSctl"
encoded="$(printf 'version=2\n# Café\ndelay=2\nboot={\n}\n' | base64 -w0)"
save_output=$(XBS_STATE_DIR="$TMP/helper-state" XBS_CPU_BASE_PATH="$TMP/cpu" \
  "$TMP/module/xbs-webui.sh" save-config "$encoded")
grep -q 'Queued: reload' <<< "$save_output"
grep -q 'Café' "$TMP/helper-state/XtremeBS.conf"
preset_output=$(XBS_STATE_DIR="$TMP/helper-state" XBS_CPU_BASE_PATH="$TMP/cpu" \
  "$TMP/module/xbs-webui.sh" cpu0-preset)
grep -q 'Target cores: cpu1 cpu2 cpu3' <<< "$preset_output"
grep -q '^  disable_cores=cpu1 cpu2 cpu3$' "$TMP/helper-state/XtremeBS.conf"
if XBS_STATE_DIR="$TMP/helper-state" XBS_CPU_BASE_PATH="$TMP/cpu" \
  "$TMP/module/xbs-webui.sh" command start .invalid >/dev/null 2>&1; then
  fail 'invalid custom event was accepted'
fi

echo 'PASS: XtremeBS host-side smoke tests'
