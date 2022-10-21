FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI += "\
        file://wpa_supplicant.conf-sane \
"
do_install_append() {
        install -d ${D}${sysconfdir}/
        install -m 0440 ${WORKDIR}/wpa_supplicant.conf-sane ${D}${sysconfdir}/wpa_supplicant.conf.default
}
