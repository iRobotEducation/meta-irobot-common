# These variables are (generally) overridden and/or set by Jenkins

VERSION ?= "0.1.0"
PRODUCT_VERSION ?= "0.1.0_rel"
BUILD_NUMBER ?= "0000"
ROBOT ?= "generic"
JOB_BASE_NAME ?= "sandbox"

IROBOT_OSVERSION ?= "linux+${VERSION}+${JOB_BASE_NAME}+${BUILD_NUMBER}"
IROBOT_PRODUCT_VERSION ?= "${PRODUCT_VERSION}+${JOB_BASE_NAME}+${BUILD_NUMBER}"
