#!/bin/sh
# Resolve the WAN interface name for obuspa and stores it in EnvironmentFile.

set -u

ENV_DIR=/run/usp-pa
ENV_FILE="${ENV_DIR}/wan.env"

mkdir -p "${ENV_DIR}"
: > "${ENV_FILE}"

IF_NAME="$(sysevent get current_wan_ifname 2> /dev/null)"

# Only trust a name that maps to an interface that really exists.
if [ -z "${IF_NAME}" ] || [ ! -d "/sys/class/net/${IF_NAME}" ]; then
       exit 1
fi

echo "OBUSPA_WAN_IF_NAME=${IF_NAME}" > "${ENV_FILE}"
