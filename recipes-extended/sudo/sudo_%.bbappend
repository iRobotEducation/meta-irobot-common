FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"
PR_append .= ".4"

SRC_URI_append = "\
           file://sudoers.irobot \
           "
do_install_append() {
        install -d ${D}${sysconfdir}/
        install -m 0440 ${WORKDIR}/sudoers.irobot ${D}${sysconfdir}/sudoers
}
