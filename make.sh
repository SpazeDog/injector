#!/bin/bash

OUTPUT="$1"
TYPE=$(test -n "$2" && echo "$2" || echo "aroma")

case "$TYPE" in
    aroma)
        FOLDER=META-INF_Aroma
    ;;

    legacy)
        FOLDER=META-INF_Legacy
    ;;

    *)
        echo "Usage: ./make.sh <output file> <aroma/legacy>"; exit 1
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

mv $FOLDER META-INF

if [ "$TYPE" = "aroma" ]; then
    ( cd src && zip -9 -r ../src.zip . )
    zip -9 -r $OUTPUT META-INF src.zip busybox
    rm -rf src.zip

else
    zip -9 -r $OUTPUT META-INF src busybox
fi

mv META-INF $FOLDER

echo "Created $OUTPUT"
