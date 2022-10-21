#! /bin/sh

###############################
# provision firmware
###############################

[ "$MSG" ] || MSG="Initial configuration complete"
[ "$RESET" ] || RESET="0"

###############################
# hostname
###############################
cfg_hostname() {

   if [ x$RID == "xunknown" ]; then
     HOSTNAME="${PRODUCT}-${SERIAL}"
   else
     # be set to iRobot-<robot id>.
     HOSTNAME="iRobot-${RID}"
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
   grep -q ${HOSTNAME} /etc/hosts
   if [ $? -eq 1 ]; then
     # new hostname is not in the hosts file, put it there
     echo "127.0.0.1	${HOSTNAME}" >> /etc/hosts
   fi

   grep -q localhost /etc/hosts
   if [ $? -eq 1 ]; then
     # localhosts is not in the hosts file, put it there
     echo "127.0.0.1	localhost" >> /etc/hosts
   fi
   hostname -F /etc/hostname
}

###############################
# modify hostapd settings
###############################
cfg_hostapd() {
   grep -s -q bssid /etc/hostapd.conf
   if [ $? -ne 0 ] ; then
     # hostapd.conf does not have a bssid entry.  create one.
     # bssid is used to set the mac addr for the AP.
     #
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
       # add the bssid entry to the hostapd.conf file
       echo "bssid=$oc1:$oc2:$oc3:$oc4:$oc5:$oc6" >> /etc/hostapd.conf
       sync
     fi
   fi
   grep -s -q interface /etc/hostapd.conf
   if [ $? -ne 0 ] ; then
     # hostapd.conf does not have any lines with the key word interfaces.
     # the file is likely corrupt or empty.
     # bring in the default hostapd.conf file
     cp /etc/hostapd.conf.default /etc/hostapd.conf > /dev/null 2>&1
     # try again
     grep -s -q interface /etc/hostapd.conf
     if [ $? -ne 0 ] ; then
       # create a bare minimum hostapd file
       echo "ssid=$APSSID" > /etc/hostapd.conf
       echo "channel=$APCHAN" >> /etc/hostapd.conf
       echo "hw_mode=$APHWMODE"  >> /etc/hostapd.conf
       echo "ht_capab=$APHT" >> /etc/hostapd.conf
       echo "interface=$WLANAPNAME" >> /etc/hostapd.conf
       return
     fi
   fi
   # update apssid
   cp /etc/hostapd.conf /tmp/hostapd.conf
   sed --follow-symlinks -i -e "s/^ssid=.*/ssid=$APSSID/" /tmp/hostapd.conf
   # update channel
   sed --follow-symlinks -i -e "s/^channel=.*/channel=$APCHAN/" /tmp/hostapd.conf
   sed --follow-symlinks -i -e "s/^hw_mode=.*/hw_mode=$APHWMODE/" /tmp/hostapd.conf
   sed --follow-symlinks -i -e "s/^ht_capab=.*/ht_capab=$APHT/" /tmp/hostapd.conf
   sed --follow-symlinks -i -e "s/^interface=.*/interface=$WLANAPNAME/" /tmp/hostapd.conf
   sed --follow-symlinks -i -e "s/^country_code=.*/country_code=$APCC/" /tmp/hostapd.conf
   cp /tmp/hostapd.conf /etc/hostapd.conf
   rm /tmp/hostapd.conf
   sync
}

###############################
# configure development mode
###############################
cfg_devmode() {
   if [ "x$1" == "xenabled"  ] ; then
     DEV_MODE=$1
   elif [ "x$1" == "xdisabled"  ] ; then
     DEV_MODE=$1
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
   sed --follow-symlinks -i -e "s/^start.*/start  $baseip.20/" /tmp/udhcpd.conf
   sed --follow-symlinks -i -e "s/^end.*/end  $baseip.50/" /tmp/udhcpd.conf

   cat /tmp/udhcpd.conf | awk 'match($0, /^opt([ion]*)([\ \t]+)dns([\ \t]+)192.*/, matches) {print }' \
       | while read var;do if [ -n "$var" ]; then sed --follow-symlinks -i -e "s/$var/#$var/" /tmp/udhcpd.conf;fi;done

   cat /tmp/udhcpd.conf | awk 'match($0, /^opt([ion]*)([\ \t]+)router([\ \t]+)192.168.10.2/, matches) {print }' /tmp/udhcpd.conf \
       | while read var;do if [ -n "$var" ]; then sed --follow-symlinks -i -e "s/$var/opt router 192.168.10.1/" /tmp/udhcpd.conf;fi;done

   cat /tmp/udhcpd.conf | awk 'match($0, /^opt([ion]*)([\ \t]+)wins([\ \t]+)192.168.10.*/, matches) {print }' /tmp/udhcpd.conf \
       | while read var;do if [ -n "$var" ]; then sed --follow-symlinks -i -e "s/$var/#$var/" /tmp/udhcpd.conf ;fi;done

   cat /tmp/udhcpd.conf | awk 'match($0, /^opt([ion]*)([\ \t]+)dns([\ \t]+)129.219.13.*/, matches) {print }' /tmp/udhcpd.conf \
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
     CFGCLDND="down killall -9 udhcpc"
     CFGCLGW="#"
     CFGCLNS1="#"
     CFGCLNS2="#"
     CFGCLSC="#"
     CFGCLRMR="#"
     CFGCLTS="#"
     CFGCLUP2="up /usr/sbin/dhcpcd $WLANCLNAME -t $DHCPCDTIMEOUT -o domain_name_servers -h \`hostname\` --noipv4ll -b -d >/dev/null 2>&1"
     CFGCLDN2="down ps ax | grep -q \"[d]hcpcd\" && killall -9 dhcpcd"
     CFGMODE="manual"
   fi

   # if CLREGDOMAIN passed with NULL value, then it is an indication to clear
   # the current REG Domain set in the provisioning for 80211d precedence
   # if --clregdomain is not called in provision and we find CLREGDOMAIN
   # set in provisioning file from previous setting, then set that country
   # automatically to be used at bootup. User space apps who controls Reg
   # Domain settings knows the precedence and country code to be used based on
   # the scenario. In this case it is connectivity binaries
   PRE_UP_REG_DOMAIN=
   if [[ "${CLREGDOMAIN}" != "#" ]]; then
        PRE_UP_REG_DOMAIN="pre-up iw reg set $CLREGDOMAIN"
   fi

   cat << EOF > /etc/network/interfaces

# /etc/network/interfaces -- configuration file for ifup(8), ifdown(8)

# The loopback interface
auto lo
iface lo inet loopback

# Wireless interface
auto $WLANCLNAME
iface $WLANCLNAME inet dhcp
    pre-up /usr/bin/set_mac.sh || true
    wireless_mode managed
    wireless_essid any
    wpa-driver wext
    wpa-conf /etc/wpa_supplicant.conf
    udhcpc_opts -t 1 -T 1 -b -S -x hostname:`hostname`

#auto $WLANAPNAME
iface $WLANAPNAME inet static
    pre-up ifconfig $WLANAPNAME txqueuelen 50
    pre-up ip addr flush dev $WLANAPNAME
    address $APIPADDR
    netmask 255.255.255.0
    up hostapd -B /etc/hostapd.conf
    up udhcpd /etc/udhcpd.conf
    down killall -9 hostapd
    down killall -9 udhcpd

# Wired interface
auto eth0
iface eth0 inet dhcp

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
   echo " --radiolist <radios>           - quoted list of wifi radios (ie \"wlan0 wlan1\")"
   echo " --devmode <mode>               - development mode (disabled/enabled)"
   echo " --sysaccess <mode>             - system access (locked/unlocked/beta)"
   #echo " --product <id>                 - product id"
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
   echo "   AP RADIO        : ${APHWMODE}/${APCHAN}/${APHT}/${APSSID}/$APCC"
   echo "   AP IP ADDR      : ${APIPADDR}"
   echo "   CL IP           : ${CLMODE}/${CLIPADDR}/${CLNETMASK}/${CLGW}"
   echo "   CL DNS          : ${CLDNSSC}/${CLDNSNS1}/${CLDNSNS2}"
   echo "   CL DHCPCD T/O   : ${DHCPCDTIMEOUT}"
   echo "   CL REG DOMAIN   : ${CLREGDOMAIN}"
   echo "   SYSTEM_ACCESS   : $SYSTEM_ACCESS"
   echo "   DEVELOPMENT MODE: $DEV_MODE"
   echo "   RADIO_LIST      : $INSTALLED_RADIOS"
   echo "   HOSTNAME        : $HOSTNAME"
   echo "   ROBOT ID        : $RID"
   echo ""
}

###############################
# Main script
###############################

SERIAL=
# factory default settings start
#
APSSID=irobot-0123456789ABCDEF
APCHAN=11
APHT="[SHORT-GI-20][GF]"
APCC=US
APHWMODE=g
WLANCLNAME=wlan0
WLANAPNAME=wlan1
WLANMONNAME=mon0
APIPADDR="192.168.10.1"
CLMODE="dhcp"
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
      --radiolist) INSTALLED_RADIOS=$2; shift;;
      --devmode) cfg_devmode $2; shift;;
      --sysaccess) cfg_sysaccess $2; shift;;
      -h|--help)  usage;;
      *) echo Invalid parameter: $1; usage;;
   esac
   shift
done

[ "$SERIAL" ] || {
  if [ -f /etc/${WLANCLNAME}_mac ] ; then
    # use the lat 3 bytes of the mac addr as the serial number
    MAC_ADDR=$(cat /etc/${WLANCLNAME}_mac | sed s/://g)
    # use the last 6 digits of MAC_ADDR for the serial number
    SERIAL=${MAC_ADDR:6}
  fi
}

case "$CLMODE" in "static"|"dhcp"|"");;
  *) echo "Error: invalid client IP mode"; usage;;
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
mkdir -p /opt/irobot/config
cat << EOF > /opt/irobot/config/provisioning
# This file was created automatically by /usr/bin/provision
# do not edit manually unless you know what you're doing
SERIAL=$SERIAL
PRODUCT=$PRODUCT
HOSTNAME=$HOSTNAME
WLANCLNAME=$WLANCLNAME
WLANAPNAME=$WLANAPNAME
USB0IP=$USB0IP
APIPADDR=$APIPADDR
APSSID=$APSSID
APHWMODE=$APHWMODE
APCHAN=$APCHAN
APHT=$APHT
APCC=$APCC
CLEANTRACK_MODE=$CLEANTRACK_MODE
INSTALLED_RADIOS="$INSTALLED_RADIOS"
SYSTEM_ACCESS="$SYSTEM_ACCESS"
DEV_MODE="$DEV_MODE"
CLMODE="$CLMODE"
CLIPADDR="$CLIPADDR"
CLMASK="$CLNETMASK"
CLGW="$CLGW"
CLDNSSC="$CLDNSSC"
CLDNSNS1="$CLDNSNS1"
CLDNSNS2="$CLDNSNS2"
CLREGDOMAIN="$CLREGDOMAIN"
DHCPCDTIMEOUT="$DHCPCDTIMEOUT"
CONNECTIVITY_SERVICES_MODE="$CONNECTIVITY_SERVICES_MODE"

EOF

display_vars
cfg_network
sync
echo "Provisioning of $HOSTNAME Complete"
