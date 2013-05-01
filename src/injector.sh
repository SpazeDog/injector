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

bb=busybox

cDirectory=$($bb readlink -f $($bb dirname $0))
cExitCode=1
cLog=/tmp/injector.log
cImgBoot=/tmp/boot.img
cDirectoryBoot=/tmp/boot_img
cDirectoryInitrd=$cDirectoryBoot/initrd
cDirectoryTools=$cDirectory/tools
cDirectoryDevices=$cDirectory/devices
cDirectoryInjectors=$cDirectory/injector.d
cFileBootZImage=$cDirectoryBoot/zImage
cFileBootInitrd=$cDirectoryBoot/initrd.img
cFileBootSecond=$cDirectoryBoot/stage2.img
cFileBootCfg=$cDirectoryBoot/bootimg.cfg

echo "Starting Injection" > $cLog
exec >> $cLog 2>&1 

iModel=$($bb grep -e "^ro.product.model=" /default.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/')
iBoard=$($bb grep -e "^ro.product.board=" /default.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/')
iDevice=$($bb grep -e "^ro.product.device=" /default.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/')
iPlatform=$($bb grep -e "^ro.board.platform=" /default.prop | $bb sed 's/^.*=\(.*\)$/\1/' | $bb tr '[A-Z]' '[a-z]' | $bb sed 's/ /_/')

for i in $iPlatform $iBoard $iModel $iDevice; do
    if $bb [ -f $cDirectoryDevices/${i}.conf ]; then
        iConfigFile=$cDirectoryDevices/${i}.conf
    fi
done

if $bb [ ! -z "$iConfigFile" ]; then
    while read tLine; do
        if $bb test ! -z "$tLine" && ! echo "$tLine" | $bb grep -q "#"; then
            lLineName=$(echo "$tLine" | $bb sed 's/^\([^=]*\)=.*$/\1/' | $bb sed 's/^[ \t]*//' | $bb sed 's/[ \t]*$//')
            lLineContent="`echo "$tLine" | $bb sed 's/^[^=]*=\(.*\)$/\1/' | $bb sed 's/^[ \t]*//' | $bb sed 's/[ \t]*$//'`"

            eval export "c_$lLineName=\"$lLineContent\""
        fi

    done < $iConfigFile

    echo "Using $($bb basename $iConfigFile): device($c_device), bs($c_bs), base($c_base), cmdline($c_cmdline), script($c_script)"

    if $bb [ ! -z "$c_script" ]; then
        $bb test -f $cDirectoryDevices/${c_script} && c_script=$cDirectoryDevices/${c_script} || c_script=$cDirectoryDevices/${c_script}.sh
    fi
fi

if $bb [[ ! -z "$c_script" && -f $c_script ]] || $bb [[ ! -z "$c_device" && -e $c_device ]]; then
    $bb mkdir -p $cDirectoryBoot || $bb mkdir $cDirectoryBoot
    $bb mkdir -p $cDirectoryInitrd || $bb mkdir $cDirectoryInitrd

    $bb chmod 0775 $cDirectoryTools/bin/*
    $bb chmod 0775 $cDirectoryDevices/*.sh
    $bb chmod 0775 $cDirectoryInjectors/*.sh

    export PATH=$cDirectoryTools/bin:$PATH

    echo "Extracting the device boot.img"

    if $bb [ ! -z "$c_script" ]; then
        $c_script $bb read $cImgBoot $cDirectoryTools; bStatus=$($bb test $? -eq 0)

    else
        $bb test ! -z "$c_bs" && $bb dd if=$c_device of=$cImgBoot bs=$c_bs || $bb dd if=$c_device of=$cImgBoot
    fi

    if $bStatus && $bb [ -f $cImgBoot ]; then
        bUseAbootimg=false

        echo "Extracting the ramdisk from the boot.img"

        if ( cd $cDirectoryBoot && abootimg -x $cImgBoot); then
            lBootSumOld=$($bb test "`$bb md5sum $cImgBoot | $bb awk '{print $1}'`" = "``")
            abootimg -u $cImgBoot -r $cFileBootInitrd -f $cFileBootCfg
            lBootSumNew=$($bb test "`$bb md5sum $cImgBoot | $bb awk '{print $1}'`" = "``")

            $bb test "$lBootSumOld" = "$lBootSumNew" && bUseAbootimg=true

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

            unpack-bootimg -i $cImgBoot -o $cDirectoryBoot -k $($bb basename $cFileBootZImage) -r $($bb basename $cFileBootInitrd) -s $($bb basename $cFileBootSecond)
        fi

        if $bb [[ -f $cFileBootZImage && -f $cFileBootInitrd ]] && $bb zcat $cFileBootInitrd | ( cd $cDirectoryInitrd && $bb cpio -i ); then
            
            echo "Running injector.d scripts"

            for lInjectorScript in `$bb find $cDirectoryInjectors -name '*.sh' | sort -n`; do
                $lInjectorScript $bb $cDirectoryInitrd $cDirectoryTools; bStatus=$($bb test $? -eq 0)

                if ! bStatus; then
                    break
                fi
            done

            if ! bStatus; then

                echo "Re-assambling the ramdisk"

                if ( cd $cDirectoryInitrd && $bb find | $bb sort | $bb cpio -o -H newc ) | $bb gzip > initrd.img; then

                    echo "Re-assambling the boot.img"

                    if ! $bUseAbootimg || ! abootimg -u $cImgBoot -r $cFileBootInitrd -f $cFileBootCfg; then
                        mkbootimg -o $cImgBoot --kernel $cFileBootZImage --ramdisk $cFileBootInitrd $($bb test ! -z "$c_base" && echo "--base") $c_base $($bb test ! -z "$c_cmdline" && echo "--cmdline") "$c_cmdline" $($bb test -f $cFileBootSecond && echo "--second") $($bb test -f $cFileBootSecond && echo $cFileBootSecond)
                    fi

                    if $bb [ $? -eq 0 ]; then

                        echo "Writing the new boot.img to the device"

                        if $bb [ ! -z "$c_script" ]; then
                            $c_script $bb write $cImgBoot $cDirectoryTools

                        else
                            $bb dd if=$cImgBoot of=$c_device $($bb test ! -z "$c_bs" && echo "bs=$c_bs")
                        fi

                        if $bb [ $? -eq 0 ]; then
                            cExitCode=0

                        else
                            echo "Failed while writing the new boot.img to the device!"
                        fi

                    else
                        echo "Failed while trying to re-assamble the boot.img!"
                    fi

                else
                    echo "Failed while trying to re-assamble the ramdisk!"
                fi

            else
                echo "The injector.d script $($bb basename $lInjectorScript) failed to execute properly!"
            fi

        else
            echo "Failed while extracting the ramdisk from the boot.img!"
        fi

    else
        echo "Failed while trying to extract the boot.img from the device!"
    fi

else
    echo "Missing script or block device!"
fi

echo "Cleaning up old files and directories"

$bb rm -rf $cDirectoryBoot

(
    # For some reason, the boot.img needs some time before it can be deleted. And it might hang while trying, so do this in a subprocess
    $bb sleep 3

    $bb rm -rf $cImgBoot
) & 

echo "exit.status=$cExitCode" > /tmp/injector.prop

exit $cExitCode
