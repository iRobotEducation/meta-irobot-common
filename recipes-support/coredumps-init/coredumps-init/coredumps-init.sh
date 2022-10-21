#!/bin/sh

PROVISION_FILE=/opt/irobot/config/provisioning

daemon_start() {
    # pull in the provisioning variables into this environment
    if [ -r ${PROVISION_FILE} ]; then
        . ${PROVISION_FILE}
    fi

    echo "0" > /proc/sys/kernel/core_uses_pid
    # save one core file per application on Create3 platform
    # note that all core files will be removed if their total size exceeds 20M
    # (see meta-irobot-mt/recipes-core/initscripts/initscripts/persistent_setup.sh)
    echo "/data/logs/core.%e.%h" > /proc/sys/kernel/core_pattern
    #echo "|/usr/bin/coredump-proxy.sh /data/logs/core.%e.%p.%h.%t" > /proc/sys/kernel/core_pattern

}

daemon_usage() {
    echo "Usage: $0 {start}"
    exit 2
}

if [[ $# -ne 1 ]]; then
    daemon_usage
fi

case "$1" in
start)
    daemon_start
;;

*)
    daemon_usage
esac
