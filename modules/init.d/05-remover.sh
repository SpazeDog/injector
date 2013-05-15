#!/sbin/sh

bb=$CONFIG_BUSYBOX

for i in $CONFIG_DIR_INITRD/init.rc $CONFIG_DIR_INITRD/init.*.rc; do
    if [ -f $i ]; then
        cSkip=false
        $bb touch $i.tmp

        while read lFirst lSecond lRest; do
            if ! $cSkip; then
                case "$lFirst" in
                    "exec"|"start")
                        if echo "$lSecond" | $bb grep -q sysinit; then
                            continue
                        fi
                    ;;

                    "service")
                        if $bb [ "$lSecond" = "sysinit" ]; then
                            cSkip=true; continue
                        fi
                    ;;
                esac

            else
                if $bb [[ "$lFirst" != "service" && "$lFirst" != "on" && "$lFirst" != "import" ]]; then
                    continue
                fi

                cSkip=false
            fi

            lLine="$lFirst $lSecond $lRest"

            $bb [[ "$lFirst" != "service" && "$lFirst" != "on" && "$lFirst" != "import" ]] && echo "    $lLine" >> $i.tmp || echo "$lLine" >> $i.tmp

        done < $i

        $bb cat $i.tmp > $i && $bb rm -rf $i.tmp
    fi
done

if $bb grep -q "/system" /proc/mounts || $bb mount /system; then
    if $bb [ -f /system/etc/install-recovery.sh ]; then
        while read lLine; do
            if ! echo "$lLine" | $bb grep -q "run-parts" && ! echo "$lLine" | $bb grep -q "init.d"; then
                echo "$lLine" >> /tmp/install-recovery.sh
            fi

        done < /system/etc/install-recovery.sh

        $bb test -f /tmp/install-recovery.sh && $bb mv /tmp/install-recovery.sh /system/etc/install-recovery.sh
    fi
fi

exit 0
