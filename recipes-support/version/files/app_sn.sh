#!/bin/sh
#
# application serial number support
#

# usage
usage() {
   #echo "usage: $0 <-g|-s serialnum> [-d]"
   echo "usage: $0 <-g> [-d]"
   echo ""
   echo " -g,--getserial                 - get serialnumber"
   echo " -h,--help                      - this help message"
   echo ""
   exit $RC
}

# handle parameters
DEBUG=0
SERIAL=""
GET=0
RC=0
ARGS=$#
while [ "$1" ]; do
   case "$1" in
      -g|--getserial) GET=1; ;;
      -h|--help)  usage;;
      *) echo Invalid parameter: $1; usage;;
   esac
   shift
done

if [ $GET -eq 0 ] ; then
 echo "Error: must specify -g"
 RC=1
 usage
fi

# database existance check
db="/opt/irobot/persistent/opt/irobot/data/mfg/serial.json"
if [ ! -f $db ] ; then
  echo unknown
  RC=3
  exit $RC
fi

SN=$(awk '/serial_number/ {printf $2;exit;}' $db | sed s/[\",]//g)
if [ -n "$SN" ]; then
  echo $SN
else
  echo unknown
fi

exit $RC
