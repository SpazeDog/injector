#!/sbin/sh
#
# bml_over_mtd.sh
# Take care of bad blocks while flashing kernel image to boot partition
#

cd $(basename $0)

PARTITION=$1
PARTITION_START_BLOCK=$2
RESERVOIRPARTITION=$3
RESERVOIR_START_BLOCK=$4
IMAGE=$5

set -x
export PATH=/:/sbin:/system/xbin:/system/bin:$PATH

# scan boot partition for bad blocks
./bml_over_mtd scan $PARTITION; status=$?
 
# if exit status is 15 use bml_over_mtd, otherwise use flash_image
if test $status -eq 15
then
	./bml_over_mtd flash $PARTITION $PARTITION_START_BLOCK $RESERVOIRPARTITION $RESERVOIR_START_BLOCK $IMAGE; status=$?
else
	./flash_image $PARTITION $IMAGE || ( test -e /sbin/flash_image && /sbin/flash_image $PARTITION $IMAGE ); status=$?
fi

exit $status
