FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI += " \
          file://0001-ubinize-Exit-with-non-zero-exit-code-on-error.patch \
	  file://0002-ubiformat-Refactor-want_exit-to-be-want_to_continue.patch \
	  file://0003-ubiformat-Add-support-for-no-flag.patch \
	  file://0004-ubiformat-Add-support-for-bad-blocks-threshold-optio.patch \
"

