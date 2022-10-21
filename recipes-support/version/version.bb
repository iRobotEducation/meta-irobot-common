DESCRIPTION = "version"
PRIORITY = "required"
LICENSE="GPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"
#DEPENDS+="irobot-utils"

# set IROBOT_OSVERSION from default values Jenkins (via the environment)
inherit irobot-version

# replace : with - in PRODUCT_VERSION, avoids build failure from sed in base yocto code
PR_VERSION = "${@d.getVar('PRODUCT_VERSION').replace(':', '-')}"
PR = "${PR_VERSION}_${VERSION}"
# I'm not sure what Frank wanted to do by assigning "${ROBOT}" to PV, perhaps it had
# something to do with the package version used when producing installable packages for
# different robots.  I am finding that it interfers with building code for Daredevil vs
# create3 (by changing ROBOT), so I am removing this.
#PV = "${ROBOT}"
SSTATE_CREATE_PKG = "1"

SRC_URI = " \
          file://version.sh \
          file://auxboard_version.sh \
          file://app_sn.sh \
          file://get_proj_mob_pin_det.sh \
"

inherit deploy

# depends on machine as we have diff dependencies for each
PACKAGE_ARCH = "${MACHINE_ARCH}"

S = "${WORKDIR}"

do_compile[vardepsexclude] = "DATETIME"

do_compile() {
    echo "OS_VERSION=${IROBOT_OSVERSION}" > ${S}/version.env
    echo "OS_BUILD_TIMESTAMP=${DATETIME}" >> ${S}/version.env
    echo "OS_MACHINE=${MACHINE}" >> ${S}/version.env
    echo "BUILD_TYPE=${BUILD_TYPE}" >> ${S}/version.env
    echo "if [ -f /opt/irobot/identity.env ]; then"  >> ${S}/version.env
    echo " . /opt/irobot/identity.env"  >> ${S}/version.env
    echo "else"  >> ${S}/version.env
    echo "  PRODUCT_VERSION=${IROBOT_PRODUCT_VERSION}" >> ${S}/version.env
    echo "fi"  >> ${S}/version.env
}

do_install() {
    install -d ${D}/opt/irobot
    install -m 755 ${S}/version.env -D ${D}/opt/irobot/version.env
    install -d ${D}${bindir}
    install -m 755 ${S}/version.sh -D ${D}${bindir}/version
    install -m 755 ${S}/auxboard_version.sh -D ${D}${bindir}/
    install -m 755 ${S}/app_sn.sh -D ${D}${bindir}/
    install -m 755 ${S}/get_proj_mob_pin_det.sh -D ${D}${bindir}/
    # add an identity file that specifies the product model
    echo MODEL=${ROBOT}                               > ${D}/opt/irobot/identity.env
    echo "PRODUCT_VERSION=${IROBOT_PRODUCT_VERSION}" >> ${D}/opt/irobot/identity.env
}

do_deploy() {
    install -d ${DEPLOYDIR}
    install ${S}/version.env ${DEPLOYDIR}
}

addtask deploy after do_compile

FILES_${PN} += "/opt/irobot/* ${bindir}/*"
