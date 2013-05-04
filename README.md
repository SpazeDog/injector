Injector
========

An Android Ramdisk Injector

About
------
The one problem with Android when it comes to customization, is the Ramdisk. You are not able to edit anything while the device is booted, and each device differs in many ways which makes it difficult to create an updater script to do the work without targering a specific device. 

Injector is a recovery script that enables you to modify the ramdisk on multiple devices, without having to worry about creating device specific code. The injector will extract the ramdisk for you, and it will write it back to the boot partition once you are done. All you have to do, is create any script that does whatever work you need it to do, place it in the injector.d folder, compress the updater archive and upload. 

Supported Devices
------

* QSD8K
    * HTC Desire GSM (Tested)
    * HTC Desire CDMA
    * HTC Nexus One

* Marvel
    * HTC Wildfire S

* Spade
    * HTC Desire HD

* endeavoru
    * HTC One X

* Aries
    * Samsung Galaxy S I9000
    * Samsung Galaxy S I9000B
    * Samsung Galaxy S Captivate
    * Samsung Galaxy S Vibrant
    * Samsung Galaxy S Fascinate

* smdk4210
    * Samsung Galaxy S II I9100
    * Samsung Galaxy S II I777

* SMDK4x12
    * Samsung Galaxy S III I9300 (Tested)
    * Samsung Galaxy S III Sprint

* SMDK4412
    * Samsung Galaxy S III I9305

* Golden
    * Samsung Galaxy S III Mini I8190

* JF
    * Samsung Galaxy S 4 I9505

* JFLTE
    * Samsung Galaxy S 4 I9505 LTE

* Totoro
    * Samsung Galaxy Y S5360

Example
------
Let's create a simple package that removes init.cm.rc

```bash
#!/sbin/sh

# Path to the busybox binary in usage
BB=$1

# The path to the extracted ramdisk
RAMDISK=$2

# The tools directory. In case your script needs any additional files, this is where to place them
TOOLS=$3

$BB rm -rf $RAMDISK/init.cm.rc

exit 0
```

Now place this script in the injector.d directory, for an example injector.d/05-myscript.sh

Now all you have to do is pack it all to a ZIP file and upload for anyone to use. This new package will work on any device listed in the supported section above.

Support Configurations
------
In the devices/ directory are all the configurations which adds support for various devices. In order to add support for a new device, create a file &lt;platform&gt;.conf, &lt;board&gt;.conf, &lt;device&gt;.conf or &lt;model&gt;.conf. 

```bash
# Path to the block or character device which can read and write to the boot partition
# Note: Not needed if you apply a script
device = /dev/block/mmcblk0p5

# The boot page size
pagesize = 2048

# The boot base
base = 0x12c00000

# The boot cmdline
cmdline = no_console_suspend=1 console=null

# The name of a device script which will handle the boot read and write
script = mtd
```
Below is an example of the script mtd.sh, applied in the configs above. A script is only needed in cases where a simple 'dd if= of=' is not enough, otherwise you can leave out the script and let Injector handle it.

```bash
#!/sbin/sh

bb=$1
iAction=$2
iBootimg=$3
iDevice=$(grep boot /proc/mtd | sed 's/^\(.*\):.*/\1/')

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
