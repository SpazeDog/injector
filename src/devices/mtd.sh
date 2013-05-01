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

$bb=$1
iAction=$2
iBootimg=$3
iDevice=$($bb grep boot /proc/mtd | $bb sed 's/^\(.*\):.*/\1/')

if $bb [[ -z "$iDevice" || ! -e /dev/mtd/$iDevice ]]; then
    iDevice=mtd2
fi

if $bb [[ ! -c /dev/mtd/$iDevice && ! -b /dev/mtd/$iDevice ]]; then
    echo "Failed! /dev/mtd/$iDevice is not a device path"; exit 1
fi

case "$iAction" in 
    read)
        if $bb dd if=/dev/mtd/$iDevice of=$iBootimg bs=4096; then
            $bb cp $iBootimg ${iBootimg}.old

            exit 0
        fi
    ;;

    write)
        if $bb test -f $iBootimg && $bb dd if=$iBootimg of=/dev/mtd/$iDevice bs=4096; then
            exit 0
        fi
    ;;
esac

exit 1
