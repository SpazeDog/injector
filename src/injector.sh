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

cSelf=$(readlink -f $(dirname $0))
cLog=/tmp/injector.log
cBootimg=/tmp/boot.img
cBootDir=/tmp/boot_img

sCode=0

cd $cSelf

echo "Starting the Injector" > $cLog

iModel=$(grep -e "^ro.product.model=" /default.prop | sed 's/^.*=\(.*\)$/\1/' | tr '[A-Z]' '[a-z]' | sed 's/ /_/')
iBoard=$(grep -e "^ro.product.board=" /default.prop | sed 's/^.*=\(.*\)$/\1/' | tr '[A-Z]' '[a-z]' | sed 's/ /_/')
iDevice=$(grep -e "^ro.product.device=" /default.prop | sed 's/^.*=\(.*\)$/\1/' | tr '[A-Z]' '[a-z]' | sed 's/ /_/')
iPlatform=$(grep -e "^ro.board.platform=" /default.prop | sed 's/^.*=\(.*\)$/\1/' | tr '[A-Z]' '[a-z]' | sed 's/ /_/')

echo "Found device information: Model($iModel), Board($iBoard), Device($iDevice), Platform($iPlatform)" >> $cLog

for i in $iPlatform $iBoard $iModel $iDevice; do
    if [ -f devices/${i}.conf ]; then
        iConfig=devices/${i}.conf
        iScript=

    elif [ -f devices/${i}.sh ] then
        iConfig=
        iScript=devices/${i}.sh
    fi
done

if [ ! -z "$iConfig" ]; then
    iBlockDevice=$(grep -e "^[ \t]*device[ \t]*=" $iConfig | sed 's/^.*=\(.*\)$/\1/')
    iBs=$(grep -e "^[ \t]*bs[ \t]*=" $iConfig | sed 's/^.*=\(.*\)$/\1/')

    if [ -z "$iBs" ]; then
        iBs=4096
    fi
fi

if [[ ! -z "$iScript" || ! -z "$iBlockDevice" ]]; then

    echo "Using the device script $(test ! -z "$iConfig" && echo "$iConfig" || basename $iScript)" >> $cLog
    echo "Extracting the device boot.img" >> $cLog

    if ( test ! -z "$iConfig" && dd if=$iBlockDevice of=$iBootimg bs=$iBs ) || ( test ! -z "$iScript" && chmod 0775 $iScript && $iScript read $cBootimg ); then
        echo "Extracting the ramdisk from the boot.img" >> $cLog

        if mkdir $cBootDir && ( cd $cBootDir && $cSelf/abootimg -x $cBootimg && mkdir initrd && zcat initrd.img | ( cd initrd && cpio -i ) ); then
            echo "Running injector scripts" >> $cLog

            chmod 0755 injector.d/*

            for lInjectorScript in $(find injector.d -name '*.sh' | sort -n); do
                if ! $lInjectorScript $cBootDir/initrd; then
                    echo "The injector script $(basename $lInjectorScript) failed to execute!" >> $cLog; sCode=1
                fi
            done

            echo "Re-assembling the ramdisk" >> $cLog

            if ( cd $cBootDir && ( cd initrd && find | sort | cpio -o -H newc ) | gzip > initrd.img && $cSelf/abootimg -u $cBootimg -r initrd.img -f bootimg.cfg ); then
                echo "Writing new boot.img to the device" >> $cLog

                if ( test ! -z "$iConfig" && dd if=$iBootimg of=$iBlockDevice bs=$iBs ) || ( test ! -z "$iScript" && $iScript write $cBootimg ); then
                    echo "The boot.img has been successfully updated" >> $cLog

                else
                    echo "Could not write the new boot.img!" >> $cLog; sCode=1
                fi

            else
                echo "Could not re-assamlbe the ramdisk!" >> $cLog; sCode=1
            fi

        else
            echo "Could not extract the ramdisk!" >> $cLog; sCode=1
        fi

    else
        echo "Could not extract the boot.img!" >> $cLog; sCode=1
    fi

else
    echo "Could not locate any device scripts/configs for this specific board or model!" >> $cLog; sCode=1
fi

echo "Cleaning up" >> $cLog

rm -rf $cBootDir

(
    # For some reason, the boot.img needs some time before it can be deleted. And it might hang while trying, so do this in a subprocess
    sleep 3

    unlink $cBootimg
) & 

echo "exit.status=$sCode" > /tmp/injector.prop

exit $sCode
