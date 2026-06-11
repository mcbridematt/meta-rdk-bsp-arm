require ccsp_common_genericarm.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

CFLAGS:remove = "-DPLATFORM_RASPBERRYPI"
