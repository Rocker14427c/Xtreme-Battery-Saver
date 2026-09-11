#!/system/bin/sh
# Magisk/KernelSU-compatible installer customisation.
# Keep webroot/ out of the permission sweep: KernelSU/ReSukiSU assigns the
# required WebUI SELinux context itself during installation.

SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=true

ui_print "  Installing Xtreme Battery Saver"
ui_print "  Native KernelSU/ReSukiSU WebUI: included"
ui_print "  Runtime config: /data/local/tmp/XtremeBS/XtremeBS.conf"

# Do not recursively chmod the module.  Aside from being unnecessarily broad,
# that used to overwrite the manager-controlled WebUI file permissions.
for file in \
  "$MODPATH/action.sh" \
  "$MODPATH/service.sh" \
  "$MODPATH/xbs-webui.sh" \
  "$MODPATH/system/bin/bash" \
  "$MODPATH/system/bin/bc" \
  "$MODPATH/system/bin/XBSctl" \
  "$MODPATH/system/bin/XtremeBSd" \
  "$MODPATH/webui/cgi-bin/load.cgi" \
  "$MODPATH/webui/cgi-bin/load_log.cgi" \
  "$MODPATH/webui/cgi-bin/save.cgi" \
  "$MODPATH/webui/cgi-bin/save_log.cgi" \
  "$MODPATH/webui/cgi-bin/status.cgi"; do
  [ -e "$file" ] && set_perm "$file" 0 0 0755
done
