#!/bin/sh

LOGGER_TAG="CERTSETPARSER"
CONNECTIVITY_SERVICES_PATH="/opt/irobot/bin"

logger -t ${LOGGER_TAG} "Running certsparser.sh"

SYSTEM_CUSTOM_BIN_PATH="/usr/bin/"
CERT_SET_PARSER_BIN="certsetparser"
CERT_SET_PARSER_BIN_EXEC_PATH="${SYSTEM_CUSTOM_BIN_PATH}${CERT_SET_PARSER_BIN}"

SYS_PROVISION_CMD="/usr/bin/provision"

PROVISION_FILE=/opt/irobot/config/provisioning
if [ -r ${PROVISION_FILE} ] ; then
    . ${PROVISION_FILE}
fi

CONN_BIN_DEF_PATH="/opt/irobot/bin"
CONN_BIN_PROV_PATH=${CONNECTIVITY_SERVICES_PATH}
CONN_BIN_EXTRACT_CERT_ROBOT_ID="robotIdFromCert"

CONN_BIN_EXTRACT_CERT_ROBOT_ID_EXEC_PATH=""

if [[ -d ${CONN_BIN_PROV_PATH} && \
    -f "${CONN_BIN_PROV_PATH}/${CONN_BIN_EXTRACT_CERT_ROBOT_ID}" && \
    -x "${CONN_BIN_PROV_PATH}/${CONN_BIN_EXTRACT_CERT_ROBOT_ID}" ]]; then
    logger -t ${LOGGER_TAG} "RID:EXTRACT:Using provisioned path binary"
    CONN_BIN_EXTRACT_CERT_ROBOT_ID_EXEC_PATH="${CONN_BIN_PROV_PATH}/${CONN_BIN_EXTRACT_CERT_ROBOT_ID}"
elif [[ -d ${CONN_BIN_DEF_PATH} && \
    -f "${CONN_BIN_DEF_PATH}/${CONN_BIN_EXTRACT_CERT_ROBOT_ID}" && \
    -x "${CONN_BIN_DEF_PATH}/${CONN_BIN_EXTRACT_CERT_ROBOT_ID}" ]]; then
    CONN_BIN_EXTRACT_CERT_ROBOT_ID_EXEC_PATH="${CONN_BIN_DEF_PATH}/${CONN_BIN_EXTRACT_CERT_ROBOT_ID}"
    logger -t ${LOGGER_TAG} "RID:EXTRACT:Using system default path binary"
else
    logger -t ${LOGGER_TAG} "RID:EXTRACT:Binary doesn't exist or can't be found"
    logger -t ${LOGGER_TAG} "RID:EXTRACT:No Robot Id Extraction"
fi

ROBOT_CERT_FILE_NAME="cert.pem"
ROBOT_KEY_FILE_NAME="key.pem"
ROBOT_ID_FILE_NAME="product.robotid"

ROBOT_CERTS_TMP_DIR="/tmp/certs"
ROBOT_CERTS_APPS_DIR="/opt/irobot/persistent/opt/irobot/certs"
ROBOT_ID_APPS_DIR="/opt/irobot/persistent/opt/irobot/data/kvs"

ROBOT_CERT_TMP_SRC="${ROBOT_CERTS_TMP_DIR}/${ROBOT_CERT_FILE_NAME}"
ROBOT_KEY_TMP_SRC="${ROBOT_CERTS_TMP_DIR}/${ROBOT_KEY_FILE_NAME}"
ROBOT_ID_TMP_SRC="${ROBOT_CERTS_TMP_DIR}/${ROBOT_ID_FILE_NAME}"

ROBOT_CERT_APPS_DST="${ROBOT_CERTS_APPS_DIR}/${ROBOT_CERT_FILE_NAME}"
ROBOT_KEY_APPS_DST="${ROBOT_CERTS_APPS_DIR}/${ROBOT_KEY_FILE_NAME}"
ROBOT_ID_APPS_DST="${ROBOT_ID_APPS_DIR}/${ROBOT_ID_FILE_NAME}"

ROBOT_CERT_APPS_FALLBACK_DST="/data/${ROBOT_CERT_APPS_DST}"
ROBOT_KEY_APPS_FALLBACK_DST="/data/${ROBOT_KEY_APPS_DST}"
ROBOT_ID_APPS_FALLBACK_DST="/data/${ROBOT_ID_APPS_DST}"

if [ -e /dev/block/bootdevice/by-name/certs ]; then
  ROBOT_CERTS_PART_DEV="/dev/block/bootdevice/by-name/certs"
elif [ -e /dev/ubiblock0_crypto ]; then
  ROBOT_CERTS_PART_DEV="/dev/ubiblock0_crypto"
else
  logger -t ${LOGGER_TAG} "Certs/Crypto Partition was not found"
  exit 1
fi

ROBOT_CERTS_PART_DATA_FILE_DUMP="/tmp/tmp_certs.data"

check_remove_dirty_cert_links () {
    if [[ -h ${ROBOT_CERT_APPS_DST} && ! -f ${ROBOT_CERT_APPS_DST} \
        && "${ROBOT_CERT_TMP_SRC}" == "$(readlink ${ROBOT_CERT_APPS_DST})" ]]; then
        logger -t ${LOGGER_TAG} "Removing spurious certs link"
        rm -f ${ROBOT_CERT_APPS_DST}
    fi

    if [[ -h ${ROBOT_KEY_APPS_DST} && ! -f ${ROBOT_KEY_APPS_DST} \
        && "${ROBOT_KEY_TMP_SRC}" == "$(readlink ${ROBOT_KEY_APPS_DST})" ]]; then
        logger -t ${LOGGER_TAG} "Removing spurious keys link"
        rm -f ${ROBOT_KEY_APPS_DST}
    fi

    if [[ -h ${ROBOT_ID_APPS_DST} && ! -f ${ROBOT_ID_APPS_DST} \
        && "${ROBOT_ID_TMP_SRC}" == "$(readlink ${ROBOT_ID_APPS_DST})" ]]; then
        logger -t ${LOGGER_TAG} "Removing spurious robotid link"
        rm -f ${ROBOT_ID_APPS_DST}
    fi
}

set_tmpfs_certs_permissions () {
    [ -d "${ROBOT_CERTS_TMP_DIR}" ] && chown -R root:apps ${ROBOT_CERTS_TMP_DIR} && chmod -R 550 ${ROBOT_CERTS_TMP_DIR}
    [ -f ${ROBOT_CERT_TMP_SRC} ] && chmod 440 ${ROBOT_CERT_TMP_SRC}
    [ -f ${ROBOT_KEY_TMP_SRC} ] && chmod 440 ${ROBOT_KEY_TMP_SRC}
    [ -f ${ROBOT_ID_TMP_SRC} ] && chmod 440 ${ROBOT_ID_TMP_SRC}
}

check_remove_dirty_cert_links

# extract certs data
devfromname() {
    echo /dev/ubi0_`ubinfo /dev/ubi0 -N $1 | awk '/Volume ID/ {print $3}'`
}
extract_certs () {
    dd status=none if=`devfromname $1` of=${ROBOT_CERTS_PART_DATA_FILE_DUMP}

    if [ $? -ne 0 ]; then
        logger -t ${LOGGER_TAG} "Certs Partition not found or Unable to extract data from Certs volume $1"
        if [ -e ${ROBOT_CERTS_PART_DATA_FILE_DUMP} ]; then
            rm -f ${ROBOT_CERTS_PART_DATA_FILE_DUMP}
        fi
        return 1
    fi

    mkdir -p ${ROBOT_CERTS_TMP_DIR}

    ${CERT_SET_PARSER_BIN_EXEC_PATH} --get-robot-cert ${ROBOT_CERTS_PART_DATA_FILE_DUMP} 2>&1 > ${ROBOT_CERT_TMP_SRC}

    if [ $? -ne 0 ]; then
        logger -t ${LOGGER_TAG} "No Certificate found in volume $1"
        rm -rf ${ROBOT_CERTS_TMP_DIR}
        rm -f ${ROBOT_CERTS_PART_DATA_FILE_DUMP}
        check_remove_dirty_cert_links
        return 1
    else
        logger -t ${LOGGER_TAG} "Certificate extracted and created cert file"
    fi
    ${CERT_SET_PARSER_BIN_EXEC_PATH} --get-robot-key ${ROBOT_CERTS_PART_DATA_FILE_DUMP} 2>&1 > ${ROBOT_KEY_TMP_SRC}

    if [ $? -ne 0 ]; then
        logger -t ${LOGGER_TAG} "No Key found. Continue for RobotId..."
        rm -f ${ROBOT_KEY_TMP_SRC}
        rm -f ${ROBOT_CERTS_PART_DATA_FILE_DUMP}
        check_remove_dirty_cert_links
        return 1
    else
        logger -t ${LOGGER_TAG} "Key extracted and created key file"
    fi

    return 0
}

logger -t ${LOGGER_TAG} "Extracting robot certs"
if ! extract_certs crypto; then
        check_remove_dirty_cert_links
        extract_certs prev_crypto;
fi

if [ "${CONN_BIN_EXTRACT_CERT_ROBOT_ID_EXEC_PATH}" != "" ]; then
    ${CONN_BIN_EXTRACT_CERT_ROBOT_ID_EXEC_PATH} -f ${ROBOT_CERT_TMP_SRC} 2>&1 > ${ROBOT_ID_TMP_SRC}
    if [ $? -ne 0 ]; then
        logger -t ${LOGGER_TAG} "No robot id found"
        rm -rf ${ROBOT_CERTS_TMP_DIR}
        rm -f ${ROBOT_CERTS_PART_DATA_FILE_DUMP}
        check_remove_dirty_cert_links
        exit 1
    fi
else
    logger -t ${LOGGER_TAG} "Robot Id extract binary not found. Exiting..."
    rm -f ${ROBOT_CERTS_PART_DATA_FILE_DUMP}
    check_remove_dirty_cert_links
    set_tmpfs_certs_permissions
    exit 1
fi

if [[ -d ${ROBOT_CERTS_APPS_DIR} ]]; then
    if [[ ! -f ${ROBOT_CERT_APPS_DST} && ! -f ${ROBOT_KEY_APPS_DST} && \
        -f ${ROBOT_CERT_TMP_SRC} &&  -f ${ROBOT_KEY_TMP_SRC} ]]; then
        ln -s ${ROBOT_CERT_TMP_SRC} ${ROBOT_CERT_APPS_DST}
        ln -s ${ROBOT_KEY_TMP_SRC} ${ROBOT_KEY_APPS_DST}
        logger -t ${LOGGER_TAG} "cert, key links created"
    else
        if [[ -h ${ROBOT_CERT_APPS_DST} && -h ${ROBOT_KEY_APPS_DST} ]]; then
            logger -t ${LOGGER_TAG} "cert, key links already created"
        elif [[ ! -f ${ROBOT_KEY_TMP_SRC} ]]; then
            logger -t ${LOGGER_TAG} "Key is not extracted. Don't create links for cert, and key. Continue for Robotid..."
            set_tmpfs_certs_permissions
            rm -f ${ROBOT_CERTS_PART_DATA_FILE_DUMP}
        else
            logger -t ${LOGGER_TAG} "Either cert or key or both files exist. Continue for Robotid..."
            set_tmpfs_certs_permissions
            rm -f ${ROBOT_CERTS_PART_DATA_FILE_DUMP}
        fi
    fi
else
    logger -t ${LOGGER_TAG} "Location ${ROBOT_CERTS_APPS_DIR} doesn't exist"
fi

if [[ -d ${ROBOT_ID_APPS_DIR} ]]; then
    if [[ ! -f ${ROBOT_ID_APPS_DST} && -f ${ROBOT_ID_TMP_SRC} ]]; then
        ln -s ${ROBOT_ID_TMP_SRC} ${ROBOT_ID_APPS_DST}
        logger -t ${LOGGER_TAG} "robotid link created"
    else
        if [[ -h ${ROBOT_ID_APPS_DST} ]]; then
            logger -t ${LOGGER_TAG} "robotid link already created"
        else
            logger -t ${LOGGER_TAG} "Robotid file exist. Exiting..."
            set_tmpfs_certs_permissions
            rm -f ${ROBOT_CERTS_PART_DATA_FILE_DUMP}
            exit 1
        fi
    fi
else
    logger -t ${LOGGER_TAG} "Location ${ROBOT_ID_APPS_DIR} doesn't exist"
fi

logger -t ${LOGGER_TAG} "Running tls_bridge_setup_util"
${CONNECTIVITY_SERVICES_PATH}/tls_bridge_setup_util >/dev/null 2>&1

rm -f ${ROBOT_CERTS_PART_DATA_FILE_DUMP}

set_tmpfs_certs_permissions

exit 0
