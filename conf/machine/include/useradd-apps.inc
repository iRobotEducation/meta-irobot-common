# This file is intended to be included in recipes that needs to add apps
# user to provide ownership/permission of some files to apps user/group
inherit useradd
USERADD_PACKAGES = "${PN}"
USERADD_PARAM_${PN} = "--uid 1000 --user-group --password '' apps"
