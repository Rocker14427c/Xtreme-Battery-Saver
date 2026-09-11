#!/system/bin/sh
# Export a copy rather than overwriting the daemon's live log file.
STAMP=$(date '+%Y%m%d-%H%M%S' 2>/dev/null || echo export)
OUT="/sdcard/XtremeBS-report-$STAMP.log"
TMP="${OUT}.tmp.$$"

echo "Content-type: text/plain"
echo ""

if ! cat > "$TMP" || ! mv -f "$TMP" "$OUT"; then
  rm -f "$TMP"
  echo "ERROR: failed to export the log to external storage"
  exit 1
fi
echo "Log exported to $OUT"
