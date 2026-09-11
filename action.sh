#!/system/bin/sh
# Legacy browser fallback for managers that expose action.sh but not a native
# module WebUI. KernelSU/ReSukiSU users should use the manager's WebUI button;
# it serves webroot/ directly and does not start a localhost root HTTP server.

SCRIPT_DIR=${0%/*}
[ "$SCRIPT_DIR" = "$0" ] && SCRIPT_DIR=.
MODDIR=$(CDPATH= cd "$SCRIPT_DIR" 2>/dev/null && pwd)
[ -n "$MODDIR" ] || exit 1
STATE_DIR=${XBS_STATE_DIR:-/data/local/tmp/XtremeBS}
WEB_DIR="$MODDIR/webui"
PID_FILE="$STATE_DIR/XtremeBS-httpd.pid"
PORT=8081

if [ "$KSU" = "true" ]; then
  echo "Native WebUI is available. Open Xtreme Battery Saver's WebUI button in the manager."
  exit 0
fi

if [ ! -f "$WEB_DIR/index.html" ]; then
  echo "ERROR: legacy WebUI files are missing: $WEB_DIR"
  exit 1
fi
mkdir -p "$STATE_DIR" 2>/dev/null || {
  echo "ERROR: cannot create $STATE_DIR"
  exit 1
}

server_running=false
if [ -s "$PID_FILE" ]; then
  old_pid=$(cat "$PID_FILE" 2>/dev/null)
  case "$old_pid" in
    *[!0-9]*|'') ;;
    *) kill -0 "$old_pid" 2>/dev/null && server_running=true ;;
  esac
fi

start_httpd() {
  if command -v httpd >/dev/null 2>&1; then
    httpd -p "127.0.0.1:$PORT" -h "$WEB_DIR" -c "$WEB_DIR/httpd.conf" >/dev/null 2>&1 &
  elif [ -x /data/adb/magisk/busybox ]; then
    /data/adb/magisk/busybox httpd -p "127.0.0.1:$PORT" -h "$WEB_DIR" -c "$WEB_DIR/httpd.conf" >/dev/null 2>&1 &
  elif [ -x /data/adb/ksu/bin/busybox ]; then
    /data/adb/ksu/bin/busybox httpd -p "127.0.0.1:$PORT" -h "$WEB_DIR" -c "$WEB_DIR/httpd.conf" >/dev/null 2>&1 &
  else
    return 1
  fi
  echo "$!" > "$PID_FILE"
  return 0
}

if [ "$server_running" = false ]; then
  echo "Starting the legacy local WebUI…"
  if ! start_httpd; then
    echo "ERROR: no compatible httpd/BusyBox was found."
    echo "Edit $STATE_DIR/XtremeBS.conf or use a manager with native WebUI support."
    exit 1
  fi
  sleep 1
fi

echo "Opening http://127.0.0.1:$PORT"
am start -a android.intent.action.VIEW -d "http://127.0.0.1:$PORT" >/dev/null 2>&1 || \
  echo "Open http://127.0.0.1:$PORT in a browser manually."
