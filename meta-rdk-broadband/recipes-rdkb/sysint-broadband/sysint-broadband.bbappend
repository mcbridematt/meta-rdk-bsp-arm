# This is just to satisfy Yocto's want for a valid source
# All relevant files to this port are maintained in this layer
SRC_URI:append = " \
    ${CMF_GIT_ROOT}/rdkb/devices/raspberrypi/sysint;module=.;protocol=${CMF_GIT_PROTOCOL};branch=${CMF_GIT_BRANCH};destsuffix=git/devicegenericarm;name=sysintdevicegenericarm \
"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# These files relate to managing RDK related btrfs volumes (/nvram, /rdklogs etc.)
SRC_URI:append = "file://btrfs-subvolume.service \
                  file://nvram-subvol-init.sh \
                  file://resize-disk.sh \
                  "

SRCREV_sysintdevicegenericarm = "${AUTOREV}"
SRCREV_FORMAT = "sysintgeneric_sysintdevicegenericarm"

RDEPENDS:${PN}:append = " gptfdisk util-linux btrfs-tools multipath-tools"
do_install:append() {
    install -d ${D}${systemd_unitdir}/system
    install -m 0755 ${S}/device/lib/rdk/* ${D}${base_libdir}/rdk
    install -m 0755 ${S}/rfc.service ${D}${base_libdir}/rdk
    install -m 0755 ${S}/utils.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/getpartnerid.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/device/systemd_units/* ${D}${systemd_unitdir}/system/
    echo "BOX_TYPE=genericarm" >> ${D}${sysconfdir}/device.properties
    echo "MODEL_NAME=RPI" >> ${D}${sysconfdir}/device.properties

    ${@bb.utils.contains('DISTRO_FEATURES', 'OneWifi', 'echo "OneWiFiEnabled=true" >> ${D}${sysconfdir}/device.properties', '', d)}
    echo "MODEL_NUM=RPI_MOD" >> ${D}${sysconfdir}/device.properties

    #For rfc Support
    sed -i '/DEVICE_TYPE/c\DEVICE_TYPE=broadband' ${D}${sysconfdir}/device.properties
    sed -i '/LOG_PATH/c\LOG_PATH=/rdklogs/logs/' ${D}${sysconfdir}/device.properties
    #Erouter0 info
    sed -i "/f11/c\       mac=\`ifconfig \$WANINTERFACE | grep HWaddr | cut -d \" \" -f7\`" ${D}${base_libdir}/rdk/utils.sh
    sed -i '/Device.X_CISCO_COM_CableModem.MACAddress/{n;s/.*/    elif [ "$BOX_TYPE" = "XF3" ]; then/}' ${D}${base_libdir}/rdk/utils.sh

    # BTRFS management
    install -d ${D}${base_libdir}/rdk/btrfs
    install -m 0755 ${WORKDIR}/nvram-subvol-init.sh ${D}${base_libdir}/rdk/btrfs
    install -m 0755 ${WORKDIR}/resize-disk.sh ${D}${base_libdir}/rdk/btrfs

    install -m 0644 ${WORKDIR}/btrfs-subvolume.service ${D}${systemd_unitdir}/system

    # The btrfs image is fully read-only, so we need to create these folders ahead of time
    install -d ${D}/nvram
    touch ${D}/nvram/.placeholder
    install -d ${D}/rdklogs
    touch ${D}/rdklogs/.placeholder
    install -d ${D}/rdklogs/logs2
    touch ${D}/rdklogs/logs2/.placeholder
    install -d ${D}/volumes/toplevel
    touch ${D}/volumes/toplevel/.placeholder

    # We will put /nvram2/logs into /rdklogs/logs2
    install -d ${D}/nvram2
    touch ${D}/nvram2/.placeholder
    ln -s -r ${D}/rdklogs/logs2 ${D}/nvram2/logs

    sed -i "/if \[ \! -f \/usr\/bin\/GetConfigFile \]\;then/,+4d" ${D}/rdklogger/logfiles.sh

    # Changing CLOUDURL and DCM_LOG_SERVER_URL values with migrated server
    install -m 0755 ${S}/devicegenericarm/systemd_units/previous-log-backup.service ${D}${systemd_unitdir}/system
    install -m 0755 ${S}/devicegenericarm/lib/rdk/backupLogs.sh ${D}${base_libdir}/rdk
    sed -i -e 's/LOG_SERVER=.*$/LOG_SERVER=xconf.rdkcentral.com/' ${D}${sysconfdir}/dcm.properties
    sed -i -e 's/DCM_LOG_SERVER=.*$/DCM_LOG_SERVER=https:\/\/xconf.rdkcentral.com\/xconf\/logupload.php/' ${D}${sysconfdir}/dcm.properties
    sed -i -e 's/DCM_SCP_SERVER=.*$/DCM_SCP_SERVER=xconf.rdkcentral.com/' ${D}${sysconfdir}/dcm.properties
    sed -i -e 's/HTTP_UPLOAD_LINK=.*$/HTTP_UPLOAD_LINK=https:\/\/xconf.rdkcentral.com\/xconf\/telemetry_upload.php/' ${D}${sysconfdir}/dcm.properties
    sed -i -e 's/DCA_UPLOAD_URL=.*$/DCA_UPLOAD_URL=xconf.rdkcentral.com/' ${D}${sysconfdir}/dcm.properties
    echo "DCM_HTTP_SERVER_URL="https://xconf.rdkcentral.com/xconf/telemetry_upload.php"" >> ${D}${sysconfdir}/dcm.properties
    echo "DCM_LA_SERVER_URL="https://xconf.rdkcentral.com/xconf/logupload.php"" >> ${D}${sysconfdir}/dcm.properties

    install -m 0755 ${S}/getaccountid.sh   ${D}${base_libdir}/rdk
    echo "CLOUDURL="https://xconf.rdkcentral.com/xconf/swu/stb?eStbMac="" >> ${D}${sysconfdir}/include.properties
    sed -i -e 's|^DCM_LOG_SERVER_URL=.*$|DCM_LOG_SERVER_URL=https://xconf.rdkcentral.com/loguploader/getSettings|' ${D}${sysconfdir}/dcm.properties
    install -m 0755 ${S}/devicegenericarm/lib/rdk/StartDCM.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/devicegenericarm/lib/rdk/DCMscript.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/devicegenericarm/lib/rdk/uploadSTBLogs.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/devicegenericarm/lib/rdk/interfaceCalls.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/devicegenericarm/lib/rdk/commonUtils.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/devicegenericarm/lib/rdk/logfiles.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/devicegenericarm/lib/rdk/backupLogs.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/devicegenericarm/lib/rdk/snmpUtils.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/devicegenericarm/lib/rdk/dcaSplunkUpload.sh ${D}${base_libdir}/rdk
    install -m 0755 ${S}/devicegenericarm/lib/rdk/dca_utility.sh ${D}${base_libdir}/rdk

    #log rotate
    install -m 0644 ${S}/logFiles.properties ${D}${sysconfdir}/
    install -m 0755 ${S}/getaccountid.sh   ${D}${base_libdir}/rdk
    install -m 0644 ${S}/dcmlogservers.txt   ${D}/rdklogger/
    sed -i "/if \[ \! -f \/usr\/bin\/GetConfigFile \]\;then/,+4d" ${D}/rdklogger/logfiles.sh
    sed -i "/uploadRDKBLogs.sh/a \ \t \t  \t  uploading_rdklogs" ${D}/rdklogger/rdkbLogMonitor.sh
    sed -i "/uploadRDKBLogs.sh/d " ${D}/rdklogger/rdkbLogMonitor.sh
    sed -i "/upload_nvram2_logs()/i uploading_rdklogs() \n { \n \ \t \t TFTP_RULE_COUNT=\`iptables -t raw -L -n | grep tftp | wc -l\` \n \ \t \t if [ \"\$TFTP_RULE_COUNT\" == 0 ] \n \t \t then \n \ \t \t \t iptables -t raw -I OUTPUT -j CT -p udp -m udp --dport 69 --helper tftp \n \ \t \t \t sleep 2 \n \ \t \t fi \n \ \t \t cd /nvram2/logs \n \ \t \t FILENAME=\`ls *.tgz\` \n \ \t \t tftp -p -r \$FILENAME \$TFTP_SERVER_IP \n } " ${D}/rdklogger/rdkbLogMonitor.sh

    #self heal support
    install -d ${D}/usr/ccsp/tad
    install -m 0755 ${S}/devicegenericarm/lib/rdk/corrective_action.sh ${D}/usr/ccsp/tad
    install -m 0755 ${S}/devicegenericarm/lib/rdk/self_heal_connectivity_test.sh ${D}/usr/ccsp/tad
    install -m 0755 ${S}/devicegenericarm/lib/rdk/resource_monitor.sh ${D}/usr/ccsp/tad
    install -m 0755 ${S}/devicegenericarm/lib/rdk/task_health_monitor.sh ${D}/usr/ccsp/tad
    install -m 0644 ${S}/devicegenericarm/systemd_units/disable_systemd_restart_param.service ${D}${systemd_unitdir}/system
    install -m 0755 ${S}/devicegenericarm/lib/rdk/disable_systemd_restart_param.sh ${D}${base_libdir}/rdk
}


# TODO add back swupdate.service
SYSTEMD_SERVICE:${PN}:append = " btrfs-subvolume.service"
SYSTEMD_SERVICE:${PN}:remove:broadband = "dropbear.service"
SYSTEMD_SERVICE:${PN}:remove:broadband = "ntp-data-collector.service"
SYSTEMD_SERVICE:${PN}:bootbroadband:append = " boot-time-upload.service monitor-upload.service"

FILES:${PN}:append = " ${systemd_unitdir}/system/* /usr/ccsp/tad/* /nvram/.placeholder /rdklogs/.placeholder /volumes/toplevel/.placeholder"
FILES:${PN}:append = " /rdklogs/logs2/.placeholder /nvram2/.placeholder /nvram/logs /nvram2/logs"
FILES:${PN}:append:bootbroadband = " ${systemd_unitdir}/system/*"
