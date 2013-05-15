#!/bin/bash

OUTPUT="$1"
MODULE=$(test -n "$2" && echo "$2" || echo "template")
TYPE=$(test -n "$3" && echo "$3" || echo "aroma")

if [ ! -d modules/$MODULE ]; then
    echo "The module $MODULE does not exist!"; exit 1
fi

case "$TYPE" in
    aroma)
        FOLDER=META-INF_Aroma
    ;;

    legacy)
        FOLDER=META-INF_Legacy
    ;;

    *)
        echo "Usage: ./make.sh <output file> <module> <aroma/legacy>"; exit 1
    ;;
esac

if [ -z "$OUTPUT" ]; then
    OUTPUT="$(basename "`readlink -f "$(dirname $0)" | sed 's/ /_/'`").zip"

elif ! echo "$OUTPUT" | grep -q -e "\.zip$"; then
    OUTPUT="$OUTPUT.zip"
fi

if [ -f "$OUTPUT" ]; then
    echo -n "Override existing file? [y/n]: "; read INPUT

    if [ "`echo "$INPUT" | tr '[A-Z]' '[a-z]'`" = "y" ]; then
        rm -rf "$OUTPUT"

    else 
        exit 1
    fi

elif [ -e "$OUTPUT" ]; then
    echo "Can't override $OUTPUT"; exit 1
fi

tFolder=".$(basename "$OUTPUT" | sed 's/ /_/')"
OUTPUT=$(readlink -f "$OUTPUT")

mkdir $tFolder
cp -a $FOLDER $tFolder/META-INF
cp -a src $tFolder/src
cp -a modules/$MODULE/* $tFolder/src/injector.d/
cp busybox $tFolder/busybox

if [ "$TYPE" = "aroma" ]; then
    ( cd $tFolder/src && zip -9 -r ../src.zip . )
    ( cd $tFolder && zip -9 -r "$OUTPUT" META-INF src.zip busybox )

else
    ( cd $tFolder && zip -9 -r "$OUTPUT" META-INF src busybox )
fi

rm -rf $tFolder

echo "Created $OUTPUT"
