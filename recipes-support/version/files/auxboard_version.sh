#!/bin/sh
# query the auxilliary board version information

unknown_version() {
  echo Mobility Bootloader Version: unknown
  echo Mobility Version: unknown
  echo Power Version: unknown
  echo Safety Version: unknown
  rm -f /tmp/mos_out.txt > /dev/null 2>&1
  exit
}

if ! [ -f /opt/irobot/bin/mosquitto_sub ]; then
  unknown_version
fi

# Check if file exists and has a size greater than zero
# if not, do mqtt query
if [ ! -s /tmp/mos_out.txt ]; then
  /opt/irobot/bin/mosquitto_sub -t robot/events > /tmp/mos_out.txt 2>/dev/null&
  mosq_sub_pid=$!
  /opt/irobot/bin/mosquitto_pub -t robot/debug -m '{"get" : "subModSwVer"}' > /dev/null 2>&1

  # spawn a background thread to kill mosquitto_sub if it never receives the message
  ( sleep 1; kill -9 $mosq_sub_pid >/dev/null 2>&1 ) &
  wait $mosq_sub_pid
  sync
fi

# Check if file exists and has a size greater than zero
# if not, show unknown version
if [ ! -s /tmp/mos_out.txt ]; then
  unknown_version
fi

# check for integrity of mos_out.txt
grep -q Error /tmp/mos_out.txt
if [ $? -eq 0 ] ;then
  unknown_version
fi

grep -q subModSwVer /tmp/mos_out.txt
if [ $? -ne 0 ] ;then
  # sw version info not found
  unknown_version
else
  # save version info in aux_versions
  aux_versions=$(grep -m 1 subModSwVer /tmp/mos_out.txt)
fi

# use aux_versions to find individual board version info
navv=$(echo ${aux_versions} | awk  -F ',' '{print $1}' | sed -e 's/{\"subModSwVer\":{\"nav\"://' -e 's/\"//g')
mobv=$(echo ${aux_versions} | awk  -F ',' '{print $2}' | sed -e 's/\"mob\"://' -e 's/\"//g')
echo ${aux_versions} | grep -q bmp
if [ $? -eq 0 ]; then
  # bumper version found
  bmpv=$(echo ${aux_versions} | awk  -F ',' '{print $3}' | sed -e 's/\"bmp\"://' -e 's/\"//g')
  pwrv=$(echo ${aux_versions} | awk  -F ',' '{print $4}' | sed -e 's/\"pwr\"://' -e 's/\"//g')
  sftv=$(echo ${aux_versions} | awk  -F ',' '{print $5}' | sed -e 's/\"sft\"://' -e 's/\"//g' -e 's/}//'g)
  mobBtl=$(echo ${aux_versions} | awk  -F ',' '{print $6}' | sed -e 's/\"mobBtl\"://' -e 's/\"//g' -e 's/}//'g)
else
  # no bumper version found
  bmpv=unknown
  pwrv=$(echo ${aux_versions} | awk  -F ',' '{print $3}' | sed -e 's/\"pwr\"://' -e 's/\"//g')
  sftv=$(echo ${aux_versions} | awk  -F ',' '{print $4}' | sed -e 's/\"sft\"://' -e 's/\"//g' -e 's/}//'g)
  mobBtl=$(echo ${aux_versions} | awk  -F ',' '{print $5}' | sed -e 's/\"mobBtl\"://' -e 's/\"//g' -e 's/}//'g)
fi

rm -f /tmp/mos_out.txt > /dev/null 2>&1
if [ -z $navv ]; then
  echo Navigation Version: unknown
else
  echo Navigation Version: $navv
fi
if [ -z $mobBtl ]; then
  echo Mobility Bootloader Version: unknown
else
  echo Mobility Bootloader Version: $mobBtl
fi
if [ -z $mobv ]; then
  echo Mobility Version: unknown
else
  echo Mobility Version: $mobv
fi
if [ -z $pwrv ]; then
  echo Power Version: unknown
else
  echo Power Version: $pwrv
fi
if [ -z $sftv ]; then
  echo Safety Version: unknown
else
  echo Safety Version: $sftv
fi
if [ -z $bmpv ]; then
  echo Bumper Version: unknown
elif [ "x$bmpv" != "xunknown" ]; then
  echo Bumper Version: $bmpv
fi
