#!/sbin/sh

bb=$CONFIG_BUSYBOX

lEntered=false
lSkip=false
$bb touch $CONFIG_DIR_INITRD/init.rc.tmp

while read lFirst lSecond lRest; do
    if ! $lSkip; then
        if $lEntered; then
            if [ "$lFirst" = "class_start" ]; then
                echo "    # Invoke /system/etc/init.d" >> $CONFIG_DIR_INITRD/init.rc.tmp
                echo "    exec /system/bin/sysinit" >> $CONFIG_DIR_INITRD/init.rc.tmp
                echo "" >> $CONFIG_DIR_INITRD/init.rc.tmp
                echo "    # Invoke /system/etc/boot.d" >> $CONFIG_DIR_INITRD/init.rc.tmp
                echo "    start sysinit" >> $CONFIG_DIR_INITRD/init.rc.tmp
                echo "" >> $CONFIG_DIR_INITRD/init.rc.tmp

                lSkip=true
            fi

        elif $bb [[ "$lFirst" = "on" && "$lSecond" = "boot" ]]; then
            lEntered=true
        fi
    fi

    lLine="$lFirst $lSecond $lRest"

    $bb [[ "$lFirst" != "service" && "$lFirst" != "on" && "$lFirst" != "import" ]] && echo "    $lLine" >> $CONFIG_DIR_INITRD/init.rc.tmp || echo "$lLine" >> $CONFIG_DIR_INITRD/init.rc.tmp

done < $CONFIG_DIR_INITRD/init.rc

$bb cat $CONFIG_DIR_INITRD/init.rc.tmp > $CONFIG_DIR_INITRD/init.rc && $bb rm -rf $CONFIG_DIR_INITRD/init.rc.tmp

$bb cat <<EOF >> $CONFIG_DIR_INITRD/init.rc

# Service which invokes /sysem/etc/boot.d
service sysinit /system/bin/logwrapper /system/xbin/run-parts /system/etc/boot.d
    user root
    oneshot

EOF

if $bb grep -q "/system" /proc/mounts || $bb mount /system; then

$bb cat <<EOF > /system/bin/sysinit
#!/system/bin/sh

export PATH=/sbin:/system/sbin:/system/bin:/system/xbin
/system/bin/logwrapper /system/xbin/run-parts /system/etc/init.d
EOF

    $bb chmod 0775 /system/bin/sysinit

    $bb test ! -d /system/etc/init.d && $bb mkdir /system/etc/init.d
    $bb test ! -d /system/etc/boot.d && $bb mkdir /system/etc/boot.d

else
    exit 1
fi

exit 0
