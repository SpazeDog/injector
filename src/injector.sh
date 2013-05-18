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

VERSION=0.2.8
LOG=/tmp/injector.log
EXIT=1
ACTION=$1

## 
# Write any output to the log file
##
echo "Starting Injector v.$VERSION" > $LOG
exec >> $LOG 2>&1

while true; do
    while true; do
        ##
        # Locate a working busybox version
        ##
        for i in /tmp/busybox /tmp/aroma-data/busybox busybox; do
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

        if $bb [[ -z "$CONFIG_DEVICE_MODEL" && -z "$CONFIG_DEVICE_BOARD" && -z "$CONFIG_DEVICE_NAME" && -z "$CONFIG_DEVICE_PLATFORM" ]]; then
            if $bb grep -q '/system' /proc/mounts || $bb mount /system; then
                export CONFIG_DEVICE_MODEL=$($bb grep -e "^ro.product.model=" /system/build.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')
                export CONFIG_DEVICE_BOARD=$($bb grep -e "^ro.product.board=" /system/build.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')
                export CONFIG_DEVICE_NAME=$($bb grep -e "^ro.product.device=" /system/build.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')
                export CONFIG_DEVICE_PLATFORM=$($bb grep -e "^ro.board.platform=" /system/build.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')
            fi
        fi

        ##
        # Load settings from the device configuration file
        ##
        for i in $CONFIG_DEVICE_NAME $CONFIG_DEVICE_MODEL $CONFIG_DEVICE_BOARD $CONFIG_DEVICE_PLATFORM global; do
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

                ##
                # Create some default script action states
                # These should not be able to be set directly from the config file. They should only be set using 'actions'
                ##
                export SETTINGS_ACTIONS_READ=false
                export SETTINGS_ACTIONS_WRITE=false
                export SETTINGS_ACTIONS_UNPACK=false
                export SETTINGS_ACTIONS_PACK=false
                export SETTINGS_ACTIONS_DISASSEMBLE=false
                export SETTINGS_ACTIONS_ASSEMBLE=false
                export SETTINGS_ACTIONS_VALIDATE=false

                if $bb [ -n "$SETTINGS_SCRIPT" ]; then
                    if $bb [ -e $CONFIG_DIR_DEVICES/$SETTINGS_SCRIPT ]; then
                        SETTINGS_SCRIPT=$CONFIG_DIR_DEVICES/$SETTINGS_SCRIPT

                    elif $bb [ -e $CONFIG_DIR_DEVICES/$SETTINGS_SCRIPT.sh ]; then
                        SETTINGS_SCRIPT=$CONFIG_DIR_DEVICES/$SETTINGS_SCRIPT.sh

                    else
                        SETTINGS_SCRIPT=
                    fi

                    if $bb [[ -n "$SETTINGS_SCRIPT" && -n "$SETTINGS_ACTIONS" ]]; then
                        for lAction in $SETTINGS_ACTIONS; do
                            eval export "SETTINGS_ACTIONS_$(echo $lAction | $bb tr '[a-z]' '[A-Z]')=true"
                        done
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
        # Prepare the primary storage
        ##
        for i in /etc/recovery.fstab /recovery.fstab; do
            if $bb [[ -f $i && "`$bb grep /sdcard /etc/recovery.fstab | $bb awk '{print $2}'`" = "datamedia" ]]; then
                if $bb grep -q '/data' /proc/mounts || $bb mount /data; then
                    export CONFIG_DIR_STORAGE=/data/media/0; break
                fi

            elif [ -f $i ]; then
                if $bb grep -q '/sdcard' /proc/mounts || $bb mount /sdcard; then
                    export CONFIG_DIR_STORAGE=/sdcard; break
                fi
            fi
        done

        if $bb [ -z "$CONFIG_DIR_STORAGE" ] && $bb [ "$ACTION" != "inject-flash-current" ]]; then
            echo "It was not possible to mount the parimary storage!"
        fi

        lFileStoredBootimg=$CONFIG_DIR_STORAGE/Injector/boot.img

        ##
        # Prepare our internal dirs and files
        ##
        if $bb [[ -n "$CONFIG_DIR_STORAGE" && ! -d $CONFIG_DIR_STORAGE/Injector ]]; then
            $bb mkdir -p $CONFIG_DIR_STORAGE/Injector || $bb mkdir $CONFIG_DIR_STORAGE/Injector
        fi

        $bb mkdir -p $CONFIG_DIR_BOOTIMG || $bb mkdir $CONFIG_DIR_BOOTIMG
        $bb mkdir -p $CONFIG_DIR_INITRD || $bb mkdir $CONFIG_DIR_INITRD

        $bb chmod 0775 $CONFIG_DIR_TOOLS/bin/*
        $bb chmod 0775 $CONFIG_DIR_DEVICES/*.sh
        $bb chmod 0775 $CONFIG_DIR_SCRIPTS/*.sh

        export PATH=$CONFIG_DIR_TOOLS/bin:$PATH

        ##
        # Extract the boot.img from the device
        ##
        if $bb [[ "$ACTION" = "inject-stored" || "$ACTION" = "inject-flash-stored" || "$ACTION" = "flash-stored" ]]; then
            echo "Extracting the boot.img from $lFileStoredBootimg"

            if $bb [ ! -f $lFileStoredBootimg ] || ! $bb cp $lFileStoredBootimg $CONFIG_FILE_BOOTIMG; then
                echo "It was not possible to extract the boot.img from the storage!"; break
            fi

        else
            echo "Extracting the device boot.img"

            if $SETTINGS_ACTIONS_READ && ! $SETTINGS_SCRIPT read; then
                echo "It was not possible to extract the boot.img from the device!"; break

            elif ! $SETTINGS_ACTIONS_READ && ! dump_image $SETTINGS_DEVICE $CONFIG_FILE_BOOTIMG; then
                echo "It was not possible to extract the boot.img from the device!"; break
            fi
        fi

        if $SETTINGS_ACTIONS_VALIDATE && ! $SETTINGS_SCRIPT validate; then
            echo "The extracted image is not a valid boot.img!"; break

        elif ! $SETTINGS_ACTIONS_VALIDATE && ! abootimg -i $CONFIG_FILE_BOOTIMG; then
            echo "The extracted image is not a valid boot.img!"; break
        fi

        if $bb [ "$ACTION" != "flash-stored" ]; then
            ##
            # Disassemble the boot.img
            ##
            echo "Unpacking the boot.img"

            if $SETTINGS_ACTIONS_UNPACK && ! $SETTINGS_SCRIPT unpack; then
                echo "It was not possible to unpack the boot.img!"; break

            elif ! $SETTINGS_ACTIONS_UNPACK && ! ( cd $CONFIG_DIR_BOOTIMG && abootimg -x $CONFIG_FILE_BOOTIMG); then
                if ! unpack-bootimg -i $CONFIG_FILE_BOOTIMG -o $CONFIG_DIR_BOOTIMG -k $($bb basename $CONFIG_FILE_ZIMAGE) -r $($bb basename $CONFIG_FILE_INITRD) -s $($bb basename $CONFIG_FILE_STAGE2); then
                    echo "It was not possible to unpack the boot.img!"; break
                fi
            fi

            ##
            # Disassemble initrd
            ##
            echo "Disassembling the initrd.img"

            if $SETTINGS_ACTIONS_DISASSEMBLE && ! $SETTINGS_SCRIPT disassemble; then
                echo "It was not possible to disassemble the initrd.img!"; break

            elif ! $SETTINGS_ACTIONS_DISASSEMBLE && ! ( $bb gunzip < $CONFIG_FILE_INITRD > $CONFIG_FILE_INITRD.cpio && ( cd $CONFIG_DIR_INITRD && $bb cpio -i < $CONFIG_FILE_INITRD.cpio ) ); then
                if ! ( $bb lzma -dc < $CONFIG_FILE_INITRD > $CONFIG_FILE_INITRD.cpio && ( cd $CONFIG_DIR_INITRD && $bb cpio -i < $CONFIG_FILE_INITRD.cpio ) ); then
                    echo "It was not possible to disassemble the initrd.img!"; break
                fi
            fi

            if $bb [[ ! -e $CONFIG_DIR_INITRD/init || ! -e $CONFIG_DIR_INITRD/init.rc ]]; then
                echo "The disassembled initrd.img is corrupted!"; break
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

            if $SETTINGS_ACTIONS_ASSEMBLE && ! $SETTINGS_SCRIPT assemble; then
                echo "It was not possible to Re-assamble the initrd.img!"; break

            elif ! $SETTINGS_ACTIONS_ASSEMBLE && ! ( mkbootfs $CONFIG_DIR_INITRD > $CONFIG_FILE_INITRD.cpio && $bb gzip < $CONFIG_FILE_INITRD.cpio > $CONFIG_FILE_INITRD ); then
                if ! ( ( cd $CONFIG_DIR_INITRD && $bb find | $bb sort | $bb cpio -o -H newc > $CONFIG_FILE_INITRD.cpio ) && $bb gzip < $CONFIG_FILE_INITRD.cpio > $CONFIG_FILE_INITRD ); then
                    echo "It was not possible to Re-assamble the initrd.img!"; break
                fi
            fi

            ##
            # Re-assamble boot.img
            ##
            echo "Re-packing the boot.img"

            if $SETTINGS_ACTIONS_PACK && ! $SETTINGS_SCRIPT pack; then
                echo "It was not possible to Re-pack the boot.img!"; break

            elif ! $SETTINGS_ACTIONS_PACK; then
                if $bb [ ! -f $CONFIG_FILE_CFG ] || ! abootimg -u $CONFIG_FILE_BOOTIMG -r $CONFIG_FILE_INITRD -f $CONFIG_FILE_CFG; then
                    # Abootimg some times fails while updating, and it is not great at creating images from scratch
                    cmdMkBootimg="mkbootimg -o $CONFIG_FILE_BOOTIMG --kernel $CONFIG_FILE_ZIMAGE --ramdisk $CONFIG_FILE_INITRD $($bb test -n "$SETTINGS_BASE" && echo "--base $SETTINGS_BASE") $($bb test -n "$SETTINGS_CMDLINE" && echo "--cmdline \"$SETTINGS_CMDLINE\"") $($bb test -n "$SETTINGS_PAGESIZE" && echo "--pagesize $SETTINGS_PAGESIZE") $($bb test -f $CONFIG_FILE_STAGE2 && echo "--second $CONFIG_FILE_STAGE2")"

                    if ! eval $cmdMkBootimg; then
                        echo "It was not possible to Re-pack the boot.img!"; break
                    fi
                fi
            fi
        fi

        if $SETTINGS_ACTIONS_VALIDATE && ! $SETTINGS_SCRIPT validate; then
            echo "The new boot.img was corrupted during creation!"; break

        elif ! $SETTINGS_ACTIONS_VALIDATE && ! abootimg -i $CONFIG_FILE_BOOTIMG; then
            echo "The new boot.img was corrupted during creation!"; break
        fi

        ##
        # Write boot.img to the device
        ##
        if $bb [[ "$ACTION" = "inject-flash-current" || "$ACTION" = "inject-flash-stored" || "$ACTION" = "flash-stored" ]]; then
            echo "Writing the new boot.img to the device"

            if $SETTINGS_ACTIONS_WRITE; then
                if ! $SETTINGS_SCRIPT write; then
                    echo "It was not possible to write the boot.img to the device!"

                    if $bb [ "$SETTINGS_LOCKED" != "true" ]; then
                        break
                    fi
                fi

            else
                if ! erase_image $SETTINGS_DEVICE || ! flash_image $SETTINGS_DEVICE $CONFIG_FILE_BOOTIMG; then
                    echo "It was not possible to write the boot.img to the device!"

                    if $bb [ "$SETTINGS_LOCKED" != "true" ]; then
                        break

                    else
                        if $bb cp $CONFIG_FILE_BOOTIMG $lFileStoredBootimg; then
                            echo "The boot.img was moved to $lFileStoredBootimg. Use 'fastboot flash boot boot.img' to flash it to your boot partition"
                            echo "exit.message=The boot.img was moved to $lFileStoredBootimg. Use 'fastboot flash boot boot.img' to flash it to your boot partition" >> /tmp/injector.prop
                        fi
                    fi
                fi
            fi

        else
            echo "Moving the boot.img to the primary storage"

            if ! $bb cp $CONFIG_FILE_BOOTIMG $lFileStoredBootimg; then
                echo "It was not possible to move the boot.img to the primary storage!"; break

            else
                echo "The boot.img was moved to $lFileStoredBootimg"
                echo "exit.message=The boot.img was moved to $lFileStoredBootimg" >> /tmp/injector.prop
            fi
        fi

        EXIT=0

        break
    done

    if $bb [ -n "$CONFIG_DIR_STORAGE" ]; then
        echo "Moving log file to $CONFIG_DIR_STORAGE/Injector/injector.log"
        $bb cp $LOG $CONFIG_DIR_STORAGE/Injector/
    fi

    echo "Cleaning up old files and directories"

    # For some reason, the boot.img needs some time before it can be deleted. And it might hang while trying, so do this in a subprocess
    $bb sleep 1

    $bb rm -rf $CONFIG_DIR_BOOTIMG
    $bb rm -rf $CONFIG_FILE_BOOTIMG

    break
done

echo "exit.status=$EXIT" >> /tmp/injector.prop && exit $EXIT
