#!/bin/sh
# The total size of core.* files should be less than core_limit.
core_limit=28

# The total usage of /data partition should not greater then 70%
limit=70

scriptname=$(basename ${0})
data_dir="/data/logs/"

# usage
usage() {
    echo "usage: $scriptname [OPTIONS]"
    echo " -l,--limit <integer>           - Limit of allocation for core files (in MiB)"
    echo " -h,--help                      - this help message"
    exit 1
}

filename="$1"
file_dir=$(dirname $filename)

core_file_space_used ()
{
    # search file_dir and get a list of core files sizes (in bytes)
    core_size_list=$(find $data_dir -name "core*" | xargs ls -l | awk '{print $5}')

    local core_space_used=0
    for core_size in $core_size_list; do
        core_space_used=$((core_space_used + $core_size))
    done

    # convert bytes to MiB
    echo $((core_space_used >> 20))
}

while [ "$1" ]; do
    case "$1" in
        -l|--limit) core_limit=$2; shift;;
        -h|--help)  usage;;
        *) break;;
    esac
    shift
done

# Remove any and all temporary corefile leftovers
find $data_dir -name 'tmp.??????' | xargs -r rm -rf

# Check the capacity before we write the new core file. If we are over 70%
# capacity, remove some old files first to make it likely that our new coredump
# will complete successfully.
for f in $(ls -tc -r $file_dir/core*); do
    capacity=$(df -Pm $file_dir | tail -1 | sed s/%//g | awk '{print $5}')
    if [ "$capacity" -gt "$limit" ]; then
        logger -t $scriptname "Removing core file $f to reclaim some space for new coredump."
        rm $f
    else
        break
    fi
done

# temp file must be on the same disk as the
# resulting $filename, so create a temporary
# file over there.
tmp=$(mktemp -p $file_dir)

dd of=$tmp
dumpfailed=$?
sync 
if [ "$dumpfailed" -ne 0 ]; then
    logger -t $scriptname "Failed to create core file for $filename."
    rm $tmp
    exit $dumpfailed
fi

# this is an atomic operation, thus the file
# integrity is guaranteed when it's moved.
mv $tmp $filename

# Ensure that core file space used does not exceed our core file size limit
# (28MB by default). If we exceed the limit, start by removing oldest core files
# first until we are under threshold, we can't clean anymore, or we just have
# our new file left.
for f in $(ls -tc -r $file_dir/core*); do
    # don't delete our new core file!
    if [ "$f" == "$filename" ] ; then break; fi

    space_used=$(core_file_space_used)
    if [ "$space_used" -gt "$core_limit" ]; then
        logger -t $scriptname "Cleaning core file $f for space."
        rm $f
    else
        break
    fi
done

exit 0
