#!/bin/sh
#
# system boot counter support.
# get/set the count of the number of times the system has booted
#

# usage
usage() {
   echo "usage: $0 <-g|-s> [-d]"
   echo ""
   echo " -s,--incrbootcount             - increment the bootcount by 1"
   echo " -g,--getbootcount              - get the bootcount"
   echo " -h,--help                      - this help message"
   echo ""
   exit $RC
}

# handle parameters
DEBUG=0
BOOT_COUNT=""
SET=0
GET=0
RC=0
ARGS=$#
while [ "$1" ]; do
   case "$1" in
      -s|--incrcount) SET=1; shift;;
      -g|--getcount) GET=1; ;;
      -d|--debug)  DEBUG=1;;
      -h|--help)  usage;;
      *) echo Invalid parameter: $1; usage;;
   esac
   shift
done

if [ $GET == $SET ] ; then
 echo "Error: must specify one request, either -s or -g"
 RC=1
 usage
fi

# retrieve the id for boot_count
if [ $GET == 1 ]; then
  PROVISION_FILE=/opt/irobot/config/provisioning
  if [ -r ${PROVISION_FILE} ] ; then
      . ${PROVISION_FILE}
  fi
  if [ -n "$BOOTCOUNT" ] ; then
    echo $BOOTCOUNT
  else
    echo "unknown"
  fi
fi

if [ $SET == 1 ]; then
  /data/provision.sh --incrbootcount > /dev/null 2>&1
fi


sync
exit $RC
