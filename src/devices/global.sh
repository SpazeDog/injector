#!/sbin/sh
#####
# This file is part of the Injector Project: https://github.com/spazedog/injector
#  
# Copyright (c) 2013 Daniel Bergløv
#
# Injector is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Injector is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Injector. If not, see <http://www.gnu.org/licenses/>
#####

## A global config file for devices not added to the support tree

if $CONFIG_BUSYBOX [[ -e /proc/mtd && -d /dev/mtd ]]; then
    lDevice=boot

else
    for i in /recovery.fstab /etc/recovery.fstab; do
        if $CONFIG_BUSYBOX [ -e $i ]; then
            lDevice=$($CONFIG_BUSYBOX grep '/boot' $i | $CONFIG_BUSYBOX awk '{print $3}'); break
        fi
    done

    # If we have an BML device where the boot entry is missing in recovery.fstab
    if $CONFIG_BUSYBOX [[ -z "$lDevice" || ! -e $lDevice ]] && $CONFIG_BUSYBOX [ -e /dev/block/bml7 ]; then
        lDevice=/dev/block/bml7
    fi
fi

case "$1" in 
    read)
        # BML devices has the /proc/mtd file, but not the /dev/mtd directory
        if $CONFIG_BUSYBOX [[ ! -e /proc/mtd || -d /dev/mtd ]]; then
            if $CONFIG_BUSYBOX [[ -e "$lDevice" || "$lDevice" = "boot" ]]; then
                if dump_image $lDevice $CONFIG_FILE_BOOTIMG; then
                    exit 0
                fi
            fi

        else
            if $CONFIG_BUSYBOX [ -e "$lDevice" ]; then
                if $CONFIG_BUSYBOX dd if=$lDevice of=$CONFIG_FILE_BOOTIMG; then
                    exit 0
                fi
            fi
        fi
    ;;

    write)
        if $CONFIG_BUSYBOX [[ ! -e /proc/mtd || -d /dev/mtd ]]; then
            if $CONFIG_BUSYBOX [[ -e "$lDevice" || "$lDevice" = "boot" ]]; then
                if flash_image $lDevice $CONFIG_FILE_BOOTIMG; then
                    exit 0
                fi
            fi

        else
            if $CONFIG_BUSYBOX [ -e "$lDevice" ]; then
                if bmlunlock && $CONFIG_BUSYBOX dd if=$CONFIG_FILE_BOOTIMG of=$lDevice; then
                    exit 0
                fi
            fi
        fi
    ;;

    pack)
        # The main injector script will use mkbootimg if abootimg fails. But without a specific device config,
        # we do not have the information needed like kernel base, cmdline etc. So if abootimg fails, there is no more we can do.
        if $CONFIG_BUSYBOX [ -f $CONFIG_FILE_CFG ] && abootimg -u $CONFIG_FILE_BOOTIMG -r $CONFIG_FILE_INITRD -f $CONFIG_FILE_CFG; then
            exit 0
        fi
    ;;

    disassemble)
        if $CONFIG_BUSYBOX [ -d $CONFIG_DIR_INITRD.base ]; then
            $CONFIG_BUSYBOX rm -rf $CONFIG_DIR_INITRD.base/*

        else
            $CONFIG_BUSYBOX mkdir $CONFIG_DIR_INITRD.base
        fi

        if $CONFIG_BUSYBOX gunzip < $CONFIG_FILE_INITRD > $CONFIG_FILE_INITRD.cpio && ( cd $CONFIG_DIR_INITRD.base && $CONFIG_BUSYBOX cpio -i < $CONFIG_FILE_INITRD.cpio ); then
            if $CONFIG_BUSYBOX [ -L $CONFIG_DIR_INITRD.base/init ]; then
                if [ -f $CONFIG_DIR_INITRD.base/sbin/ramdisk.cpio ]; then
                    if ( cd $CONFIG_DIR_INITRD && $CONFIG_BUSYBOX cpio -i < $CONFIG_DIR_INITRD.base/sbin/ramdisk.cpio ); then
                        exit 0
                    fi
                fi

            else
                if $CONFIG_BUSYBOX mv $CONFIG_DIR_INITRD.base $CONFIG_DIR_INITRD; then
                    exit 0
                fi
            fi
        fi
    ;;

    assemble)
        if $CONFIG_BUSYBOX [ -d $CONFIG_DIR_INITRD.base ]; then
            if mkbootfs $CONFIG_DIR_INITRD > $CONFIG_DIR_INITRD.base/sbin/ramdisk.cpio; then
                if mkbootfs $CONFIG_DIR_INITRD.base > $CONFIG_FILE_INITRD.cpio && $bb gzip < $CONFIG_FILE_INITRD.cpio > $CONFIG_FILE_INITRD; then
                    $CONFIG_BUSYBOX rm -rf $CONFIG_DIR_INITRD.base; exit 0
                fi
            fi

        else
            if mkbootfs $CONFIG_DIR_INITRD | $bb gzip > $CONFIG_FILE_INITRD; then
                exit 0
            fi
        fi
    ;;
esac

exit 1
