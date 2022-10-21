#!/bin/sh

# error/return/exit codes
# are in sync with /usr/include/sysexits.h
EX_OK=0
EX_USAGE=64
EX_DATAERR=65
EX_NOINPUT=66
EX_NOUSER=67
EX_NOHOST=68
EX_UNAVAILABLE=69
EX_SOFTWARE=70
EX_OSERR=71
EX_OSFILE=72
EX_CANTCREAT=73
EX_IOERR=74
EX_TEMPFAIL=75
EX_PROTOCOL=76
EX_NOPERM=77
EX_CONFIG=78
EX__MAX=78

# Non standard error code definitions to be in sync with
# iRobot specific userspace applications and other
# automated scripts process
# error code for unknow reset type. Used in cleantrack only currently
EX_NS_UNKNOWN_APP=3
EX_NS_UNKNOWN_UPDATE_RESET_TYPE=4
EX_NS_UPDATE_RESET_TYPE_ALONE=5
EX_NS_PROJ_IN_REQUEST=6
EX_NS_UNKNOWN_PROJ_INPUT=7
EX_NS_UNKNOWN_PROJ_INPUT_TRIDENT=8
EX_NS_UNKNOWN_PROJ_INPUT_WICHITA=9
EX_NS_UNKNOWN_PROJ_INPUT_DAREDEVIL=10
EX_NS_USER_CANCEL=11
EX_NS_UNKNOWN_MANUAL_RESET_TYPE=12

SCRIPT_NAME=$0

if [[ $(id -u $(whoami)) != 0 ]]; then
    echo "Error: ${SCRIPT_NAME} should be run with root privileges"
    exit $EX_USAGE;
fi
# Constants
RESET_SLEEP=0.3
RESET_WIGGLE_SLEEP=0.2
# Wait time in seconds before resetting mobility after mobility self upgrade
# requested
MOBILITY_SELF_UPGRADE_TRIDENT_WAIT=60
MOBILITY_SELF_UPGRADE_DAREDEVIL_WAIT=60
MOBILITY_SELF_UPGRADE_WICHITA_WAIT=220

MOBILITY_SELF_UPGRADE_SLEEP=${MOBILITY_SELF_UPGRADE_TRIDENT_WAIT}

RESET_PIN_NUM_PULSES=500

NAV_MOB_RESET_GPIO_PIN=16
NAV_MOB_RESET_TYPE_RESET=reset
NAV_MOB_RESET_TYPE_WIGGLE=wiggle
NAV_MOB_RESET_TYPE=${NAV_MOB_RESET_TYPE_RESET}

PROVISION_FILE=/opt/irobot/config/provisioning
FW_FILE=
PROJECT_TYPE_USER_IN=
NAV_MOB_COM_DEVICE=/dev/ttyMobility0
NO_RESET_CLEANTRACK=
NO_RESET_CONNECTIVITY=
RETRIES_REQUESTED="1"
MOB_UPDATE_RESET_TYPE_UPDATE_ONLY=0
MOB_UPDATE_RESET_TYPE_RESET_ONLY=1
MOB_UPDATE_RESET_TYPE_UPDATE_RESET=2
MOB_UPDATE_RESET_TYPE=${MOB_UPDATE_RESET_TYPE_UPDATE_RESET}
# no input initially
MOB_UPDATE_RESET_TYPE_INPUT=0
MOB_RESET_GPIO_CUR_STATE=$EX_OSERR

# Script to get Project type and Mobility reset PIN numbers
GET_PROJ_MOB_PIN_SCRIPT="/usr/bin/get_proj_mob_pin_det.sh"
# Should be in-sync with values from get_proj_mob_pin_det.sh
PROJECT_TYPE_TRIDENT="trident"
PROJECT_TYPE_WICHITA="wichita"
PROJECT_TYPE_DAREDEVIL="daredevil"
PROJECT_TYPE_UNKNOWN="unknown"

# used for reset type on Soho/Sanmarino robots to support
# old and new HW as reset logic has changed in Soho EP1A and Sanmarino's after
# P4 version
MOB_RESET_TYPE_MANUAL_INPUT=

usage()
{
    RET=$1;
    echo "Usage:    ${SCRIPT_NAME} <arguments>";
    echo "  requires root privileges. Either root user or sudo";
    echo "Arguments:";
    echo "Mandatory:    -f=<mobility-firmware-file> or --firmware=<mobility-firmware-file>";
    echo "Optional :";
    echo "              -p=<daredevil|trident|wichita> or --project=<daredevil|trident|wichita>";
    echo "                  Project id can't be detected by the script";
    echo "                      user inputs 'daredevil' or 'trident' or 'wichita' as project id to reset mobility";
    echo "              --ignore-app-reset=<name of app(s)>";
    echo "                  currently supported app name is 'cleantrack'";
    echo "                  used only by application that intended to update mobility";
    echo "                  when app(s) name is passed those apps will not be stopped if they are already running";
    echo "                  mostly used by cleantrack when launched from cleantrack";
    echo "              --update-reset-type=<updateonly/resetonly/updatereset>";
    echo "                  this is valid if and only if --ignore-app-reset is used";
    echo "                  app can request whether to update mobility only and reset mobility only or update and reset";
    echo "                  value:";
    echo "                      updateonly  :   update mobility without mobility reset after update";
    echo "                      resetonly   :   just reset mobility without update";
    echo "                      updatereset :   update mobility and reset mobility after update";
    echo "                  Default :   updatereset";
    echo "              --reset-type=<reset/wiggle>";
    echo "                  this is needed to support some Trident projects robots which uses both";
    echo "                  reset and wiggle mobility reset logic in older and newer versions of HW respectively.";
    echo "                  There is no Hardware Identification on Nav board for this, so user input is required.";
    echo "                  value:";
    echo "                      reset       :   For Soho Trident Robots till P7 version";
    echo "                                      For Sanmarino Trident Robots till P4 version";
    echo "                      wiggle      :   For Soho Trident Robots after P7 version";
    echo "                                      For Sanmarino Trident Robots after P4 version";
    echo "                  Default :   wiggle";
    echo "              -r|--retry=<number of attempts to download to mobility>";
    echo "Eg:";
    echo "  manual launch:";
    echo "      yes | sudo slave_firmware_install.sh -f=<mobility_firmware_image>";
    echo "                  or";
    echo "      yes | sudo slave_firmware_install.sh -f=<mobility_firmware_image> -p=<daredevil|trident|wichita>";
    echo "                  or";
    echo "      yes | sudo slave_firmware_install.sh -f=<mobility_firmware_image> --reset-type=reset";
    echo "              For Soho Trident till P7 and For Sanmarino Trident till P4";
    echo "                  or";
    echo "      yes | sudo slave_firmware_install.sh -f=<mobility_firmware_image> --reset-type=wiggle";
    echo "              For Soho Trident After P7 and For Sanmarino Trident After P4";
    echo "      ";
    echo "  launch from app:    Mostly from cleantrack if needed";
    echo "      yes | sudo /usr/bin/slave_firmware_install.sh -f=<mobility_firmware_image> --ignore-app-reset=cleantrack --update-reset-type=<updateonly/resetonly/updatereset>";
    echo "                  or";
    echo "      yes | sudo slave_firmware_install.sh -f=<mobility_firmware_image> --ignore-app-reset=cleantrack --update-reset-type=<updateonly/resetonly/updatereset> --reset-type=reset";
    echo "              For Soho Trident till P7 and For Sanmarino Trident till P4";
    echo "                  or";
    echo "      yes | sudo slave_firmware_install.sh -f=<mobility_firmware_image> --ignore-app-reset=cleantrack --update-reset-type=<updateonly/resetonly/updatereset> --reset-type=wiggle";
    echo "              For Soho Trident After P7 and For Sanmarino Trident After P4";
    exit ${RET};
}

# Check args
if [ $# -lt 1 ]; then
    echo "Error: Too few arguments";
    usage $EX_USAGE;
fi

for i in "$@"
do
case $i in
    -f=*|--firmware=*)
        FW_FILE="${i#*=}"
        shift
        ;;
    -p=*|--project=*)
        PROJECT_TYPE_USER_IN="${i#*=}"
        shift
        ;;
    -r=*|--retry=*)
        RETRIES_REQUESTED="${i#*=}"
	# validate RETRIES_REQUESTED is a number
        [ -n "$RETRIES_REQUESTED" ] && [ "$RETRIES_REQUESTED" -eq "$RETRIES_REQUESTED" ] 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Error: Number of retries requested is not a number"
            exit $EX_USAGE
        fi
        shift
        ;;
    --ignore-app-reset=*)
        case `echo ${i#*=} | tr [:upper:] [:lower:]` in
            `echo cleantrack | tr [:upper:] [:lower:]`)
                NO_RESET_CLEANTRACK=1
                ;;
            *)
                echo "Error: Unknown app name to ignore reset"
                usage $EX_NS_UNKNOWN_APP;
                ;;
        esac
        shift
        ;;
    --update-reset-type=*)
        case `echo ${i#*=} | tr [:upper:] [:lower:]` in
            `echo updateonly | tr [:upper:] [:lower:]`)
                MOB_UPDATE_RESET_TYPE_INPUT=1
                MOB_UPDATE_RESET_TYPE=${MOB_UPDATE_RESET_TYPE_UPDATE_ONLY}
                ;;
            `echo resetonly | tr [:upper:] [:lower:]`)
                MOB_UPDATE_RESET_TYPE_INPUT=1
                MOB_UPDATE_RESET_TYPE=${MOB_UPDATE_RESET_TYPE_RESET_ONLY}
                ;;
            `echo updatereset | tr [:upper:] [:lower:]`)
                MOB_UPDATE_RESET_TYPE_INPUT=1
                MOB_UPDATE_RESET_TYPE=${MOB_UPDATE_RESET_TYPE_UPDATE_RESET}
                ;;
            *)
                echo "Error: Unknown update and reset type"
                usage $EX_NS_UNKNOWN_UPDATE_RESET_TYPE;
                ;;
        esac
        shift
        ;;
    --reset-type=*)
        case `echo ${i#*=} | tr [:upper:] [:lower:]` in
            `echo reset | tr [:upper:] [:lower:]`)
                MOB_RESET_TYPE_MANUAL_INPUT="${i#*=}"
                ;;
            `echo wiggle | tr [:upper:] [:lower:]`)
                MOB_RESET_TYPE_MANUAL_INPUT="${i#*=}"
                ;;
            *)
                echo "Error: Unknown manual reset type passed"
                usage $EX_NS_UNKNOWN_MANUAL_RESET_TYPE;
                ;;
        esac
        shift
        ;;

    --default)
        shift
        ;;
    *)
        # unknown option
        usage $EX_USAGE;
        ;;
esac
done

if [[ "x$NO_RESET_CLEANTRACK" = "x" && \
    $MOB_UPDATE_RESET_TYPE_INPUT == 1 ]]; then
        echo "Error: --update-reset-type= can't be used as standalone";
        usage $EX_NS_UPDATE_RESET_TYPE_ALONE;
fi

if [[ $MOB_UPDATE_RESET_TYPE != $MOB_UPDATE_RESET_TYPE_RESET_ONLY ]]; then
    if [[ "x$FW_FILE" = "x" || ! -r  $FW_FILE ]]; then
        echo "Error: Either firmware file invalid input or can't read firmware file";
        usage $EX_NOINPUT;
    fi
fi


mobility_update_pre_post_action()
{
    APP_NAME=$1
    ACTION=$2
    APP_ACTION_SCRIPT=

    case $APP_NAME in
        cleantrack)
            APP_ACTION_SCRIPT="/etc/init.d/cleantrack.init"
            ;;
        *)
            echo "Error: Unknown app name. Exiting...";
            usage $EX_NS_UNKNOWN_APP;
            ;;
    esac

    case $ACTION in
        stop)
            APP_ACTION_SCRIPT="/etc/init.d/cleantrack.init"
            APP_STATUS=$($APP_ACTION_SCRIPT status)
            if [ "$APP_STATUS" == "$APP_NAME is running" ]; then
                echo "$APP_NAME is running and must be closed before updating mobility board"
                echo -n "Terminate cleantrack application (y/n)? "
                read answer
                if echo "$answer" | grep -iq "^y" ; then
                    $APP_ACTION_SCRIPT stop
                else
                    echo -e "Warning: $APP_NAME not terminated, cancelling download"
                    exit $EX_NS_USER_CANCEL;
                fi
            fi
            ;;
        start)
            APP_STATUS=$($APP_ACTION_SCRIPT status)
            if [ "$APP_STATUS" == "$APP_NAME is running" ]; then
                echo "$APP_NAME is already running and so restarting"
                yes | $APP_ACTION_SCRIPT stop
            fi
            $APP_ACTION_SCRIPT start
            ;;

        *)
            echo "Error: Unknown app action. Exiting...";
            usage $EX_SOFTWARE;
            ;;
    esac
}


# Exit and notify user if cleantrack is running. Since the downloader and nav
# board use the same uart, cleantrack must be closed before attempting a
# mobility update.
# check if launcher doesn't want to stop cleantrack
if [[ "x$NO_RESET_CLEANTRACK" = "x" ]]; then
    mobility_update_pre_post_action "cleantrack" "stop"
fi

# Start the install process
if [ -f /usr/bin/read_uboot_env ]; then
BOARD_NAME=$(/usr/bin/read_uboot_env board)
else
BOARD_NAME="default"
fi

# using script to get project type and mobility reset pin
if [[ ! -f ${GET_PROJ_MOB_PIN_SCRIPT} ]]; then
    echo "Error: Missing critical file ${GET_PROJ_MOB_PIN_SCRIPT}";
    echo "Error: Probably corrupted image or Handcopied ${SCRIPT_NAME} is being used";
    exit ${EX_OSFILE};
fi

IN_ARGS_GET_PROJ_MOB=

if [[ "${PROJECT_TYPE_USER_IN}" != "" ]]; then
    IN_ARGS_GET_PROJ_MOB="-p=${PROJECT_TYPE_USER_IN}";
fi

PROJ_MOB_PIN_RET=$(${GET_PROJ_MOB_PIN_SCRIPT} ${IN_ARGS_GET_PROJ_MOB})
RC=$?

if [[ $RC -ne ${EX_OK} ]]; then
    echo "${PROJ_MOB_PIN_RET}";
    exit $RC;
fi

# extract data
for i in ${PROJ_MOB_PIN_RET}
do
case $i in
    PROJ=*)
        PROJECT_TYPE="${i#*=}";
        shift;
        ;;
    PIN=*)
        NAV_MOB_RESET_GPIO_PIN="${i#*=}";
        shift;
        ;;
    COM_DEV_FILE=*)
        NAV_MOB_COM_DEVICE="${i#*=}";
        shift;
        ;;
    --default)
        shift
        ;;
esac
done

# pull in the provisioning variables into this environment
if [ -r ${PROVISION_FILE} ] ; then
    . ${PROVISION_FILE}
fi

case $PROJECT_TYPE in
    $PROJECT_TYPE_TRIDENT)
        if [ -z "${PRODUCT##*soho*}" ] ;then
            MOBILITY_SELF_UPGRADE_SLEEP=${MOBILITY_SELF_UPGRADE_TRIDENT_WAIT}
            NAV_MOB_RESET_TYPE="${MOB_RESET_TYPE_MANUAL_INPUT}"
            if [[ "x${NAV_MOB_RESET_TYPE}" = "x" ]]; then
                echo "Warning: Reset defaulting to wiggle/charge pump type. If this doesn't work. Consider using --reset-type=<>";
                NAV_MOB_RESET_TYPE="${NAV_MOB_RESET_TYPE_WIGGLE}"
            fi
        elif [ -z "${PRODUCT##*lewis*}" ] || \
            [ -z "${PRODUCT##*daredevil*}" ]; then
            # Adding daredevil product to whitelist under Trident project. This
            # is requirement to use Trident based Lewis V3 robots for
            # Daredevil program testing from cleantrack application until
            # Daredevil silicon is available for developer usage and TUT
            # testing
            # FIXME:
            #   This is a workaround should not go into Wichita or any other
            #   APQ8009 SoC based targets unless instructed to do so
            MOBILITY_SELF_UPGRADE_SLEEP=${MOBILITY_SELF_UPGRADE_TRIDENT_WAIT}
            NAV_MOB_RESET_TYPE=wiggle
        elif [ -z "${PRODUCT##*sanmarino*}" ] ;then
            MOBILITY_SELF_UPGRADE_SLEEP=${MOBILITY_SELF_UPGRADE_TRIDENT_WAIT}
            NAV_MOB_RESET_TYPE="${MOB_RESET_TYPE_MANUAL_INPUT}"
            if [[ "x${NAV_MOB_RESET_TYPE}" = "x" ]]; then
                echo "Warning: Reset defaulting to wiggle/charge pump type. If this doesn't work. Consider using --reset-type=<>";
                NAV_MOB_RESET_TYPE="${NAV_MOB_RESET_TYPE_WIGGLE}"
            fi
        else
            echo "Error: Unknown or incompatible product name set";
            echo "Error: Set appropriate product and run ${SCRIPT_NAME} again";
            usage $EX_NS_UNKNOWN_PROJ_INPUT_TRIDENT;
        fi
        ;;
    $PROJECT_TYPE_WICHITA)
        if [ -z "${PRODUCT##*wichita*}" ] ;then
            NAV_MOB_RESET_TYPE=reset
            MOBILITY_SELF_UPGRADE_SLEEP=${MOBILITY_SELF_UPGRADE_WICHITA_WAIT}
        else
            echo "Error: Unknown or incompatible product name set";
            echo "Error: Set appropriate product and run ${SCRIPT_NAME} again";
            usage $EX_NS_UNKNOWN_PROJ_INPUT_WICHITA;
        fi
        ;;
    $PROJECT_TYPE_DAREDEVIL)
        if [ -z "${PRODUCT##*daredevil*}" -o -z "${PRODUCT##*create3*}" ] ;then
            NAV_MOB_RESET_TYPE=wiggle
            MOBILITY_SELF_UPGRADE_SLEEP=${MOBILITY_SELF_UPGRADE_DAREDEVIL_WAIT}
        else
            echo "Error: Unknown or incompatible product name set";
            echo "Error: Set appropriate product and run ${SCRIPT_NAME} again";
            usage $EX_NS_UNKNOWN_PROJ_INPUT_DAREDEVIL;
        fi
        ;;
    *)
        echo "Error: Unknown Project can't program. Exiting...";
        usage $EX_NS_PROJ_IN_REQUEST;
        ;;
esac

get_gpio_pin_value()
{
    DST_PIN=$1
    GPIO_SYSFS_BASE_DIR="/sys/class/gpio"
    if [ -d "${GPIO_SYSFS_BASE_DIR}/gpio${DST_PIN}" ]; then
        MOB_RESET_GPIO_CUR_STATE=`cat "${GPIO_SYSFS_BASE_DIR}/gpio${DST_PIN}/value"`
        return;
    else
        echo ${DST_PIN} > "${GPIO_SYSFS_BASE_DIR}/export"
        if [ ! -d "${GPIO_SYSFS_BASE_DIR}/gpio${DST_PIN}" ]; then
            echo "Warning: Unable to export to read cur state of PIN $DST_PIN"
            return $EX_OSERR;
        fi
        MOB_RESET_GPIO_CUR_STATE=`cat "${GPIO_SYSFS_BASE_DIR}/gpio${DST_PIN}/value"`
        echo ${DST_PIN} > "${GPIO_SYSFS_BASE_DIR}/unexport"
        return;
    fi
    echo "Warning: Unable to read cur state of PIN $DST_PIN"
    return $EX_OSERR;
}

reset_mobility()
{
    # Reset Mobility board
    if [ "$NAV_MOB_RESET_TYPE" == "${NAV_MOB_RESET_TYPE_RESET}" ]; then
        echo "Resetting mobility...";
        gpio -p ${NAV_MOB_RESET_GPIO_PIN} -s 0;
        sleep ${RESET_SLEEP};
        gpio -p ${NAV_MOB_RESET_GPIO_PIN} -s 1;
    elif [ "$NAV_MOB_RESET_TYPE" == "${NAV_MOB_RESET_TYPE_WIGGLE}" ]; then
        get_gpio_pin_value ${NAV_MOB_RESET_GPIO_PIN}
        echo "Read PIN $NAV_MOB_RESET_GPIO_PIN current state as $MOB_RESET_GPIO_CUR_STATE";
        echo "Resetting mobility...";
        gpio -p ${NAV_MOB_RESET_GPIO_PIN} -t -c ${RESET_PIN_NUM_PULSES};
        if [[ $MOB_RESET_GPIO_CUR_STATE -eq 0 || $MOB_RESET_GPIO_CUR_STATE -eq 1 ]]; then
            gpio -p ${NAV_MOB_RESET_GPIO_PIN} -s $MOB_RESET_GPIO_CUR_STATE
        fi
        sleep ${RESET_WIGGLE_SLEEP};
    else
        echo "Error: Unknown reset Type. Exiting...";
        exit $EX_NS_UNKNOWN_UPDATE_RESET_TYPE;
    fi
}

# no mobility update and just the reset was requested from app
if [[ "x$NO_RESET_CLEANTRACK" != "x" && \
    $MOB_UPDATE_RESET_TYPE == $MOB_UPDATE_RESET_TYPE_RESET_ONLY ]]; then
    reset_mobility
    exit $EX_OK
fi

# Update process:
# 1)	Cleantrack will check board ID to choose the correct file to invoke slave_firmware_install 
# 2)	slave_firmware_install should do the following
# 2a)   If the firmware file is a tar.gz package it should call update_nav_driven which does the following
#    a.	Extract files in tar package
#    b. Verify that a manifest file exists
#    b.	Verify md5sum of the files against md5sum in manifest
#    c.	Check manifest for image with IMAGE ID 1 and suffix pkg.enc, if it exists do the following
#       i.	Reset mobility 
#      ii.	Run downloader with provided mobility image
#     iii.	When downloader returns perform wait countdown for 30 seconds.
#    d.	Loop through remaining images listed in manifest, executing downloader 
#       with -e parameter, waiting for downloader to return for each image.
# 2b)	If not a tar.gz package call update_mob_driven which does the following
#    a. reset mobility
#    b. call /usr/bin/downloader with provided mobility image
#    c. perform a wait countdown for 60s
#
AUX_UPDATE_INPROGRESS_FILE="/tmp/aux_board_update_inprogress"
update_mob_driven() {
    echo "Mobility driven download starting, resetting the mobility board"
    reset_mobility

    # set the indicator that an aux board update is in progress
    touch ${AUX_UPDATE_INPROGRESS_FILE}
    /usr/bin/downloader -b 460800 -c $NAV_MOB_COM_DEVICE $FW_FILE

    RC=$?
    # Check for lost connection or other error
    if [ $RC -ne 0 ]; then
        rm ${AUX_UPDATE_INPROGRESS_FILE}
        echo "Error: Downloader failed."
        exit $EX_IOERR
    fi
}

TMP_DIR="/tmp/slave_firmware_install_navdriven_files"
update_nav_driven() {
    mkdir -p ${TMP_DIR}

    tar -xvf $FW_FILE -C $TMP_DIR > /dev/null 2>&1
    RC=$?
    if [ $RC -ne 0 ]; then
        echo "Error: untar $FW_FILE failed"
        rm -rf ${TMP_DIR}
        exit $RC
    fi

    if [ ! -f "${TMP_DIR}/download-manifest.cfg" ] ; then
        echo Error: manifest file not found
        rm -rf ${TMP_DIR}
        exit $EX_NOINPUT
    fi

    # calculate md5sum, checksums are calculated using the file sequence in the manifest
    FILE_LIST="$(awk -v env_var="$TMP_DIR" '/IMAGE/ {printf "%s/%s ", env_var, $3}' ${TMP_DIR}/download-manifest.cfg)"
    MD5SUM_CALC="$(cat ${FILE_LIST} | md5sum | sed 's/ .*$//')"
    MD5SUM=`cat ${TMP_DIR}/download-manifest.cfg | awk  '/MD5SUM/{print $2}'`
    if [ "$MD5SUM" != "$MD5SUM_CALC" ] ; then
        echo "Error: Checksums don't match"
        rm -rf ${TMP_DIR}
        exit $EX_DATAERR
    fi	

    # generate an image list with extraneous parts stripped off
    cat ${TMP_DIR}/download-manifest.cfg | awk '/IMAGE/{print}' > ${TMP_DIR}/images-sorted

    #read images-sorted file line at a time and send to downloader
    echo "Navigation driven download starting"
    # set the indicator that an aux board update is in progress
    touch ${AUX_UPDATE_INPROGRESS_FILE}
    for i in `seq 1 $RETRIES_REQUESTED`;
    do
	DOWNLOADER_FAILED="false"
	while IFS= read -r line
	do
	    IMG_NUM=`echo $line | awk '/IMAGE/{print $2}'`
	    IMG_NAME=`echo $line | awk '/IMAGE/{print $3}'`
	    WAIT=0
	    EXTRA_ARGS="-w 1 -e ${IMG_NUM}"
	    if [[ ${IMG_NUM} == "1" ]] ; then
		# Make sure this is a pkg.enc file 
		if [ $(expr match "$IMG_NAME" '.*\(pkg.enc\)' ) ] ; then
		    WAIT=30
		    EXTRA_ARGS=""
		    reset_mobility
		elif [ $(expr match "$IMG_NAME" '.*\(enc\)' ) ] ; then
		    WAIT=2
		    EXTRA_ARGS=""
		    reset_mobility
		else
		    echo "Error: Was expecting a pkg.enc file"
		    rm ${AUX_UPDATE_INPROGRESS_FILE}
		    rm -rf ${TMP_DIR}
		    exit $EX_NOINPUT
		fi
	    fi

	    echo Downloading $IMG_NAME with $WAIT sec wait
	    echo "/usr/bin/downloader ${EXTRA_ARGS} -b 460800 -c $NAV_MOB_COM_DEVICE ${TMP_DIR}/${IMG_NAME}"
	    /usr/bin/downloader ${EXTRA_ARGS} -b 460800 -c $NAV_MOB_COM_DEVICE ${TMP_DIR}/${IMG_NAME}
	    RC=$?
	    if [ $RC -ne 0 ] ; then
		echo "Error: Downloader failed."
		DOWNLOADER_FAILED="true"
		break
	    fi
	    echo sleeping $WAIT seconds
	    sleep $WAIT
	done < ${TMP_DIR}/images-sorted

	if [ "$DOWNLOADER_FAILED" = "false" ]; then
	    echo "Downloading all images successful"
	    rm ${AUX_UPDATE_INPROGRESS_FILE}
	    rm -rf ${TMP_DIR}
	    break
	fi
        echo "Retrying..."
    done

    if [ "$DOWNLOADER_FAILED" = "true" ]; then
	echo "Error: Downloader failed after $RETRIES_REQUESTED retries"
	rm ${AUX_UPDATE_INPROGRESS_FILE}
	rm -rf ${TMP_DIR}
	exit $EX_IOERR
    fi
}

# check the package type. For navigation driven update a tar.gz package is provided.
if [ $(expr match "$FW_FILE" '.*\(tar.gz\)' ) ] ; then
    update_nav_driven
    UPDATE_TYPE="update_nav_driven"
else
    update_mob_driven
    UPDATE_TYPE="update_mob_driven"
fi

# mobility update and no reset was requested from app
if [[ $MOB_UPDATE_RESET_TYPE == $MOB_UPDATE_RESET_TYPE_UPDATE_RESET ]]; then
    seconds=0
    if [[ $UPDATE_TYPE == "update_mob_driven" ]] ; then
        while [ $seconds -le $MOBILITY_SELF_UPGRADE_SLEEP ]; do
            echo -ne "Download complete, waiting for mobility board application to update... ($((seconds))/$MOBILITY_SELF_UPGRADE_SLEEP)s\r"
            seconds=$(( $seconds + 1 ))
            sleep 1
        done
    fi
    echo -e "\nUpdate complete"

    # Finish update by resetting board
    reset_mobility
fi

# remove the indicator that an aux board update is in progress
rm ${AUX_UPDATE_INPROGRESS_FILE}

# Restart terminated application(s)
if [[ "x$NO_RESET_CLEANTRACK" = "x" ]]; then
    mobility_update_pre_post_action "cleantrack" "start"
fi
