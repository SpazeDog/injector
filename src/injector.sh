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

VERSION=0.2.0
LOG=/tmp/injector.log
EXIT=1

## 
# Write any output to the log file
##
echo "Starting Injection v.$VERSION" > $LOG
exec >> $LOG 2>&1

while true; do
    while true; do
        ##
        # Locate a working busybox version
        ##
        for i in /tmp/busybox busybox; do
            if $i test true; then
                echo "Using $i as the toolbox for this script"
                bb=$i

                export CONFIG_BUSYBOX=$bb; break
            fi
        done

        if ! $bb test true || $bb test -z "$CONFIG_BUSYBOX"; then
            echo "Could not locate any available busybox binaries on this system!"; break 2
        fi

        ##
        # Assamble some script properties
        ##
        export CONFIG_DIR_INJECTOR=$($bb readlink -f $($bb dirname $0))
        export CONFIG_FILE_BOOTIMG=/tmp/boot.img
        export CONFIG_DIR_BOOTIMG=/tmp/boot_img
        export CONFIG_DIR_INITRD=$CONFIG_DIR_BOOTIMG/initrd
        export CONFIG_FILE_INITRD=$CONFIG_DIR_BOOTIMG/initrd.img
        export CONFIG_FILE_ZIMAGE=$CONFIG_DIR_BOOTIMG/zImage
        export CONFIG_FILE_STAGE2=$CONFIG_DIR_BOOTIMG/stage2.img
        export CONFIG_FILE_CFG=$CONFIG_DIR_BOOTIMG/bootimg.cfg
        export CONFIG_DIR_TOOLS=$CONFIG_DIR_INJECTOR/tools
        export CONFIG_DIR_DEVICES=$CONFIG_DIR_INJECTOR/devices
        export CONFIG_DIR_SCRIPTS=$CONFIG_DIR_INJECTOR/injector.d

        ##
        # This is used by the updater-script
        ##
        $bb test -e /tmp/injector.prop && echo -n "" > /tmp/injector.prop || $bb touch /tmp/injector.prop

        ##
        # Get the device information
        ##
        export CONFIG_DEVICE_MODEL=$($bb grep -e "^ro.product.model=" /default.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')
        export CONFIG_DEVICE_BOARD=$($bb grep -e "^ro.product.board=" /default.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')
        export CONFIG_DEVICE_NAME=$($bb grep -e "^ro.product.device=" /default.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')
        export CONFIG_DEVICE_PLATFORM=$($bb grep -e "^ro.board.platform=" /default.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')

        ##
        # Load settings from the device configuration file
        ##
        for i in $CONFIG_DEVICE_NAME $CONFIG_DEVICE_MODEL $CONFIG_DEVICE_BOARD $CONFIG_DEVICE_PLATFORM; do
            if $bb [ -f $CONFIG_DIR_DEVICES/$i.conf ]; then
                export CONFIG_DEVICE_SETTINGS=$CONFIG_DIR_DEVICES/$i.conf

                echo "Using configuration file $i.conf"

                while read tLine; do
                    if $bb test ! -z "$tLine" && ! echo "$tLine" | $bb grep -q "#"; then
                        lLineName=$(echo "$tLine" | $bb sed 's/^\([^=]*\)=.*$/\1/' | $bb sed 's/^[ \t]*//' | $bb sed 's/[ \t]*$//' | $bb tr '[a-z]' '[A-Z]')
                        lLineContent="`echo "$tLine" | $bb sed 's/^[^=]*=\(.*\)$/\1/' | $bb sed 's/^[ \t]*//' | $bb sed 's/[ \t]*$//'`"

                        eval export "SETTINGS_$lLineName=\"$lLineContent\""
                    fi

                done < $CONFIG_DEVICE_SETTINGS

                if $bb [ -n "$SETTINGS_SCRIPT" ]; then
                    if $bb [ -e $CONFIG_DIR_DEVICES/$SETTINGS_SCRIPT ]; then
                        SETTINGS_SCRIPT=$CONFIG_DIR_DEVICES/$SETTINGS_SCRIPT

                    elif $bb [ -e $CONFIG_DIR_DEVICES/$SETTINGS_SCRIPT.sh ]; then
                        SETTINGS_SCRIPT=$CONFIG_DIR_DEVICES/$SETTINGS_SCRIPT.sh

                    else
                        SETTINGS_SCRIPT=
                    fi
                fi

                break
            fi
        done

        if $bb [ -z "$CONFIG_DEVICE_SETTINGS" ]; then
            echo "Could not locate any configuration file for this device!"; break

        elif $bb [ -z "$SETTINGS_SCRIPT" ] && $bb [[ "$SETTINGS_DEVICE" != "boot" && ! -e "$SETTINGS_DEVICE" ]]; then
            echo "The configuration file $CONFIG_DEVICE_SETTINGS does not contain any valid information about the boot partition!"; break
        fi

        ##
        # Prepare our internal dirs and files
        ##
        $bb mkdir -p $CONFIG_DIR_BOOTIMG || $bb mkdir $CONFIG_DIR_BOOTIMG
        $bb mkdir -p $CONFIG_DIR_INITRD || $bb mkdir $CONFIG_DIR_INITRD

        $bb chmod 0775 $CONFIG_DIR_TOOLS/bin/*
        $bb chmod 0775 $CONFIG_DIR_DEVICES/*.sh
        $bb chmod 0775 $CONFIG_DIR_SCRIPTS/*.sh

        export PATH=$CONFIG_DIR_TOOLS/bin:$PATH

        ##
        # Extract the boot.img from the device
        ##
        echo "Extracting the device boot.img"

        if $bb [ -n "$SETTINGS_SCRIPT" ]; then
            if ! $SETTINGS_SCRIPT read; then
                echo "It was not possible to extract the boot.img from the device!"; break
            fi

        else
            if ! dump_image $SETTINGS_DEVICE $CONFIG_FILE_BOOTIMG; then
                echo "It was not possible to extract the boot.img from the device!"; break
            fi
        fi

        if ! abootimg -i $CONFIG_FILE_BOOTIMG; then
            echo "The extracted image is not a valid boot.img!"; break
        fi

        ##
        # Disassemble the boot.img
        ##
        bUseAbootimg=false

        echo "Disassembling the boot.img"

        if ( cd $CONFIG_DIR_BOOTIMG && abootimg -x $CONFIG_FILE_BOOTIMG); then
            lBootSumOld=$($bb md5sum $CONFIG_FILE_BOOTIMG | $bb awk '{print $1}')

            if abootimg -u $CONFIG_FILE_BOOTIMG -r $CONFIG_FILE_INITRD -f $CONFIG_FILE_CFG 1> /dev/null; then
                if $bb [ "`$bb md5sum $CONFIG_FILE_BOOTIMG | $bb awk '{print $1}'`" = "$lBootSumOld" ]; then
                    bUseAbootimg=true
                fi
            fi

        else
        # elif ! unpack-bootimg -i $cImgBoot -o $cDirectoryBoot -k $($bb basename $cFileBootZImage) -r $($bb basename $cFileBootInitrd) -s $($bb basename $cFileBootSecond) 
            # lPart=0

            # for vOffset in `$bb od -A d -tx1 "$cImgBoot" | $bb grep '1f 8b 08' | $bb awk '{print $1}'`; do
            #     lPart=$(($lPart + 1))
            # 
			# 	case $lPart in
			# 		1) vFile=$cFileBootZImage ;;
			# 		2) vFile=$cFileBootInitrd ;;
			# 		3) vFile=$cFileBootSecond ;;
			# 	esac
            # 
			# 	$bb dd if=$cImgBoot bs=1 skip=$vOffset of=$vFile
            # done

            if ! unpack-bootimg -i $CONFIG_FILE_BOOTIMG -o $CONFIG_DIR_BOOTIMG -k $($bb basename $CONFIG_FILE_ZIMAGE) -r $($bb basename $CONFIG_FILE_INITRD) -s $($bb basename $CONFIG_FILE_STAGE2); then
                echo "It was not possible to disassemble the boot.img!"; break
            fi
        fi

        ##
        # Disassemble initrd
        ##
        echo "Disassembling the initrd.img"

        if ! $bb zcat $CONFIG_FILE_INITRD | ( cd $CONFIG_DIR_INITRD && $bb cpio -i ); then
            echo "It was not possible to disassemble the initrd.img!"; break
        fi

        ##
        # Execute all of the injector.d scripts
        ##
        echo "Running injector scripts"

        for lInjectorScript in `$bb find $CONFIG_DIR_SCRIPTS -name '*.sh' | sort -n`; do
            echo "Executing $($bb basename $lInjectorScript)"

            if ! $lInjectorScript; then
                echo "The injector.d script $($bb basename $lInjectorScript) failed to execute properly!"; break 2
            fi
        done

        ##
        # Re-assamble initrd.img
        ##
        echo "Re-assambling the initrd.img"

        if ! mkbootfs $CONFIG_DIR_INITRD | $bb gzip > $CONFIG_FILE_INITRD; then
            if ! ( cd $CONFIG_DIR_INITRD && $bb find | $bb sort | $bb cpio -o -H newc ) | $bb gzip > $CONFIG_FILE_INITRD; then
                echo "It was not possible to Re-assamble the initrd.img!"; break
            fi
        fi

        ##
        # Re-assamble boot.img
        ##
        echo "Re-assambling the boot.img"

        if ! $bUseAbootimg || ! abootimg -u $CONFIG_FILE_BOOTIMG -r $CONFIG_FILE_INITRD -f $CONFIG_FILE_CFG; then
            if $bb [ "$SETTINGS_RECREATE" != "false" ]; then
                # Abootimg some times fails while updating, and it is not great at creating images from scratch
                if ! mkbootimg -o $CONFIG_FILE_BOOTIMG --kernel $CONFIG_FILE_ZIMAGE --ramdisk $CONFIG_FILE_INITRD $($bb test -n "$SETTINGS_BASE" && echo "--base") $SETTINGS_BASE $($bb test -n "$SETTINGS_CMDLINE" && echo "--cmdline") "$SETTINGS_CMDLINE" $($bb test -n "$SETTINGS_PAGESIZE" && echo "--pagesize") $SETTINGS_PAGESIZE $($bb test -f $CONFIG_FILE_STAGE2 && echo "--second") $($bb test -f $CONFIG_FILE_STAGE2 && echo $CONFIG_FILE_STAGE2); then
                    echo "It was not possible to Re-assamble the boot.img!"; break
                fi
            fi
        fi

        if ! abootimg -i $CONFIG_FILE_BOOTIMG; then
            echo "The new boot.img was corrupted during creation!"; break
        fi

        ##
        # Write boot.img to the device
        ##
        echo "Writing the new boot.img to the device"

        if $bb [ -n "$SETTINGS_SCRIPT" ]; then
            if ! $SETTINGS_SCRIPT write; then
                echo "It was not possible to write the boot.img to the device!"; break
            fi

        else
            if ! erase_image $SETTINGS_DEVICE || ! flash_image $SETTINGS_DEVICE $CONFIG_FILE_BOOTIMG; then
                echo "It was not possible to write the boot.img to the device!"; break
            fi
        fi

        EXIT=0

        break
    done

    for i in /etc/recovery.fstab /recovery.fstab; do
        if $bb [[ -f $i && "`$bb grep /sdcard /etc/recovery.fstab | $bb awk '{print $2}'`" = "datamedia" ]]; then
            tDevice=/data
            tLocation=/data/media/0

            break

        else
            tDevice=/sdcard
            tLocation=$tDevice
        fi
    done

    if $bb grep -q $tDevice /proc/mounts || $bb mount $tDevice; then
        if $bb [[ "$SETTINGS_LOCKED" = "true" && -f $CONFIG_FILE_BOOTIMG ]]; then
            echo "Copying boot.img to the sdcard"

            $bb cp $CONFIG_FILE_BOOTIMG $tLocation/

            echo "locked.message=The boot.img has been copied to the sdcard" >> /tmp/injector.prop
            echo "locked.status=1" >> /tmp/injector.prop
        fi

        echo "Copying log file to the sdcard"

        $bb cp $LOG $tLocation/

        echo "log.message=The log file has been copied to the sdcard" >> /tmp/injector.prop
        echo "log.status=1" >> /tmp/injector.prop
    fi

    echo "Cleaning up old files and directories"

    (
        # For some reason, the boot.img needs some time before it can be deleted. And it might hang while trying, so do this in a subprocess
        $bb sleep 1

        $bb rm -rf $CONFIG_DIR_BOOTIMG
        $bb rm -rf $CONFIG_FILE_BOOTIMG
    ) & 

    echo "exit.status=$EXIT" >> /tmp/injector.prop && exit $EXIT

    break
done
