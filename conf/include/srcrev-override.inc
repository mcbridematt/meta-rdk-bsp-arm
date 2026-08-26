# 2026-08-05 utopia to develop (after 2.8.0) to sync with
# proposed upstream merge
# 2026-08-25 bumped to 2.8.1, upstream merge still pending
# We cannot override the SRCREV:pn-utopia defined in meta-rdk-broadband
# directly, so these need to be cited in the utopia.bbappend and
# utopia-headers.bbappend
GENERIC_ARM_UTOPIA_SRCREV = "adc857addde87240b8adc504b01e5861807d18a4"
GENERIC_ARM_UTOPIA_PV = "2.8.1"

# 2026-08-26 Some Ethernet agent patches upstreamed
# https://github.com/rdkcentral/ethernet-agent/pull/64
GENERIC_ARM_ETH_AGENT_SRCREV = "779663d6bc585952bf78a9df043347c4f91c3975"
GENERIC_ARM_ETH_AGENT_PV = "2.5.0"