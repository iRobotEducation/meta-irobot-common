FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI += " \
          file://init \
"

do_configure_append () {
    # replace init file
    cp ${WORKDIR}/init ${S}/init
    # use p2p0 in the config file
    sed -i -e 's,wlan0,p2p0,g' ${S}/hostapd/hostapd.conf
    # remove bssid from the config file
    sed -i -e 's,.*bssid.*,,g' ${S}/hostapd/hostapd.conf

    # set default ssid to Roomba-1234567890123456 in config file
    sed -i '0,/ssid=test/s//ssid=Roomba-1234567890123456/'  ${S}/hostapd/hostapd.conf

    # update WMM parameter
    sed -i '0,/wmm_enabled=1/s//wmm_enabled=0/'  ${S}/hostapd/hostapd.conf

    # update channel number to 6
    sed -i '0,/channel=1/s//channel=6/'  ${S}/hostapd/hostapd.conf

    # Add note for future reference regarding hostapd.conf file change
    sed -i '4 i # NOTE: \
# On the robot, the hostapd.conf file located under /etc folder, will be \
# updated from the provision.sh script and it contains below parameters only \
# ctrl_interface=/var/run/hostapd \
# interface=p2p0 \
# ssid=Roomba-1234567890123456 \
# channel=6 \
# hw_mode=g \
# wmm_enabled=0 \
    ' ${S}/hostapd/hostapd.conf

}

do_install_append () {
	install -d ${D}${sysconfdir}
	# install a default copy of hostapd.conf, for use in error recovery
        install -m 0644 ${S}/hostapd/hostapd.conf ${D}${sysconfdir}/hostapd.conf.default
}

FILES_${PN} += "${sysconfdir}/*"
