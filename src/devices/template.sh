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

iAction=$1
iBootimg=$2

case "$iAction" in 
    read)
        ## Copy the boot partition into the boot.img file
        # dd if=/dev/<boot device> of=$iBootimg

        exit 0
    ;;

    write)
        ## Copy the new boot.img into the boot partition
        # dd if=$iBootimg of=/dev/<boot device>

        exit 0
    ;;
esac

exit 1
