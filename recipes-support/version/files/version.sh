#!/bin/sh
#
# Display firmware version information
#

PROVISION_FILE=/opt/irobot/config/provisioning
if [ -r ${PROVISION_FILE} ] ; then
    . ${PROVISION_FILE}
fi

if [ -f /opt/irobot/version.env ]; then
  . /opt/irobot/version.env
fi

if [ -f /opt/irobot/identity.env ]; then
  . /opt/irobot/identity.env
fi

if [ -z ${MODEL+x} ] ; then
  PROD_PREFIX=generic
else
  PROD_PREFIX=$MODEL
fi

# output the PRODUCT_VERSION
echo -n "Product Version: $PROD_PREFIX+"
if [ -z ${PRODUCT_VERSION+x} ]; then
  echo "unknown"
else
  echo $PRODUCT_VERSION
fi

echo -n "OS Version: "
if [ -z ${OS_VERSION+x} ]; then
  echo "unknown"
else
  echo $OS_VERSION
fi

echo -n "OS Build Date: "
if [ -z ${OS_BUILD_TIMESTAMP+x} ]; then
  echo "unknown"
else
  echo ${OS_BUILD_TIMESTAMP}
fi

echo -n "Build Type: "
if [ -z ${BUILD_TYPE+x} ]; then
  echo "unknown"
else
  echo ${BUILD_TYPE}
fi

BL_VERSION=`sed -n 's/.*bl_version=\([^[:space:]]*\)\(.*\)$/\1/p' /proc/cmdline`
if [ -z ${BL_VERSION} ]; then
    BL_VERSION="unknown"
fi
echo "Bootloader Version: ${BL_VERSION}"

# Obtain the TSK fingerprint from /var/run/tsk-fingerprint. This file is 
# created by irbtsetup. See meta-irobot-mt/recipes-support/irbtsetup
TSK_FINGERPRINT=`cat /var/run/tsk-fingerprint 2> /dev/null`
if [ -z ${TSK_FINGERPRINT} ]; then
    TSK_FINGERPRINT="unknown"
fi

PROD_FINGERPRINT="3fa49ee6b2a56423e27c32b8bf13dc826d9cd3281c1d46130e2714242adf9dfd"
CREATE_FINGERPRINT="c2444ff57a6697b86733b6308f9dc502807c8cc81144768cfe43de93214790db"
if [ "$TSK_FINGERPRINT" == "$PROD_FINGERPRINT" ]; then
    TSK_FINGERPRINT="${TSK_FINGERPRINT} (PRODUCTION)"
elif [ "$TSK_FINGERPRINT" == "$CREATE_FINGERPRINT" ]; then
    TSK_FINGERPRINT="${TSK_FINGERPRINT} (Create3)"
elif [ "$TSK_FINGERPRINT" == "unknown" ]; then
    TSK_FINGERPRINT="${TSK_FINGERPRINT} (UNKNOWN)"
else
    TSK_FINGERPRINT="${TSK_FINGERPRINT} (ENGINEERING)"
fi

echo "TSK Fingerprint: ${TSK_FINGERPRINT}"

PREV_OS_VERSION="unknown"
grep -q old_rootfs /proc/mtd
if [ $? -eq 0 ]; then
  # try to find the mtd number
  MTD_NUM=$(grep -m 1 old_rootfs /proc/mtd | awk -F ' ' '{print $1}' | sed 's/[^0-9]*//g')
  if [ ! -z "${MTD_NUM##*[!0-9]*}" ]; then
    if [ -b /dev/mtdblock$MTD_NUM ]; then
      mount /dev/mtdblock$MTD_NUM /mnt/system.prev > /dev/null 2>&1
      if [ -f /mnt/system.prev/opt/irobot/version.env ]; then
        PREV_OS_VERSION=$(grep -m 1 OS_VERSION /mnt/system.prev/opt/irobot/version.env |  awk -F '=' '{print $2}')
      fi
      umount /mnt/system.prev > /dev/null 2>&1
    fi
  fi
  if [ -z $PREV_OS_VERSION ] ; then
    PREV_OS_VERSION="unknown"
  fi
fi
echo "Previous OS Version: $PREV_OS_VERSION"

# get the cleantrack version through strings on the binary
if [ "$CLEANTRACK_PATH" == "" ]; then
  CLEANTRACK_PATH="/opt/irobot/bin"
fi

if [ -f $CLEANTRACK_PATH/cleantrack ]; then
  strings $CLEANTRACK_PATH/cleantrack 2> /dev/null | grep -m 1 "firmware version" | grep -v "%s" | awk -F':' '{print "Cleantrack Version:"$2}'
else
  echo "Cleantrack Version: Program not installed"
fi

# get the connectivity binaries version through strings on the binary
# if connectivity binaries path is not set in provisioning, then fall back to
# system default
if [ "$CONNECTIVITY_SERVICES_PATH" == "" ]; then
    CONNECTIVITY_SERVICES_PATH="/opt/irobot/bin"
fi

if [ -f $CONNECTIVITY_SERVICES_PATH/local_manager ]; then
  LOCAL_MANAGER_VERSION=$($CONNECTIVITY_SERVICES_PATH/local_manager -v 2> /dev/null | grep -m 1 "Connectivity Module version" |  awk -F ' ' '{print $4}' |  tr '\"' ' ')
  if [ -z $LOCAL_MANAGER_VERSION ]; then
    LOCAL_MANAGER_VERSION="unknown"
  fi
else
  LOCAL_MANAGER_VERSION="Program not installed"
fi
echo "Local Manager Version: $LOCAL_MANAGER_VERSION"

if [ -f $CONNECTIVITY_SERVICES_PATH/network_manager ]; then
  NETWORK_MANAGER_VERSION=$($CONNECTIVITY_SERVICES_PATH/network_manager -v 2> /dev/null | grep -m 1 "Connectivity Module version" |  awk -F ' ' '{print $4}' |  tr '\"' ' ')
  if [ -z $NETWORK_MANAGER_VERSION ]; then
    NETWORK_MANAGER_VERSION="unknown"
  fi
else
  NETWORK_MANAGER_VERSION="Program not installed"
fi
echo "Network Manager Version: $NETWORK_MANAGER_VERSION"

if [ -f $CONNECTIVITY_SERVICES_PATH/cloud_manager ]; then
  CLOUD_MANAGER_VERSION=$($CONNECTIVITY_SERVICES_PATH/cloud_manager -v 2> /dev/null | grep -m 1 "Connectivity Module version" |  awk -F ' ' '{print $4}' |  tr '\"' ' ')
  if [ -z $CLOUD_MANAGER_VERSION ]; then
    CLOUD_MANAGER_VERSION="unknown"
  fi
else
  CLOUD_MANAGER_VERSION="Program not installed"
fi
echo "Cloud Manager Version: $CLOUD_MANAGER_VERSION"

if [ -f $CONNECTIVITY_SERVICES_PATH/scheduler ]; then
  SCHEDULER_VERSION=$($CONNECTIVITY_SERVICES_PATH/scheduler -v 2> /dev/null | grep -m 1 "Connectivity Module version" |  awk -F ' ' '{print $4}' |  tr '\"' ' ')
  if [ -z $SCHEDULER_VERSION ]; then
    SCHEDULER_VERSION="unknown"
  fi
else
  SCHEDULER_VERSION="Program not installed"
fi
echo "Scheduler Version: $SCHEDULER_VERSION"

if [ -f $CONNECTIVITY_SERVICES_PATH/ota_manager ]; then
  OTA_MANAGER_VERSION=$($CONNECTIVITY_SERVICES_PATH/ota_manager -v 2> /dev/null | grep -m 1 "Connectivity Module version" |  awk -F ' ' '{print $4}' |  tr '\"' ' ')
  if [ -z $OTA_MANAGER_VERSION ]; then
    OTA_MANAGER_VERSION="unknown"
  fi
else
  OTA_MANAGER_VERSION="Program not installed"
fi
echo "Ota Manager Version: $OTA_MANAGER_VERSION"

if [ -f $CONNECTIVITY_SERVICES_PATH/connectivity_manager ]; then
  CONNECTIVITY_MANAGER_VERSION=$($CONNECTIVITY_SERVICES_PATH/connectivity_manager -v 2> /dev/null | grep -m 1 "Connectivity Module version" |  awk -F ' ' '{print $4}' |  tr '\"' ' ')
  if [ -z $CONNECTIVITY_MANAGER_VERSION ]; then
    CONNECTIVITY_MANAGER_VERSION="unknown"
  fi
else
  CONNECTIVITY_MANAGER_VERSION="Program not installed"
fi
echo "Connectivity Manager Version: $CONNECTIVITY_MANAGER_VERSION"

BOOT_COUNT="$(/usr/bin/boot_counter.sh -g )"
if [ $? -eq 0 ]; then
  echo "Boot Count: $BOOT_COUNT"
else
  echo "Boot Count: unknown"
fi

NSN=$(/usr/bin/app_sn.sh -g 2>/dev/null)
if [ $? -eq 0 ]; then
  echo "Navigation Serial Number: "$NSN
else
  echo "Navigtion Serial Number: unknown"
fi

RID="unknown"
if [ -f /opt/irobot/persistent/opt/irobot/data/kvs/robot_id ] ; then
  RID=$(cat /opt/irobot/persistent/opt/irobot/data/kvs/robot_id)
  if [ -z $RID ] ; then
    RID="unknown"
  fi
elif [ -f /opt/irobot/persistent/opt/irobot/data/kvs/product.robotid ] ; then
  RID=$(cat /opt/irobot/persistent/opt/irobot/data/kvs/product.robotid)
  if [ -z $RID ] ; then
    RID="unknown"
  fi
fi
echo "Robot ID: "$RID


BOARD_REV="unknown"
PIN_INFO=$(/usr/bin/get_proj_mob_pin_det.sh)

# extract data
for i in ${PIN_INFO}
do
case $i in
    BOARD_ID=*)
        BOARD_REV="${i#*=}";
        shift;
        ;;
    *)
        shift
        ;;
esac
done

if [ x${BOARD_REV} == "x0" ]; then
  BOARD_TYPE="(sundial P1/P2/EP1)"
elif [ x${BOARD_REV} == "x1" ]; then
  BOARD_TYPE="(sundial EP2)"
elif [ x${BOARD_REV} == "x2" ]; then
  BOARD_TYPE="(sundial MAX audio)"
else
  BOARD_TYPE="(unknown type)"
fi

echo "Nav board revision: "$BOARD_REV $BOARD_TYPE

# display aux board versions
/usr/bin/auxboard_version.sh
