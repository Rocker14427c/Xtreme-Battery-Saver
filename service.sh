#!/system/bin/sh
# XtremeBS late_start service.
#
# Do not invoke /system/bin/bash or /system/bin/XtremeBSd here.  Those paths
# exist only when a root manager mounts this module's system/ directory; a
# KernelSU/ReSukiSU installation without a metamodule does not mount it.

SCRIPT_DIR=${0%/*}
[ "$SCRIPT_DIR" = "$0" ] && SCRIPT_DIR=.
MODDIR=$(CDPATH= cd "$SCRIPT_DIR" 2>/dev/null && pwd)
[ -n "$MODDIR" ] || exit 1
STATE_DIR=${XBS_STATE_DIR:-/data/local/tmp/XtremeBS}
LOG_FILE="$STATE_DIR/XtremeBS.service.log"
BASH_BIN="$MODDIR/system/bin/bash"
DAEMON="$MODDIR/system/bin/XtremeBSd"

mkdir -p "$STATE_DIR" 2>/dev/null || exit 1
umask 077

log_service() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" "$*" >> "$LOG_FILE"
}

# The daemon does not need shared/external storage.  Waiting for
# /sdcard/Android caused it never to start on some KernelSU devices.
until [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ]; do
  sleep 2
done

if [ ! -x "$DAEMON" ]; then
  log_service "FATAL: daemon is missing or not executable: $DAEMON"
  exit 1
fi
if [ ! -x "$BASH_BIN" ]; then
  log_service "FATAL: bundled Bash is missing or not executable: $BASH_BIN"
  exit 1
fi

abi=$(getprop ro.product.cpu.abi 2>/dev/null)
case "$abi" in
  arm64-v8a|arm64*) ;;
  *) log_service "WARNING: bundled Bash is AArch64; reported primary ABI is '${abi:-unknown}'." ;;
esac

# A manager normally runs service.sh once per boot.  The guard helps when a
# manager restarts late_start scripts without rebooting.
if command -v pgrep >/dev/null 2>&1 && pgrep -f "$DAEMON" >/dev/null 2>&1; then
  log_service "XtremeBS daemon is already running; not starting a duplicate."
  exit 0
fi

log_service "Starting XtremeBS from module directory."
XBS_MODDIR="$MODDIR" XBS_STATE_DIR="$STATE_DIR" XBS_BASH="$BASH_BIN" \
  "$BASH_BIN" "$DAEMON" >> "$LOG_FILE" 2>&1 &
echo "$!" > "$STATE_DIR/XtremeBSd.pid"
exit 0
