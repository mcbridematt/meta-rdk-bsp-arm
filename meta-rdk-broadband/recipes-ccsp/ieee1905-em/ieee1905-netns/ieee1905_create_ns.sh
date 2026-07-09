#!/bin/sh
##################################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
#  Copyright 2025 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##################################################################################

set -e
if [ ! -f "/var/run/netns/ieee1905" ]; then
	ip netns add ieee1905
	ip link add veth1905 type veth peer name eth0 netns ieee1905
	ip link set dev veth1905 master brlan0
	ip link set dev veth1905 up
	ip netns exec ieee1905 ip link set lo up
	ip netns exec ieee1905 ip link set eth0 up
fi
