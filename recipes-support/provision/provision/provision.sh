#! /bin/sh

###############################
# provision firmware
###############################

[ "$MSG" ] || MSG="Initial configuration complete"
[ "$RESET" ] || RESET="0"

###############################
# hostname
###############################
validate_hostentry ()
{
   local HOST_NAME=$1

   while IFS="" read -r line || [ -n "$line" ]
   do
     echo $line | grep -q "$HOST_NAME"
     if [[ $? -eq 0 ]]; then
       entry_str=$(echo "$line" | awk '{ print $1 }')
       if [[ -n $entry_str ]] && [[ $entry_str == "127.0.0.1" ]]; then
         return 0
       fi
     fi
   done < /etc/hosts

   return 1
}

cfg_hostname() {

   if [ -z "${CUSTOM_HOSTNAME}" ] ; then
      if [ x$RID == "xunknown" ]; then
        HOSTNAME="${PRODUCT}-${SERIAL}"
      else
        # be set to iRobot-<robot id>.
        HOSTNAME="iRobot-${RID}"
      fi
   else
      HOSTNAME=$CUSTOM_HOSTNAME
   fi 

   echo "${HOSTNAME}" > /etc/hostname
   # update the hosts file
   current=`/bin/hostname`
   #echo current is $current
   #echo new is $HOSTNAME
   if [ "x${current}" != "xlocalhost" ] ; then
     # with a readonly rootfs, can't use "-i" flag for sed
     sed --follow-symlinks -e "s/${current}/${HOSTNAME}/g" /etc/hosts \
       > /tmp/hosts
     cp /tmp/hosts /etc/hosts
     rm /tmp/hosts
   fi
   validate_hostentry ${HOSTNAME}
   if [ $? -eq 1 ]; then
     # new hostname is not in the hosts file, put it there
     echo "127.0.0.1	${HOSTNAME}" >> /etc/hosts
   fi

   validate_hostentry "localhost"
   if [ $? -eq 1 ]; then
     # localhosts is not in the hosts file, put it there
     echo "127.0.0.1	localhost" >> /etc/hosts
   fi
   hostname -F /etc/hostname
   if [ ! -z "${RESTART_AVAHI}" ]; then
     /etc/init.d/avahi-daemon restart || /bin/true
   fi
}

###############################
# store the AP bssid
# this value is used in
# cfg_hostapd() to configure
# robot AP with mac addr
###############################
cfg_ap_bssid() {
   if [ -z $APBSSID ] ; then
     # set AP bssid variable 
     # bssid is used to set the mac addr for the AP.
     if [ -f  /sys/class/net/wlan0/address ]; then
       # get the mac addr of wlan0. if valid, use this mac addr as the basis
       # for the bssid.
       MAC_ADDR=$(cat /sys/class/net/wlan0/address)
       # validate the mac address
       if [ `echo $MAC_ADDR | egrep "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$"` ]; then
         # the mac address is valid
         # break the mac addr into octets.
         oc1=$(echo $MAC_ADDR | awk -F ":" '{print $1}')
         oc2=$(echo $MAC_ADDR | awk -F ":" '{print $2}')
         oc3=$(echo $MAC_ADDR | awk -F ":" '{print $3}')
         oc4=$(echo $MAC_ADDR | awk -F ":" '{print $4}')
         oc5=$(echo $MAC_ADDR | awk -F ":" '{print $5}')
         oc6=$(echo $MAC_ADDR | awk -F ":" '{print $6}')
       else
         # the mac address is invalid.
         # set the first three octets to 501479, the iRobot OUI
         oc1=50
         oc2=14
         oc3=79
         # generate random values for the remaining octets.
         oc4=$(printf '%02x' $((RANDOM%100)))
         oc5=$(printf '%02x' $((RANDOM%100)))
         oc6=$(printf '%02x' $((RANDOM%100)))
       fi
       # set the locally administered bit of the first octet
       oc1=$(printf '%02x\n' "$(( 0x$oc1 | 0x02 ))")
       # save the bssid address
       APBSSID="$oc1:$oc2:$oc3:$oc4:$oc5:$oc6"      
       sync
     fi
   fi
}

###############################
# modify hostapd settings
###############################
cfg_hostapd() {
    TMP_HOSTAPD=/tmp/hostapd.conf
    HOSTAPD_FILE=/etc/hostapd.conf
    echo "ctrl_interface=/var/run/hostapd" >> $TMP_HOSTAPD
    echo "interface=$WLANP2PNAME" >> $TMP_HOSTAPD
    echo "ssid=$APSSID" >> $TMP_HOSTAPD
    echo "channel=$APCHAN" >> $TMP_HOSTAPD
    echo "hw_mode=$APHWMODE"  >> $TMP_HOSTAPD
    echo "wmm_enabled=0" >> $TMP_HOSTAPD

    # bssid is used to set the mac addr for the AP.
    if [ -f  /sys/class/net/wlan0/address ]; then
      # get the mac addr of wlan0. if valid, use this mac addr as the basis
      # for the bssid.
      MAC_ADDR=$(cat /sys/class/net/wlan0/address)
      # validate the mac address
      if [ `echo $MAC_ADDR | egrep "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$"` ]; then
        # the mac address is valid
        # break the mac addr into octets.
        oc1=$(echo $MAC_ADDR | awk -F ":" '{print $1}')
        oc2=$(echo $MAC_ADDR | awk -F ":" '{print $2}')
        oc3=$(echo $MAC_ADDR | awk -F ":" '{print $3}')
        oc4=$(echo $MAC_ADDR | awk -F ":" '{print $4}')
        oc5=$(echo $MAC_ADDR | awk -F ":" '{print $5}')
        oc6=$(echo $MAC_ADDR | awk -F ":" '{print $6}')
      else
        # the mac address is invalid.
        # set the first three octets to 501479, the iRobot OUI
        or1=50
        oc2=14
        oc3=79
        # generate random values for the remaining octets.
        oc4=$(printf '%02x' $((RANDOM%100)))
        oc5=$(printf '%02x' $((RANDOM%100)))
        oc6=$(printf '%02x' $((RANDOM%100)))
      fi
      # set the locally administered bit of the first octet
      oc1=$(printf '%02x\n' "$(( 0x$oc1 | 0x02 ))")

      # add the bssid entry to the hostapd.conf file
      # but current mt wifi driver can't set bssid, make it a commented line for now
      echo "#bssid=$oc1:$oc2:$oc3:$oc4:$oc5:$oc6" >> $TMP_HOSTAPD
      sync
    fi

    cp $TMP_HOSTAPD $HOSTAPD_FILE
    rm $TMP_HOSTAPD
    sync

}
###############################
# configure development mode
###############################
cfg_devmode() {
   if [ "x$1" == "xenabled" ]; then
     if [ "$DEV_MODE" == "enabled" ]; then
       echo "-----------------------------------------"
       echo "       Devmode is already enabled        "
       echo "-----------------------------------------"
     # Only enable overlay if we can successfully set it up and try enabling it
     elif /usr/bin/overlay.sh setup; then
       MESSAGE="You must reboot now to finish enabling devmode"
           # We must reboot so that the overlay file systems are mounted underneath all of the files
           # that get mount-copybind'd by firmware_links.sh
       DEV_MODE=$1
     else
       # Failed to enable devmode
       echo "Error: The overlay script is failed to setup"
     fi
   elif [ "x$1" == "xdisabled" ] ; then
     if [ "$DEV_MODE" == "disabled" ]; then
       echo "-----------------------------------------"
       echo "       Devmode is already disabled       "
       echo "-----------------------------------------"
     else
       # We are less pedantic about disabling it.  We attempt tear it down and disable it, telling the user to reboot
       timeout 10 /usr/bin/overlay.sh teardown
       MESSAGE="You must reboot now to finish disabling devmode"
       # We must reboot so that the overlay file systems are unmounted
       DEV_MODE=$1
     fi
   else
     echo " "
     echo "Error: This is not a valid development mode: $1"
     echo " "
     usage
   fi
}

###############################
# configure system access
###############################
cfg_sysaccess() {
   if [ "x$1" == "xlocked"  ] ; then
     SYSTEM_ACCESS=$1
   elif [ "x$1" == "xunlocked"  ] ; then
     SYSTEM_ACCESS=$1
   elif [ "x$1" == "xbeta"  ] ; then
     SYSTEM_ACCESS=$1
   else
     echo " "
     echo "Error: This is not a valid system access mode: $1"
     echo " "
     usage
   fi
}

###############################
# increment the boot counter
###############################
incr_bootcount() {
   BOOTCOUNT=$(($BOOTCOUNT + 1))
}

###############################
# modify udhcpd.conf settings
###############################
cfg_udhcpdconf() {
   grep -q option /etc/udhcpd.conf
   if [ $? -ne 0 ] ; then
     # udhcpd.conf does not have any lines with the key word option.
     # the file is likely corrupt or empty.
     # bring in the default udhcpd.conf file
     cp /etc/udhcpd.conf.default /etc/udhcpd.conf
   fi
   baseip=`echo $APIPADDR | cut -d"." -f1-3`

   cp /etc/udhcpd.conf /tmp/udhcpd.conf
   sed --follow-symlinks -i -e "s/^interface.*/interface  $WLANAPNAME/" /tmp/udhcpd.conf
   sed --follow-symlinks -i -e "s/^start.*/start  $baseip.2/" /tmp/udhcpd.conf
   sed --follow-symlinks -i -e "s/^end.*/end  $baseip.254/" /tmp/udhcpd.conf

   cat /tmp/udhcpd.conf | awk 'match($0, /^([#]*)opt([ion]*)([\ \t]+)dns([\ \t]+)192.*/, matches) {print }' \
       | while read var;do if [ -n "$var" ]; then sed --follow-symlinks -i -e "s/$var/opt dns 0.0.0.0/" /tmp/udhcpd.conf;fi;done

   cat /tmp/udhcpd.conf | awk 'match($0, /^opt([ion]*)([\ \t]+)dns([\ \t]+)129.219.13.*/, matches) {print }' /tmp/udhcpd.conf \
       | while read var;do if [ -n "$var" ]; then sed --follow-symlinks -i -e "s/$var/#$var/" /tmp/udhcpd.conf ;fi;done

   cat /tmp/udhcpd.conf | awk 'match($0, /^opt([ion]*)([\ \t]+)router([\ \t]+)192.168.10.2/, matches) {print }' /tmp/udhcpd.conf \
       | while read var;do if [ -n "$var" ]; then sed --follow-symlinks -i -e "s/$var/opt router 192.168.10.1/" /tmp/udhcpd.conf;fi;done

   cat /tmp/udhcpd.conf | awk 'match($0, /^opt([ion]*)([\ \t]+)wins([\ \t]+)192.168.10.*/, matches) {print }' /tmp/udhcpd.conf \
       | while read var;do if [ -n "$var" ]; then sed --follow-symlinks -i -e "s/$var/#$var/" /tmp/udhcpd.conf ;fi;done

   sed --follow-symlinks -i -e 's/^opt[ion]*[[:space:]]*msstaticroutes/#opt msstaticroutes/' /tmp/udhcpd.conf
   sed --follow-symlinks -i -e 's/^opt[ion]*[[:space:]]*staticroutes/#opt staticroutes/' /tmp/udhcpd.conf

   cat /tmp/udhcpd.conf | awk 'match($0, /^opt([ion]*)([\ \t]+)0x08([\ \t]+)*/, matches) {print }' /tmp/udhcpd.conf \
       | while read var;do if [ -n "$var" ]; then sed --follow-symlinks -i -e "s/$var/#$var/" /tmp/udhcpd.conf;fi;done
   cp /tmp/udhcpd.conf /etc/udhcpd.conf
   rm /tmp/udhcpd.conf

   # delete all empty sed inplace empty files from persistent storage
   rm -rf /opt/irobot/persistent/etc/sed*

}

cfg_network() {
   # update hostapd settings
   cfg_hostapd

   # update udhcpd.conf settings
   cfg_udhcpdconf

   if [ "$CLMODE" == "static"  ] ; then
     CFGCLIPADDR="address $CLIPADDR"
     if [ "$CLNETMASK" != "#" ]; then
       CFGCLNETMASK="netmask $CLNETMASK"
     else
       CFGCLNETMASK="$CLNETMASK"
     fi
     if [ "$CLGW" != "#" ]; then
       CFGCLGW="gateway $CLGW"
     else
       CFGCLGW="$CLGW"
     fi
     CFGCLUPD="# udhcpc.sh not enabled in static mode"
     CFGCLDND="#"
     if [ "$CLDNSNS1" != "#" ]; then
       CFGCLNS1="up echo nameserver $CLDNSNS1 > /etc/resolv.conf"
     else
       CFGCLNS1="up echo \# > /etc/resolv.conf"
     fi
     if [ "$CLDNSNS2" != "#" ]; then
       CFGCLNS2="up echo nameserver $CLDNSNS2 >> /etc/resolv.conf"
     else
       CFGCLNS2="up echo \# >> /etc/resolv.conf"
     fi
     CFGCLTS="up /usr/bin/timesync.sh"
     if [ "$CLDNSSC" != "#" ]; then
       CFGCLSC="up echo search $CLDNSSC >> /etc/resolv.conf"
     else
       CFGCLSC="up echo \# >> /etc/resolv.conf"
     fi
     CFGCLRMR="down echo \# > /etc/resolv.conf"
     CFGCLUP2="#"
     CFGCLDN2="#"
     CFGMODE="static"
   else
     CFGCLIPADDR="#"
     CFGCLNETMASK="#"
     CFGCLUPD="up /usr/bin/udhcpc.sh $WLANCLNAME"
     CFGCLDND="down killall -9 udhcpc > /dev/null 2>&1 || true"
     CFGCLGW="#"
     CFGCLNS1="#"
     CFGCLNS2="#"
     CFGCLSC="#"
     CFGCLRMR="#"
     CFGCLTS="#"
     CFGCLUP2="udhcpc_opts -t $DHCPCDTIMEOUT -T 1 -b -S -x hostname:\`hostname\`"
     CFGCLDN2="down ps ax | grep -q \"[d]hcpcd\" && killall -9 dhcpcd"
     CFGMODE="dhcp"
   fi

   # if CLREGDOMAIN passed with NULL value, then it is an indication to clear
   # the current REG Domain set in the provisioning for 80211d precedence
   # if --clregdomain is not called in provision and we find CLREGDOMAIN
   # set in provisioning file from previous setting, then set that country
   # automatically to be used at bootup. User space apps who controls Reg
   # Domain settings knows the precedence and country code to be used based on
   # the scenario. In this case it is connectivity binaries
   PRE_UP_REG_DOMAIN="#"
   if [[ "${CLREGDOMAIN}" != "#" ]]; then
        PRE_UP_REG_DOMAIN="pre-up iw reg set $CLREGDOMAIN"
   fi

   if [ "$ETH0MODE" == "static"  ] ; then
     CFGETH0PREUP1="pre-up ip addr flush dev eth0 > /dev/null 2>&1 || true"
     CFGETH0IPADDR="address $ETH0IPADDR"
     CFGETH0NETMASK="netmask 255.255.255.0"
   else
     CFGETH0PREUP1="#"
     CFGETH0IPADDR="#"
     CFGETH0NETMASK="#"
   fi

   cat << EOF > /etc/network/interfaces

# /etc/network/interfaces -- configuration file for ifup(8), ifdown(8)

# The loopback interface
auto lo
iface lo inet loopback

# Wireless interface
# $WLANCLNAME is the client interface, $WLANAPNAME is the virtual access point interface
# for the mt proprietary wifi driver, the client inteface and the access point inteface cannot
# be active simultaneously.  however, the client interface must always be UP, even when the
# access point is active

auto $WLANCLNAME
iface $WLANCLNAME inet $CFGMODE
    # clear the ip address's for both the client and access point
    pre-up ip addr flush dev $WLANCLNAME > /dev/null 2>&1 || true
    pre-up ip addr flush dev $WLANAPNAME > /dev/null 2>&1 || true
    # ensure both the client and access point are down before bringing up the client
    pre-up ip link set dev $WLANP2PNAME down > /dev/null 2>&1 || true
    pre-up ip link set dev $WLANAPNAME down > /dev/null 2>&1 || true
    # ensure both hostapd and udhcpd are not running before bringing up the client
    pre-up killall -9 hostapd > /dev/null 2>&1 || true
    pre-up killall -9 udhcpd > /dev/null 2>&1 || true
    # add the virtual access point interface
    up brctl addbr $WLANAPNAME > /dev/null 2>&1 || true
    up brctl addif $WLANAPNAME $WLANP2PNAME > /dev/null 2>&1 || true
    $PRE_UP_REG_DOMAIN
    $CFGCLIPADDR
    $CFGCLNETMASK
    $CFGCLGW
    $CFGCLUP2
    $CFGCLNS1
    $CFGCLNS2
    $CFGCLSC
    wireless_mode managed
    wireless_essid any
    wpa-driver nl80211
    wpa-conf /etc/wpa_supplicant.conf
    down ip addr flush dev $WLANCLNAME
    down ip link set dev $WLANCLNAME down > /dev/null 2>&1 || true
    $CFGCLRMR

#auto $WLANAPNAME
iface $WLANAPNAME inet static
    pre-up ip link set $WLANAPNAME txqueuelen 50 > /dev/null 2>&1 || true
    # clear the ip address's for both the client and access point
    pre-up ip addr flush dev $WLANCLNAME > /dev/null 2>&1 || true
    pre-up ip addr flush dev $WLANAPNAME > /dev/null 2>&1 || true
    # wpa_supplicant must not run in AP mode
    pre-up killall -9 wpa_supplicant > /dev/null 2>&1 || true
    # client interface must be UP for AP mode operation
    pre-up ip link set dev $WLANCLNAME up > /dev/null 2>&1 || true
    up udhcpd /etc/udhcpd.conf
    up hostapd -B /etc/hostapd.conf
    address $APIPADDR
    netmask 255.255.255.0
    down killall -9 hostapd > /dev/null 2>&1 || true
    down killall -9 udhcpd > /dev/null 2>&1 || true
    down ip link set dev $WLANP2PNAME down > /dev/null 2>&1 || true

# Wired interface
auto eth0
iface eth0 inet $ETH0MODE
    $CFGETH0PREUP1
    $CFGETH0IPADDR
    $CFGETH0NETMASK

# USB (CDC-ECM) interface from Debug board
auto usb0
iface usb0 inet static
     pre-up ip addr flush dev usb0 > /dev/null 2>&1 || true
     address $USB0IP
     netmask 255.255.255.0

EOF
}

# usage
usage() {
   echo "usage: $0 [OPTIONS]"
   echo ""
   echo " -s,--serialnum <serialnum>     - integer serialnumber to provision unit"
   echo " --cleanmode <mode>             - cleanmode (normal/diag/none)"
   echo " --connectivity_svc_mode <mode> - connectivity services mode (normal/none)"
   echo " --apipaddr <ipaddr>            - ap point ip addr"
   echo " --apssid <ssid>                - ap point ssid"
   echo " --apchan <channel>             - ap channel"
   echo " --aphwmode <mode>              - ap mode (a, b, g, ad)"
   echo " --wlanclname <clname>          - client interface name (ex wlan0)"
   echo " --wlanapname <apname>          - ap interface name (ex wlan1)"
   echo " --wlanp2pname <p2pname>        - p2p interface name (ex p2p0)"
   echo " --apcc <code>                  - ap country code (ex US)"
   echo " --clmode <mode>                - client mode (static or dhcp)"
   echo " --clipaddr <ipaddr>            - client ip addr (ex 192.168.0.1)"
   echo " --clnetmask <netmask>          - client netmask (ex 255.255.255.0)"
   echo " --clgw <gateway>               - client gateway (ex 192.168.0.254)"
   echo " --cldnssc <search>             - client dns search (ex irobot.com)"
   echo " --cldnsns1 <nameserver>        - client dns nameserver (ex 192.168.0.254)"
   echo " --cldnsns2 <nameserver>        - client dns nameserver (ex 172.128.0.254)"
   echo " --clregdomain <reg domain>     - client regulatory domain (ex US)"
   echo " --dhcpcdtimeout <time>         - client dhcpcd timeout in seconds (0-60)"
   echo " --eth0mode <mode>              - eth0 mode (static or dhcp)"
   echo " --eth0ipaddr <ipaddr>          - eth0 static address (ex 192.168.186.2)"
   echo " --usb0ipaddr <ipaddr>          - usb0 static address (ex 192.168.186.2)"
   echo " --usb0ipsubaddr1 <ipaddr>      - usb0 sub addr static address (ex 192.168.187.2)"
   echo " --radiolist <radios>           - quoted list of wifi radios (ie \"wlan0 wlan1\")"
   echo " --devmode <mode>               - development mode (disabled/enabled)"
   echo " --sysaccess <mode>             - system access (locked/unlocked/beta)"
   echo " --incrbootcount                - increment the system boot counter"
   echo " --extra_language               - set the extra language name (ex pl-PL)"
   echo " --store						 - (re)writes the provisioning file and hostname"
   #echo " --product <id>                 - product id"
   echo " --hostname <hostname>          - set a custom hostname, omit argument to reset the hostname"
   echo " -h,--help                      - this help message"
   echo ""
   echo "Factory Reset: RESET=1 $0"
   echo ""
   exit 1
}

display_vars () {
   echo "   PRODUCT         : $PRODUCT"
   echo "   SERIAL          : $SERIAL"
   echo "   CLEAN MODE      : $CLEANTRACK_MODE"
   echo "   CONNS SVC MODE  : $CONNECTIVITY_SERVICES_MODE"
   echo "   AP RADIO        : $WLANAPNAME/${APHWMODE}/${APCHAN}/${APHT}/${APSSID}/$APCC"
   echo "   AP IP ADDR      : ${APIPADDR}"
   echo "   CL IP           : ${CLMODE}/${CLIPADDR}/${CLNETMASK}/${CLGW}"
   echo "   CL DNS          : ${CLDNSSC}/${CLDNSNS1}/${CLDNSNS2}"
   echo "   CL DHCPCD T/O   : ${DHCPCDTIMEOUT}"
   echo "   CL REG DOMAIN   : ${CLREGDOMAIN}"
   if [ "$ETH0MODE" == "static"  ] ; then
     echo "   ETH0 IP         : ${ETH0MODE}/$ETH0IPADDR"
   else
     echo "   ETH0 IP         : ${ETH0MODE}"
   fi
   echo "   USB0 IP         : $USB0IP/$USB0IPSUBADDR1"
   echo "   SYSTEM_ACCESS   : $SYSTEM_ACCESS"
   echo "   DEVELOPMENT MODE: $DEV_MODE"
   echo "   RADIO_LIST      : $INSTALLED_RADIOS"
   echo "   HOSTNAME        : $HOSTNAME"
   echo "   ROBOT ID        : $RID"
   echo "   BOOT COUNT      : $BOOTCOUNT"
   echo "   LANGUAGE PACK   : $LANGUAGE_PACK_NAME"
   echo "   EXTRA LANGUAGE  : $EXTRA_LANGUAGE"
   echo ""
}

###############################
# Main script
###############################

SERIAL=
# factory default settings start
#
APSSID=Roomba-1234567890123456
APCHAN=6
APHT="[SHORT-GI-20][GF]"
APCC=US
APHWMODE=g
APBSSID=" "
BOOTCOUNT=0
WLANCLNAME=wlan0
WLANAPNAME=wlan1
WLANP2PNAME=p2p0
WLANMONNAME=mon0
APIPADDR="192.168.10.1"
CLMODE="dhcp"
ETH0MODE="static"
ETH0IPADDR="192.168.186.2"
CLIPADDR="#"
CLNETMASK="#"
CLGW="#"
CLDNSSC="#"
CLDNSNS1="#"
CLDNSNS2="#"
DHCPCDTIMEOUT="3"
INSTALLED_RADIOS="wlan0 wlan1"
CLEANTRACK_MODE=normal
CONNECTIVITY_SERVICES_MODE=normal
SYSTEM_ACCESS=unlocked
DEV_MODE=disabled
CLREGDOMAIN="#"
PRODUCT="generic"
LANGUAGE_PACK_NAME="unknown"
EXTRA_LANGUAGE="not_installed"
if [ -f /opt/irobot/persistent/opt/irobot/data/kvs/product.robotid ] ; then
  RID=$(cat /opt/irobot/persistent/opt/irobot/data/kvs/product.robotid)
  if [ -z $RID ] ; then
    RID="unknown"
  fi
elif [ -f /opt/irobot/persistent/opt/irobot/data/kvs/robot_id ] ; then
  RID=$(cat /opt/irobot/persistent/opt/irobot/data/kvs/robot_id)
  if [ -z $RID ] ; then
    RID="unknown"
  fi
else
    RID="unknown"
fi

# factory default settings end

if [ ${RESET} -eq 0 ] ; then
  # if the current provisioning file is found, override the
  # the factory default settings.
  [ -r "/opt/irobot/config/provisioning" ] && . "/opt/irobot/config/provisioning"
else
# use the factory default settings, except for the serial number.
# there is no factory default setting for the serial number.
  if [ -r "/opt/irobot/config/provisioning" ] ; then
    SERIAL=$(grep SERIAL= /opt/irobot/config/provisioning | sed -e 's/SERIAL=//')
  else
    # this should never happen (a factory reset but no provisioning file
    # found to determine the serial number). set serial number to 1
    # to allow for recovery of the unit
    SERIAL=1
  fi
fi

# look for model in file identity.env.
# if found, set PRODUCT=$MODEL
if [ -f /opt/irobot/identity.env ] ; then
  . /opt/irobot/identity.env
  if [ -n $MODEL ] ; then
    PRODUCT=$MODEL
  fi
else
  PRODUCT="generic"
fi

# source language_pack.env for language pack name
LANG_ENV_FILE=/opt/irobot/audio/languages/language_pack.env
if [ -r ${LANG_ENV_FILE} ] ; then
  . ${LANG_ENV_FILE}
fi

# save the number of arguments passed to the script
ARGS=$#
# parse cmdline args

while [ "$1" ]; do
   case "$1" in
      -s|--serialnum) SERIAL=$2; shift;;
      --cleanmode) CLEANTRACK_MODE=$2; shift;;
      --connectivity_svc_mode) CONNECTIVITY_SERVICES_MODE=$2; shift;;
      --apipaddr) APIPADDR=$2; shift;;
      --apssid) APSSID=$2; shift;;
      --apchan) APCHAN=$2; shift;;
      --apht) APHT=$2; shift;;
      --apcc) APCC=$2; shift;;
      --aphwmode) APHWMODE=$2; shift;;
      --clmode) CLMODE=$2; shift;;
      --eth0mode) ETH0MODE=$2; shift;;
      --eth0ipaddr) ETH0IPADDR=$2; shift;;
      --usb0ipaddr) USB0IP=$2; shift;;
      --usb0ipsubaddr1) USB0IPSUBADDR1=$2; shift;;
      --clipaddr) CLIPADDR=$2; shift;;
      --clnetmask) CLNETMASK=$2; shift;;
      --clgw) CLGW=$2; shift;;
      --cldnssc) CLDNSSC=$2; shift;;
      --cldnsns1) CLDNSNS1=$2; shift;;
      --cldnsns2) CLDNSNS2=$2; shift;;
      --clregdomain) CLREGDOMAIN=$2; if [[ -z ${CLREGDOMAIN} ]]; then echo "invalid --clregdomain";usage;fi; shift;;
      --dhcpcdtimeout) DHCPCDTIMEOUT=$2; shift;;
      # setting PRODUCT manually is depracted.
      # PRODUCT is determined by the env variable stored with
      # the navigation code.  keep the --product option to
      # allow backward compatibility, but don't use the value
      # passed with --product
      --product) XPRODUCT=$2; shift;;
      --wlanapname) WLANAPNAME=$2; shift;;
      --wlanclname) WLANCLNAME=$2; shift;;
      --wlanp2pname) WLANP2PNAME=$2; shift;;
      --radiolist) INSTALLED_RADIOS=$2; shift;;
      --devmode) cfg_devmode $2; shift;;
      --sysaccess) cfg_sysaccess $2; shift;;
      --incrbootcount) incr_bootcount; shift;;
      --extra_language) EXTRA_LANGUAGE=$2; shift;;
	  --store) shift;;
      --hostname) CUSTOM_HOSTNAME=$2; RESTART_AVAHI=yes; shift;;
      -h|--help)  usage;;
      *) echo Invalid parameter: $1; usage;;
   esac
   shift
done

[ "$SERIAL" ] || {
  if [ -f /sys/class/net/${WLANCLNAME}/address ] ; then
    # use the lat 3 bytes of the mac addr as the serial number
    MAC_ADDR=$(cat /sys/class/net/${WLANCLNAME}/address | sed s/://g)
    # use the last 6 digits of MAC_ADDR for the serial number
    SERIAL=${MAC_ADDR:6}
  fi
}

case "$CLMODE" in "static"|"dhcp"|"");;
  *) echo "Error: invalid client IP mode"; usage;;
esac

case "$ETH0MODE" in "static"|"dhcp"|"");;
  *) echo "Error: invalid eth0 IP mode"; usage;;
esac


if [ "$CLMODE" == "dhcp"  ] ; then
  CLIPADDR="#"
  CLNETMASK="#"
  CLGW="#"
  CLDNSSC="#"
  CLDNSNS1="#"
  CLDNSNS2="#"
fi


###############################
# setup vars
###############################

USB0IP="192.168.186.2"
USB0IPSUBADDR1="192.168.187.2"

if [ $ARGS -eq 0 ] ; then
  if [ ${RESET} -eq 0 ] ; then
    # no command line arguments entered, and
    # not a factory reset, just display vars and exit
    display_vars
    exit 0
  fi
fi

###############################
# store provisioning vars
###############################
# need to configure hostname, as it may change as robotid or serial change
cfg_hostname
cfg_ap_bssid
mkdir -p /opt/irobot/config
cat << EOF > /opt/irobot/config/provisioning
# This file was created automatically by /usr/bin/provision
# do not edit manually unless you know what you're doing
SERIAL=$SERIAL
PRODUCT=$PRODUCT
CUSTOM_HOSTNAME=$CUSTOM_HOSTNAME
HOSTNAME=$HOSTNAME
WLANCLNAME=$WLANCLNAME
WLANAPNAME=$WLANAPNAME
WLANP2PNAME=$WLANP2PNAME
USB0IP=$USB0IP
USB0IPSUBADDR1=$USB0IPSUBADDR1
APIPADDR=$APIPADDR
APSSID=$APSSID
APHWMODE=$APHWMODE
APCHAN=$APCHAN
APHT=$APHT
APCC=$APCC
APBSSID=$APBSSID
CLEANTRACK_MODE=$CLEANTRACK_MODE
INSTALLED_RADIOS="$INSTALLED_RADIOS"
SYSTEM_ACCESS="$SYSTEM_ACCESS"
DEV_MODE="$DEV_MODE"
CLMODE="$CLMODE"
CLIPADDR="$CLIPADDR"
CLNETMASK="$CLNETMASK"
CLGW="$CLGW"
CLDNSSC="$CLDNSSC"
CLDNSNS1="$CLDNSNS1"
CLDNSNS2="$CLDNSNS2"
CLREGDOMAIN="$CLREGDOMAIN"
DHCPCDTIMEOUT="$DHCPCDTIMEOUT"
ETH0MODE="$ETH0MODE"
ETH0IPADDR="$ETH0IPADDR"
CONNECTIVITY_SERVICES_MODE="$CONNECTIVITY_SERVICES_MODE"
BOOTCOUNT="$BOOTCOUNT"
EXTRA_LANGUAGE="$EXTRA_LANGUAGE"

EOF

display_vars
cfg_network
sync
echo "Provisioning of $HOSTNAME Complete"
[ -n "$MESSAGE" ] && echo $MESSAGE

# everything executed successfully
# exit with code 0
exit 0
