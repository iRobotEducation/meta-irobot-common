PACKAGECONFIG = "${@bb.utils.filter('DISTRO_FEATURES', 'ipv6', d)} ssl libidn proxy threaded-resolver verbose zlib"

