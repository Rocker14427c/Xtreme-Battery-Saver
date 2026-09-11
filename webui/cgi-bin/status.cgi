#!/system/bin/sh
CGI_DIR=${0%/*}
[ "$CGI_DIR" = "$0" ] && CGI_DIR=.
MODDIR=$(CDPATH= cd "$CGI_DIR/../.." 2>/dev/null && pwd)
[ -n "$MODDIR" ] || exit 1

echo "Content-type: text/plain"
echo ""
"$MODDIR/xbs-webui.sh" get-status
