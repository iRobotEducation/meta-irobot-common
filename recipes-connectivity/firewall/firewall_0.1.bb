DESCRIPTION = "firewall"
PRIORITY = "required"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
RDEPENDS_${PN} += "iptables"
FILESEXTRAPATHS_prepend = "${THISDIR}/${PN}/${ROBOT}:"

PR_append = ".1"

SRC_URI = " \
          file://firewall.init \
          file://iptables.conf \
          file://default.rules \
          file://production.rules \
          file://beta.rules \
          "

S = "${WORKDIR}"

inherit update-rc.d

INITSCRIPT_NAME = "firewall.init"
INITSCRIPT_PARAMS = "start 30 S ."

do_install() {
  install -d ${D}${sysconfdir}/init.d
  install -m 0755 ${S}/firewall.init  ${D}${sysconfdir}/init.d
  install -d ${D}${sysconfdir}/iptables
  install -m 0755 ${S}/beta.rules  ${D}${sysconfdir}/iptables/
  install -m 0755 ${S}/default.rules  ${D}${sysconfdir}/iptables/
  install -m 0755 ${S}/production.rules  ${D}${sysconfdir}/iptables/
  install -m 0755 ${S}/iptables.conf  ${D}${sysconfdir}/iptables/
}

FILES_${PN} += "${sysconfdir}/*"
