Injector
========

An Android Ramdisk Injector

About
------ 
The one problem with Android when it comes to customization, is the Ramdisk. You are not able to edit anything while the device is booted, and each device differs in many ways which makes it difficult to create an updater script to do the work without targering a specific device. 

Injector is a recovery script that enables you to modify the ramdisk on multiple devices, without having to worry about creating device specific code. The injector will extract the ramdisk for you, and it will write it back to the boot partition once you are done. All you have to do, is create any script that does whatever work you need it to do, place it in the injector.d folder, compress the updater archive and upload. 

Creating recovery package
------
If you are creating a legacy package, rename `META-INF_Legacy` to `META-INF` and create a ZIP containing `META-INF/`, `src/` and `busybox`. To create an Aroma package, you need to rename `META-INF_Aroma` to `META-INF`, compress `src/` into a zip and then create a ZIP containing `META-INF/`, `src.zip` and `busybox`.

If you are using a *nix operating system, you can just use the `make.sh` file to create your packages. Just execute `./make.sh <package name> <legacy or aroma>`

Supported Devices
------

* Legend
    * HTC Legend `Tested`

* QSD8K
    * HTC Desire GSM `Tested`
    * HTC Desire CDMA `Tested`
    * HTC Nexus One `Tested`

* Marvel
    * HTC Wildfire S `Tested`

* Chacha
    * HTC Chacha `Tested`

* Spade
    * HTC Desire HD

* PrimoU
    * HTC One V

* Ville
    * HTC One S

* Endeavoru
    * HTC One X

* Evita
    * HTC One XL

* Enrc2b
    * HTC One X+

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
    * Samsung Galaxy S III I9300 `Tested`
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
    * Samsung Galaxy Y S5360 `Tested`

* Mogami
    * Sony Ericsson Experia Mini
    * Sony Ericsson Experia Mini Pro

* 7x27
    * Cherry Mobile Flame 2.0

* EMMC
    * Most EMMC devies besides the once on the list

* MTD
    * Most MTD devies besides the once on the list

* BML
    * Most BML devies besides the once on the list

Example
------
Let's create a simple package that removes init.cm.rc

```bash
#!/sbin/sh

# Remove init.cm.rc from the ramdisk
$CONFIG_BUSYBOX rm -rf $CONFIG_DIR_INITRD/init.cm.rc

exit 0
```

Now place this script in the `injector.d` directory, for an example `injector.d/05-myscript.sh`

Now all you have to do is pack it all to a ZIP file and upload for anyone to use. This new package will work on any device listed in the supported section above.

Support Configurations
------
In the `devices/` directory are all the configurations which adds support for various devices. In order to add support for a new device, create a file `<platform>.conf`, `<board>.conf`, `<device>.conf` or `<model>.conf`. 

```bash
# Path to the block or character device which can read and write to the boot partition
# Note: Not needed if you apply a script
# Note 2: On devices like MTD, you can just use the keyword 'boot'
device = /dev/block/mmcblk0p5

# The boot page size
pagesize = 2048

# The boot base
base = 0x12c00000

# The boot cmdline
cmdline = no_console_suspend=1 console=null

# The name of a device script which will handle the boot read and write along with other actions
script = mtd

# Which actions will be using the script instead of the builtin method
# - read = The custom script will handle the extraction of the boot.img from the device
# - write = The custom script will write the new boot.img back to the device
# - pack = The custom script will re-pack the new boot.img
# - unpack = The custom script will unpack the old boot.img
# - assemble = The custom script will assemble the new initrd.img
# - disassemble = The custom script will disassemble the old initrd.img
# - validate = The custom script will validate the boot.img after extraction and again after it has been altered and repacked
# Just leave out any action which should not be performed by the custom script. The injector will handle it instead.
actions = read write pack unpack assemble disassemble validate

# Use this on devices like some HTC devices which cannot write to boot via recovery
locked = true
```
Below is an example of the script mtd.sh, applied in the configs above. A script is only needed in cases where a simple `dd if= of=` is not enough, otherwise you can leave out the script and let Injector handle it.

```bash
#!/sbin/sh

iDevice=$($CONFIG_BUSYBOX grep boot /proc/mtd | sed 's/^\(.*\):.*/\1/')

case "$1" in 
    read)
        if $CONFIG_BUSYBOX dd if=/dev/mtd/$iDevice of=$CONFIG_FILE_BOOTIMG bs=4096; then
            exit 0
        fi
    ;;

    write)
        if test -f $CONFIG_FILE_BOOTIMG && $CONFIG_BUSYBOX dd if=$iBootimg of=/dev/mtd/$iDevice bs=4096; then
            exit 0
        fi
    ;;

    unpack)
        if unpack-bootimg -i $CONFIG_FILE_BOOTIMG -o $CONFIG_DIR_BOOTIMG -k $($CONFIG_BUSYBOX basename $CONFIG_FILE_ZIMAGE) -r $($CONFIG_BUSYBOX basename $CONFIG_FILE_INITRD) -s $($CONFIG_BUSYBOX basename $CONFIG_FILE_STAGE2); then
            exit 0
        fi
    ;;

    pack)
        if mkbootimg -o $CONFIG_FILE_BOOTIMG --kernel $CONFIG_FILE_ZIMAGE --ramdisk $CONFIG_FILE_INITRD --base $SETTINGS_BASE --cmdline "$SETTINGS_CMDLINE" --pagesize $SETTINGS_PAGESIZE; then
            exit 0
        fi
    ;;

    disassemble)
        if $CONFIG_BUSYBOX zcat $CONFIG_FILE_INITRD | ( cd $CONFIG_DIR_INITRD && $CONFIG_BUSYBOX cpio -i ); then
            exit 0
        fi
    ;;

    assemble)
        if ( cd $CONFIG_DIR_INITRD && $CONFIG_BUSYBOX find | $CONFIG_BUSYBOX sort | $CONFIG_BUSYBOX cpio -o -H newc ) | $CONFIG_BUSYBOX gzip > $CONFIG_FILE_INITRD; then
            exit 0
        fi
    ;;

    validate)
        if abootimg -i $CONFIG_FILE_BOOTIMG; then
            return 0
        fi
    ;;
esac

exit 1
```

Global Variables
------
Both device scripts and injector.d scripts has access to a bunch of global variables which is created by injector opon launch. `CONFIG_` variables contains injector configurations and `SETTINGS_` variables contains everything defined in the device config file.

```bash
# Path to a working busybox binary
$CONFIG_BUSYBOX

# Complete path to the Injector root directory
$CONFIG_DIR_INJECTOR

# Path to the boot.img
$CONFIG_FILE_BOOTIMG

# Path to the directory containing the unpacked boot.img
$CONFIG_DIR_BOOTIMG

# Path to the directory containing the unpacked initrd
$CONFIG_DIR_INITRD

# Path to the initrd.img
$CONFIG_FILE_INITRD

# Path to the kernel/zimage
$CONFIG_FILE_ZIMAGE

# Path to the second stage image
$CONFIG_FILE_STAGE2

# Path to the abootimg configuration file
$CONFIG_FILE_CFG

# Path to the injector tools directory ($CONFIG_DIR_TOOLS/bin is added to $PATH)
$CONFIG_DIR_TOOLS

# Path to the injector device configuration files directory
$CONFIG_DIR_DEVICES

# Path to the injector.d scripts directory
$CONFIG_DIR_SCRIPTS

# The device model name (From /default.prop)
$CONFIG_DEVICE_MODEL

# The device board name (From /default.prop)
$CONFIG_DEVICE_BOARD

# The device name (From /default.prop)
$CONFIG_DEVICE_NAME

# The device platform (From /default.prop)
$CONFIG_DEVICE_PLATFORM

# One for each index of the device configuration file is created.
# Each index name should be in upper case. 
# Example: $SETTINGS_CMDLINE or $SETTINGS_DEVICE
$SETTINGS_<NAME>

# Note that $SETTINGS_ACTIONS will auto generate one true variable per each action defined.
# If you add "actions = read write" to the config file, then $SETTINGS_ACTIONS_READ and $SETTINGS_ACTIONS_WRITE will be set to "true". 
# Default value for each $SETTINGS_ACTIONS_<ACTION> is "false". 
# Also, these cannot be set directly from the config file. "actions_read = true" will not work.
$SETTINGS_ACTIONS_READ
$SETTINGS_ACTIONS_WRITE
$SETTINGS_ACTIONS_DISASSEMBLE
$SETTINGS_ACTIONS_ASSEMBLE
$SETTINGS_ACTIONS_PACK
$SETTINGS_ACTIONS_UNPACK
$SETTINGS_ACTIONS_VALIDATE
```
