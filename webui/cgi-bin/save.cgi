#!/system/bin/sh
# Write streamed POST data atomically; command substitutions lose trailing
# newlines and can corrupt a hand-edited configuration.
CGI_DIR=${0%/*}
[ "$CGI_DIR" = "$0" ] && CGI_DIR=.
MODDIR=$(CDPATH= cd "$CGI_DIR/../.." 2>/dev/null && pwd)
[ -n "$MODDIR" ] || exit 1
STATE_DIR=${XBS_STATE_DIR:-/data/local/tmp/XtremeBS}
CONF=${XBS_CONF:-$STATE_DIR/XtremeBS.conf}
TMP="${CONF}.tmp.$$"

echo "Content-type: text/plain"
echo ""

mkdir -p "$STATE_DIR" 2>/dev/null || {
  echo "ERROR: cannot create $STATE_DIR"
  exit 1
}
umask 077
if ! cat > "$TMP" || [ ! -s "$TMP" ]; then
  rm -f "$TMP"
  echo "ERROR: refusing to save an empty configuration"
  exit 1
fi
if ! mv -f "$TMP" "$CONF"; then
  rm -f "$TMP"
  echo "ERROR: cannot write $CONF"
  exit 1
fi
chmod 600 "$CONF" 2>/dev/null || true
"$MODDIR/system/bin/XBSctl" reload 2>&1
