#!/bin/sh
# purpose: identify mobility reset pin and reset communication channel for
# downloader binary if needed to update mobility based on Project and Board
# Rev identification.
# IN ARGS   :   One
#               -p or --project which is a direct user input or an indirect
#               user input from slave_firmware_install.sh or another
#               script/application
# Return    :   "PROJ=<daredevil> PIN=<+ve numeric> COM_DEV_FILE=<UART_DEV_FILE>
#               with zero exit code
#                                       or
#               appropriate error message with error code as exit code

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
EX_NS_PROJ_IN_REQUEST=6
EX_NS_UNKNOWN_PROJ_INPUT=7
EX_NS_UNKNOWN_PROJ_INPUT_DAREDEVIL=8

SCRIPT_NAME=$0

if [[ $(id -u $(whoami)) != 0 ]]; then
    echo "Error: ${SCRIPT_NAME} should be run with root privileges"
    exit $EX_USAGE;
fi

PROJECT_TYPE_USER_IN=
NAV_MOB_COM_DEVICE=/dev/ttyMobility0

usage()
{
    RET=$1;
    echo "Usage:    ${SCRIPT_NAME} <arguments>";
    echo "  requires root privileges. Either root user or sudo";
    echo "Arguments:";
    echo "Optional :";
    echo "              -p=<daredevil> or --project=<daredevil>";
    echo "                  Project id can't be detected by the script";
    echo "                      user inputs 'daredevil' as project id to reset mobility";
    echo "              --help";
    echo "                  display usage information";
    echo "Output format:";
    echo "  No Error:   PROJ=project_type PIN=numeric; exit code 0";
    echo "  Error:      appropriate error message; exit code non-zero";
    exit ${RET};
}

for i in "$@"
do
case $i in
    -p=*|--project=*)
        PROJECT_TYPE_USER_IN="${i#*=}"
        shift
        ;;
    --default)
        shift
        ;;
    --help)
        # display usage
        usage $EX_USAGE;
        ;;
esac
done

get_robot_project_hw_id_info()
{

    DAREDEVIL_B0_NAV_MOB_RESET_GPIO_PIN=16
    BOARD_HW_ID_PIN1=21
    BOARD_HW_ID_PIN2=20
    BOARD_HW_ID_PIN3=19

    BOARD_HW_ID_PINS="${BOARD_HW_ID_PIN1} ${BOARD_HW_ID_PIN2} ${BOARD_HW_ID_PIN3}"

    BOARD_HW_ID_BIT_POS_PIN1=0
    BOARD_HW_ID_BIT_POS_PIN2=1
    BOARD_HW_ID_BIT_POS_PIN3=2

    BOARD_HW_ID_PIN_VALUE_HIGH=1
    BOARD_HW_ID_PIN_VALUE_LOW=0

    PROJECT_TYPE_DAREDEVIL="daredevil"
    PROJECT_TYPE_UNKNOWN="unknown"
    PROJECT_TYPE="${PROJECT_TYPE_UNKNOWN}"

    PROJECT_TYPE_ID_PIN=${BOARD_HW_ID_PIN1}
    PROJECT_TYPE_ID_PIN_BIT_POS=${BOARD_HW_ID_BIT_POS_PIN1}

    PROJECT_TYPE_DAREDEVIL_ID=$(($BOARD_HW_ID_PIN_VALUE_HIGH << $PROJECT_TYPE_ID_PIN_BIT_POS))

    BOARD_ID_B0_DAREDEVIL=$(($BOARD_HW_ID_PIN_VALUE_LOW << $BOARD_HW_ID_BIT_POS_PIN1 | \
                   $BOARD_HW_ID_PIN_VALUE_LOW << $BOARD_HW_ID_BIT_POS_PIN2 | \
                   $BOARD_HW_ID_PIN_VALUE_LOW << $BOARD_HW_ID_BIT_POS_PIN3))

    BOARD_ID_EP2_DAREDEVIL=$(($BOARD_HW_ID_PIN_VALUE_HIGH << $BOARD_HW_ID_BIT_POS_PIN1 | \
                   $BOARD_HW_ID_PIN_VALUE_LOW << $BOARD_HW_ID_BIT_POS_PIN2 | \
                   $BOARD_HW_ID_PIN_VALUE_LOW << $BOARD_HW_ID_BIT_POS_PIN3))

    # ID for nav baords with new max98357a audio codec
    BOARD_ID_MAXIM_DAREDEVIL=$(($BOARD_HW_ID_PIN_VALUE_LOW << $BOARD_HW_ID_BIT_POS_PIN1 | \
                   $BOARD_HW_ID_PIN_VALUE_HIGH << $BOARD_HW_ID_BIT_POS_PIN2 | \
                   $BOARD_HW_ID_PIN_VALUE_LOW << $BOARD_HW_ID_BIT_POS_PIN3))

    BOARD_ID_UNKNOW=0
    BOARD_ID=${BOARD_ID_UNKNOW}
    BOARD_ID_READ_VALUE=0

    c=1
    for i in ${BOARD_HW_ID_PINS}
    do
        VALUE=`gpio -p $i -g`
        if [[ $VALUE -eq $BOARD_HW_ID_PIN_VALUE_HIGH || $VALUE -eq $BOARD_HW_ID_PIN_VALUE_LOW ]]; then
            SHIFT="BOARD_HW_ID_BIT_POS_PIN$c"
            BOARD_ID_READ_VALUE=$(($BOARD_ID_READ_VALUE + $(($VALUE << $SHIFT))))
            if [ $i -eq $PROJECT_TYPE_ID_PIN ]; then
                VALUE=$(($VALUE << $PROJECT_TYPE_ID_PIN_BIT_POS))
                PROJECT_TYPE="${PROJECT_TYPE_DAREDEVIL}"
            fi
        else
            echo "Error: Value can't be read from PIN $i. Exiting...";
            exit ${EX_OSERR};
        fi
        c=$((c+1))
    done

    case $PROJECT_TYPE in
        $PROJECT_TYPE_DAREDEVIL)
            NAV_MOB_COM_DEVICE=/dev/ttyMobility0
            if [ $BOARD_ID_READ_VALUE -eq $BOARD_ID_B0_DAREDEVIL ]; then
                BOARD_ID=$BOARD_ID_B0_DAREDEVIL
                NAV_MOB_RESET_GPIO_PIN=$DAREDEVIL_B0_NAV_MOB_RESET_GPIO_PIN
            elif [[ $BOARD_ID_READ_VALUE -eq $BOARD_ID_EP2_DAREDEVIL || $BOARD_ID_READ_VALUE -eq $BOARD_ID_MAXIM_DAREDEVIL ]]; then
                BOARD_ID=$BOARD_ID_READ_VALUE
                NAV_MOB_RESET_GPIO_PIN=$DAREDEVIL_B0_NAV_MOB_RESET_GPIO_PIN
	    else
                echo "Error: Unknown Project can't program. Exiting...";
                exit ${EX_NS_PROJ_IN_REQUEST};
            fi
            ;;
        *)
            echo "Error: Unknown Project can't program. Exiting...";
            exit ${EX_NS_PROJ_IN_REQUEST};
            ;;
    esac
}

get_robot_project_hw_id_info

echo "PROJ=${PROJECT_TYPE} PIN=${NAV_MOB_RESET_GPIO_PIN} COM_DEV_FILE=${NAV_MOB_COM_DEVICE} BOARD_ID=${BOARD_ID}"
exit ${EX_OK};
