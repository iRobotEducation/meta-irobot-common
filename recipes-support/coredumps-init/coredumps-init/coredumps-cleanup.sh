#!/bin/sh
SCRIPT_NAME=$(basename ${0})
data_dir="/data/logs/"
DEV_MODE=$(provision | grep "DEVELOPMENT MODE" | awk '{print $3}')

if [ "$DEV_MODE" == "enabled" ]; then
    logger -t $SCRIPT_NAME "Skipping check for old core files in devmode."
else
    logger -t $SCRIPT_NAME "Checking for old core files to cleanup."

    # find all core files older than 3 days
    FILES_TO_BE_DELETED=$(find $data_dir -name "core*" -mtime +2)

    if [ ! -z "$FILES_TO_BE_DELETED" ]; then
        echo ${FILES_TO_BE_DELETED} | xargs logger -t $SCRIPT_NAME "Core file(s) to be deleted:" 
        echo ${FILES_TO_BE_DELETED} | xargs -r rm
    fi
fi
