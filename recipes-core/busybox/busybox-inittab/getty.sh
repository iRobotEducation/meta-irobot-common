#!/bin/sh
#
# start/autorestart for the serial port getty.
# allows for start/autorestart only when system access is not "locked"
#

PROVISION_FILE=/opt/irobot/config/provisioning

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
   # do nothing on ctrl-c
   true
}

# set the default system access to locked
SYSTEM_ACCESS="locked"

# pull in the provisioning variables (including SYSTEM_ACCESS) into this environment
if [ -r ${PROVISION_FILE} ] ; then
    . ${PROVISION_FILE}
fi

if  [ -n "${SYSTEM_ACCESS}" ] && [ "${SYSTEM_ACCESS}" == "unlocked" ] || [ "${SYSTEM_ACCESS}" == "beta" ]  ; then
  # system is unlocked, start a console terminal
  /sbin/getty 115200 ttyS1 > /dev/null 2>&1
else
  # system is locked, do nothing
  while [ 1 ] ; do
    sleep 2
  done
fi

exit 0
