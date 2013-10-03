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

VERSION=0.3.0
LOG=/tmp/injector.log
RESULT=1
ACTION=$1

SYSTEM_MOUNTED=false
STORAGE_MOUNTED=false

## 
# Write all output to the log file
##
echo "Starting Injector v.$VERSION" > $LOG
exec >> $LOG 2>&1

##
# This is used by the updater-script
##
echo -n "" > /tmp/injector.prop 2> /dev/null || echo "" > /tmp/injector.prop

while true; do
    while true; do
        ##
        # Locate a working busybox version
        ##
        BUSYBOX_FOUND=false

        for i in /tmp/busybox /tmp/aroma-data/busybox busybox; do
            if $i test true 2> /dev/null; then
                echo "Using $i as the toolbox for this script"
                bb=$i

                BUSYBOX_FOUND=true

                break
            fi
        done

        if ! $BUSYBOX_FOUND; then
            echo "Could not locate any available busybox binaries on this system!"; break 2
        fi

        ##
        # Prepare actions
        ##
        ACTION_USE_STORED=false
        ACTION_INJECT=false
        ACTION_FLASH=false

        if echo "$ACTION" | $bb grep -q -e '\(^\||\)stored\($\||\)'; then
            ACTION_USE_STORED=true
        fi

        if echo "$ACTION" | $bb grep -q -e '\(^\||\)inject\($\||\)'; then
            ACTION_INJECT=true
        fi

        if echo "$ACTION" | $bb grep -q -e '\(^\||\)flash\($\||\)'; then
            ACTION_FLASH=true
        fi

        ##
        # Assamble some script properties
        ##
        export CONFIG_BUSYBOX=$bb
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

        export PATH=$CONFIG_DIR_TOOLS/bin:$PATH

        ##
        # Prepare our internal dirs and files
        ##
        $bb mkdir -p "$CONFIG_DIR_BOOTIMG" 2> /dev/null || $bb mkdir "$CONFIG_DIR_BOOTIMG"
        $bb mkdir -p "$CONFIG_DIR_INITRD" 2> /dev/null || $bb mkdir "$CONFIG_DIR_INITRD"

        $bb chmod 0775 $CONFIG_DIR_TOOLS/bin/*
        $bb chmod 0775 $CONFIG_DIR_DEVICES/*.sh
        $bb chmod 0775 $CONFIG_DIR_SCRIPTS/*.sh

        ##
        # Try mounting the system partition
        ##
        if $bb grep -q '/system' /proc/mounts || $bb mount /system; then
            SYSTEM_MOUNTED=true
        fi

        ##
        # Get the device information
        ##
        for productName in model board device platform; do
            productVariable=CONFIG_DEVICE_$(echo $productName | $bb tr '[a-z]' '[A-Z]')

            if $bb test -n "`$bb grep -qe "^ro.product.$productName=" /default.prop`"; then
                export $productVariable=$($bb grep -e "^ro.product.$productName=" /default.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')

            elif $SYSTEM_MOUNTED; then
                export $productVariable=$($bb grep -e "^ro.product.$productName=" /system/build.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/g')
            fi
        done

        ##
        # Load settings from the device configuration file
        ##
        for configName in "$CONFIG_DEVICE_NAME" "$CONFIG_DEVICE_MODEL" "$CONFIG_DEVICE_BOARD" "$CONFIG_DEVICE_PLATFORM" global; do
            configFile="$CONFIG_DIR_DEVICES/$configName.conf"

            if $bb test -f "$configFile"; then
                echo "Using configuration file '$configName.conf'"
                export CONFIG_DEVICE_SETTINGS="$configFile"

                while read configLine; do
                    if $bb test -n "$configLine" && ! echo "$configLine" | grep -q '#'; then
                        settingsName=SETTINGS_$(echo "$configLine" | $bb sed 's/^\([^=]*\)=.*$/\1/' | $bb sed 's/^[ \t]*//' | $bb sed 's/[ \t]*$//' | $bb tr '[a-z]' '[A-Z]')
                        settingsValue="`echo "$configLine" | $bb sed 's/^[^=]*=\(.*\)$/\1/' | $bb sed 's/^[ \t]*//' | $bb sed 's/[ \t]*$//'`"

                        export $settingsName="$settingsValue"
                    fi

                done < "$configFile"

                ##
                # Create some default script action states
                # These should not be able to be set directly from the config file. They should only be set using 'actions'
                ##
                export SETTINGS_ACTIONS_DEVICE=false
                export SETTINGS_ACTIONS_READ=false
                export SETTINGS_ACTIONS_WRITE=false
                export SETTINGS_ACTIONS_UNPACK=false
                export SETTINGS_ACTIONS_PACK=false
                export SETTINGS_ACTIONS_DISASSEMBLE=false
                export SETTINGS_ACTIONS_ASSEMBLE=false
                export SETTINGS_ACTIONS_VALIDATE=false

                for scriptName in "$SETTINGS_SCRIPT" "$SETTINGS_SCRIPT.sh"; do
                    scriptFile="$CONFIG_DIR_DEVICES/$scriptName"

                    if $bb test -f "$scriptFile"; then
                        echo "Using associated script file '$scriptName'"
                        SETTINGS_SCRIPT="$scriptFile"

                        if $bb test -n "$SETTINGS_ACTIONS"; then
                            for actionName in $SETTINGS_ACTIONS; do
                                actionVariable=SETTINGS_ACTIONS_$(echo $actionName | $bb tr '[a-z]' '[A-Z]')

                                export $actionVariable=true
                            done
                        fi

                        break
                    fi
                done

                break
            fi
        done

        if $bb test ! -f "$CONFIG_DEVICE_SETTINGS"; then
            echo "Could not locate any configuration file for this device!"; break

        elif $bb test -f "$SETTINGS_SCRIPT" && $SETTINGS_ACTIONS_DEVICE; then
            export SETTINGS_DEVICE=$($SETTINGS_SCRIPT "device"); status=$?

            if $bb $status -ne 0 || ( $bb test "$SETTINGS_DEVICE" != "boot" && $bb test ! -e "$SETTINGS_DEVICE" ); then
                echo "Could not locate the device file '$SETTINGS_DEVICE' from the device script!"; break
            fi

        elif $bb test ! -f "$SETTINGS_SCRIPT" && ( $bb test "$SETTINGS_DEVICE" != "boot" && $bb test ! -e "$SETTINGS_DEVICE" ); then
            echo "The configuration file '$CONFIG_DEVICE_SETTINGS' does not contain any valid information about the boot partition!"; break
        fi

        ##
        # Prepare the primary storage
        ##
        for fstabFile in /etc/recovery.fstab /recovery.fstab; do
            if $bb test -f $fstabFile; then
                if $bb test "`$bb grep /sdcard $i | $bb awk '{print $2}'`" = "datamedia"; then
                    if $bb grep -q '/data' /proc/mounts || $bb mount /data; then
                        export CONFIG_DIR_STORAGE=/data/media/0
                    fi

                elif $bb grep -q '/sdcard' /proc/mounts || $bb mount /sdcard; then
                    export CONFIG_DIR_STORAGE=/sdcard
                fi

                if $bb test -z "$CONFIG_DIR_STORAGE"; then
                    echo "It was not possible to mount the parimary storage!"

                else
                    STORAGE_MOUNTED=true

                    if $bb test ! -d "$CONFIG_DIR_STORAGE/Injector"; then
                        $bb mkdir -p "$CONFIG_DIR_STORAGE/Injector" 2> /dev/null || $bb mkdir "$CONFIG_DIR_STORAGE/Injector";
                    fi

                    storedImageFile="$CONFIG_DIR_STORAGE/Injector/boot.img"
                fi

                break
            fi
        done

        ##
        # Extract the boot.img from the device
        ##
        if $ACTION_USE_STORED; then
            echo "Extracting the boot.img from $storedImageFile into $CONFIG_FILE_BOOTIMG"

            if $bb test -z "$storedImageFile" || $bb test ! -f "$storedImageFile" || ! $bb cp -f "$storedImageFile" "$CONFIG_FILE_BOOTIMG"; then
                echo "It was not possible to extract the boot.img from the storage!"; break
            fi

        else
            echo "Extracting the device boot.img from $SETTINGS_DEVICE into $CONFIG_FILE_BOOTIMG"

            if $SETTINGS_ACTIONS_READ && ! $SETTINGS_SCRIPT "read"; then
                echo "It was not possible to extract the boot.img from the device!"; break

            elif ! $SETTINGS_ACTIONS_READ && ! dump_image "$SETTINGS_DEVICE" "$CONFIG_FILE_BOOTIMG" 2>/dev/null && ( $bb test ! -e /sbin/dump_image || ! /sbin/dump_image "$SETTINGS_DEVICE" "$CONFIG_FILE_BOOTIMG" ); then
                if $bb test "$SETTINGS_DEVICE" = "boot" || ! $bb dd if="$SETTINGS_DEVICE" of="$CONFIG_FILE_BOOTIMG"; then
                    echo "It was not possible to extract the boot.img from the device!"; break
                fi
            fi
        fi

        ##
        # Make sure that we are dealing with a valid boot.img
        ##
        echo "Validating the extracted boot.img file"

        if $SETTINGS_ACTIONS_VALIDATE && ! $SETTINGS_SCRIPT validate; then
            echo "The extracted image is not a valid boot.img!"; break

        elif ! $SETTINGS_ACTIONS_VALIDATE && ! abootimg -i $CONFIG_FILE_BOOTIMG > /dev/null; then
            echo "The extracted image is not a valid boot.img!"; break
        fi

        if $ACTION_INJECT; then
            ##
            # Disassemble the boot.img
            ##
            echo "Unpacking the boot.img"

            if $SETTINGS_ACTIONS_UNPACK && ! $SETTINGS_SCRIPT "unpack"; then
                echo "It was not possible to unpack the boot.img!"; break

            elif ! $SETTINGS_ACTIONS_UNPACK && ! ( cd $CONFIG_DIR_BOOTIMG && abootimg -x $CONFIG_FILE_BOOTIMG); then
                if ! unpack-bootimg -i $CONFIG_FILE_BOOTIMG -o $CONFIG_DIR_BOOTIMG -k $($bb basename $CONFIG_FILE_ZIMAGE) -r $($bb basename $CONFIG_FILE_INITRD) -s $($bb basename $CONFIG_FILE_STAGE2) > /dev/null; then
                    if ! unpack-bootimg -i $CONFIG_FILE_BOOTIMG -o $CONFIG_DIR_BOOTIMG -k $($bb basename $CONFIG_FILE_ZIMAGE) -r $($bb basename $CONFIG_FILE_INITRD) > /dev/null; then
                        echo "It was not possible to unpack the boot.img!"; break
                    fi
                fi
            fi

            # We need this if abootimg fails to update
            $bb test -z "$SETTINGS_CMDLINE" && export SETTINGS_CMDLINE="$(stat-bootimg $CONFIG_FILE_BOOTIMG | $bb grep 'CMDLINE' | $bb cut -d ' ' -f 2)"
            $bb test -z "$SETTINGS_BASE" && export SETTINGS_BASE="0x$(stat-bootimg $CONFIG_FILE_BOOTIMG | $bb grep 'BASE' | $bb cut -d ' ' -f 2)"
            $bb test -z "$SETTINGS_PAGESIZE" && export SETTINGS_PAGESIZE="$(stat-bootimg $CONFIG_FILE_BOOTIMG | $bb grep 'PAGE_SIZE' | $bb cut -d ' ' -f 2)"

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

            if $CONFIG_BUSYBOX test -n "`$bb find "$CONFIG_DIR_INITRD" -type f -name 'ramdisk.cpio'`"; then
                echo "Located an inner ramdisk.cpio within the ramdisk. Extracting it"

                export CONFIG_DIR_INITRD_BASE=$CONFIG_DIR_INITRD.base

                $bb mv $CONFIG_DIR_INITRD $CONFIG_DIR_INITRD_BASE
                $bb mkdir $CONFIG_DIR_INITRD

                export CONFIG_FILE_INITRD_BASE=$($bb find "$CONFIG_DIR_INITRD_BASE" -type f -name "ramdisk.cpio")

                if $bb test ! -f "$CONFIG_FILE_INITRD_BASE"; then
                    echo "Could not validate the inner ramdisk.cpio file!"; break
                fi

                if ! ( cd $CONFIG_DIR_INITRD && $bb cpio -i < "$CONFIG_FILE_INITRD_BASE" ); then
                    echo "It was not possible to disassemble the inner ramdisk.cpio!"; break
                fi
            fi

            if $bb test ! -e $CONFIG_DIR_INITRD/init || $bb test ! -e $CONFIG_DIR_INITRD/init.rc; then
                for lFile in `$bb find $CONFIG_DIR_INITRD -name 'init.rc'`; do
                    # Make sure that we don't have a recovery ramdisk directory
                    if ! $bb grep 'service' "$lFile" | $bb grep -q '/sbin/recovery'; then
                        export CONFIG_DIRS_INITRD="$CONFIG_DIRS_INITRD $($bb dirname $lFile)"
                    fi
                done

                if $bb test -z "$CONFIG_DIRS_INITRD"; then
                    echo "The disassembled ramdisk is corrupted!"; break
                fi

                echo "Located mutiple ramdisk versions within the ramdisk. Injecting them all"

            else
                export CONFIG_DIRS_INITRD=$CONFIG_DIR_INITRD
            fi

            ##
            # Execute all of the injector.d scripts
            ##
            echo "Running injector scripts"

            export CONFIG_DIR_INITRD_MAIN=$CONFIG_DIR_INITRD

            for lDirectory in $CONFIG_DIRS_INITRD; do
                echo "Injecting ramdisk located in $lDirectory"

                export CONFIG_DIR_INITRD=$lDirectory

                for lInjectorScript in `$bb find $CONFIG_DIR_SCRIPTS -name '*.sh' | $bb sort -n`; do
                    echo "Executing $($bb basename $lInjectorScript)"

                    if ! $lInjectorScript; then
                        echo "The injector.d script $($bb basename $lInjectorScript) failed to execute properly!"; break
                    fi
                done
            done

            export CONFIG_DIR_INITRD=$CONFIG_DIR_INITRD_MAIN

            ##
            # Re-assamble initrd.img
            ##
            echo "Re-assambling the initrd.img"

            if $bb test -n "$CONFIG_FILE_INITRD_BASE"; then
                echo "Re-assambling the inner ramdisk.cpio file"

                if ! mkbootfs $CONFIG_DIR_INITRD > $CONFIG_FILE_INITRD_BASE; then
                    if ! ( cd $CONFIG_DIR_INITRD && $bb find | $bb sort | $bb cpio -o -H newc > $CONFIG_FILE_INITRD_BASE ); then
                        echo "It was not possible to Re-assamble the inner ramdisk.cpio"; break
                    fi
                fi

                if ! $bb rm -rf $CONFIG_DIR_INITRD || ! $bb mv $CONFIG_DIR_INITRD_BASE $CONFIG_DIR_INITRD; then
                    echo "It was not possible to Re-assamble the inner ramdisk.cpio"; break
                fi
            fi

            if $SETTINGS_ACTIONS_ASSEMBLE && ! $SETTINGS_SCRIPT "assemble"; then
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

            if $SETTINGS_ACTIONS_PACK && ! $SETTINGS_SCRIPT "pack"; then
                echo "It was not possible to Re-pack the boot.img!"; break

            elif ! $SETTINGS_ACTIONS_PACK; then
                if $bb test ! -f "$CONFIG_FILE_CFG" || ! abootimg -u "$CONFIG_FILE_BOOTIMG" -r "$CONFIG_FILE_INITRD" -f "$CONFIG_FILE_CFG"; then
                    # Abootimg some times fails while updating, and it is not great at creating images from scratch
                    cmdMkBootimg="mkbootimg -o $CONFIG_FILE_BOOTIMG --kernel $CONFIG_FILE_ZIMAGE --ramdisk $CONFIG_FILE_INITRD $($bb test -n "$SETTINGS_BASE" && echo "--base $SETTINGS_BASE") $($bb test -n "$SETTINGS_CMDLINE" && echo "--cmdline \"$SETTINGS_CMDLINE\"") $($bb test -n "$SETTINGS_PAGESIZE" && echo "--pagesize $SETTINGS_PAGESIZE") $($bb test -n "$SETTINGS_OFFSET" && echo "--ramdisk_offset $SETTINGS_OFFSET") $($bb test -f $CONFIG_FILE_STAGE2 && echo "--second $CONFIG_FILE_STAGE2")"

                    if ! eval $cmdMkBootimg; then
                        echo "It was not possible to Re-pack the boot.img!"; break
                    fi
                fi
            fi

            echo "Validating the newly created boot.img"

            if $SETTINGS_ACTIONS_VALIDATE && ! $SETTINGS_SCRIPT "validate"; then
                echo "The new boot.img was corrupted during creation!"; break

            elif ! $SETTINGS_ACTIONS_VALIDATE && ! abootimg -i $CONFIG_FILE_BOOTIMG > /dev/null; then
                echo "The new boot.img was corrupted during creation!"; break
            fi
        fi

        ##
        # Re-writing boot.img
        ##
        if $ACTION_FLASH; then
            echo "Writing the new boot.img to the device"

            if $SETTINGS_ACTIONS_WRITE; then
                if ! $SETTINGS_SCRIPT "write"; then
                    echo "It was not possible to write the boot.img to the device!"

                    if $bb cp $CONFIG_FILE_BOOTIMG $storedImageFile; then
                        echo "The boot.img was moved to $storedImageFile. Use 'fastboot flash boot boot.img' to flash it to your boot partition"
                        echo "exit.message=The boot.img was moved to $storedImageFile. Use 'fastboot flash boot boot.img' to flash it to your boot partition" >> /tmp/injector.prop
                    fi

                    break;
                fi

            else
                if ( ! erase_image $SETTINGS_DEVICE 2>/dev/null && ( $bb test ! -e /sbin/erase_image || ! /sbin/erase_image $SETTINGS_DEVICE ) ) || ( ! flash_image $SETTINGS_DEVICE $CONFIG_FILE_BOOTIMG 2>/dev/null && ( $bb test ! -e /sbin/flash_image || ! /sbin/flash_image $SETTINGS_DEVICE $CONFIG_FILE_BOOTIMG ) ); then
                    if $bb test "$SETTINGS_DEVICE" = "boot" || ! $bb dd if=$CONFIG_FILE_BOOTIMG of=$SETTINGS_DEVICE; then
                        echo "It was not possible to write the boot.img to the device!"

                        if $bb cp $CONFIG_FILE_BOOTIMG $storedImageFile; then
                            echo "The boot.img was moved to $storedImageFile. Use 'fastboot flash boot boot.img' to flash it to your boot partition"
                            echo "exit.message=The boot.img was moved to $storedImageFile. Use 'fastboot flash boot boot.img' to flash it to your boot partition" >> /tmp/injector.prop
                        fi

                        break;
                    fi
                fi
            fi

        else
            echo "Moving the boot.img to the primary storage"

            if ! $bb cp "$CONFIG_FILE_BOOTIMG" "$storedImageFile"; then
                echo "It was not possible to move the boot.img to the primary storage!"; break

            else
                echo "The boot.img was moved to $storedImageFile" 
                echo "exit.message=The boot.img was moved to $storedImageFile" >> /tmp/injector.prop
            fi
        fi

        RESULT=0

        break
    done

    if $bb test -n "$CONFIG_DIR_STORAGE"; then
        echo "Moving log file to $CONFIG_DIR_STORAGE/Injector/injector.log"
        $bb cp $LOG $CONFIG_DIR_STORAGE/Injector/
    fi

    echo "Cleaning up old files and directories"

    # For some reason, the boot.img needs some time before it can be deleted
    $bb sleep 1

    # Make sure that we are not within the directory that is about to be deleted
    cd /

    $bb rm -rf $CONFIG_DIR_BOOTIMG
    $bb rm -rf $CONFIG_FILE_BOOTIMG

    break
done

echo "exit.status=$RESULT" >> /tmp/injector.prop && exit $RESULT
