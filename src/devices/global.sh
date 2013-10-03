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

case "$1" in 
    device)
        # BML devices has the /proc/mtd file, but not the /dev/mtd directory. Non-MTD/BML devices has none if them
        if $CONFIG_BUSYBOX test ! -e /proc/mtd || $CONFIG_BUSYBOX test ! -e /dev/mtd; then
            for i in /tmp/recovery.fstab /recovery.fstab /etc/recovery.fstab; do
                if $CONFIG_BUSYBOX test -e $i; then
                    echo $($CONFIG_BUSYBOX grep '/boot' $i | $CONFIG_BUSYBOX awk '{print $3}') && return 0
                fi
            done

            if $CONFIG_BUSYBOX test -e /dev/block/bml7; then
                bmlunlock
            fi
        fi

        echo boot && return 0
    ;;
esac

exit 1
