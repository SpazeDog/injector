Injector
========

An Android Ramdisk Injector

About
------
The one problem with Android when it comes to customization, is the Ramdisk. You are not able to edit anything while the device is booted, and each device differs in many ways which makes it difficult to create a simple updater script to do the work. 

SpazeDog Injector is a recovery script which enables you to edit the ramdisk on multiple devices, without having to code any device specific code. By using separate device configs to extract and write the boot.img, it is easy to add new devices to the support tree, without having to rewrite any existing files. 

Supported Devices
------

* QSD8K
    * HTC Desire GSM
    * HTC Desire CDMA
    * HTC Nexus One

* Marvel
    * HTC Wildfire S

* Aries (Untested)
    * Samsung Galaxy S I9000
    * Samsung Galaxy S I9000B
    * Samsung Galaxy S Captivate
    * Samsung Galaxy S Vibrant
    * Samsung Galaxy S Fascinate

* smdk4210 (Untested)
    * Samsung Galaxy S II I9100
    * Samsung Galaxy S II I777

* SMDK4x12 (Untested)
    * Samsung Galaxy S III I9300
    * Samsung Galaxy S III Sprint

* SMDK4412 (Untested)
    * Samsung Galaxy S III I9305

Usage
------
The injector will do all the work of extracting the boot.img and the ramdisk, re-assemble and write the new edited version. All you have to do, is create a script to do the kind of editing that you would like.

```bash
#!/sbin/sh
# injector.d/09-myscript.sh

# The path to the extracted ramdisk
RAMDISK=$1

rm -rf init.cm.rc

exit 0
```

Once this script has been executed by the injector, a new boot.img has been written which does not include init.cm.rc

Adding device support
------
Each device has it's own way of writing/storing the boot.img. Because of this, injector uses config scripts to read/write from/to the boot partition. These files is placed in devices/ and are named as the device it adds support for. The names are extracted from the build.prop. You can name your device config using the board name, device name, platform or model. 

```bash
#!/sbin/sh
# devices/qsd8k.sh

iAction=$1
iBootimg=$2
iDevice=$(grep boot /proc/mtd | sed 's/^\(.*\):.*/\1/')

if [ -z "$iDevice" || ! -e /dev/mtd/$iDevice ]; then
    iDevice=mtd2
fi

case "$iAction" in 
    read)
        if dd if=/dev/mtd/$iDevice of=$iBootimg bs=4096; then
            exit 0
        fi
    ;;

    write)
        if test -f $iBootimg && dd if=$iBootimg of=/dev/mtd/$iDevice bs=4096; then
            exit 0
        fi
    ;;
esac

exit 1
```

This will be used by any device using the QSD8K platform. We could also add another config file named bravo.sh which would only be used by QSD8K devices using the bravo board. 
