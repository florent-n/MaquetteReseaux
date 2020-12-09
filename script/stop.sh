#!/bin/sh
if [ $# = 2 ]; then
TAP_INT_NAME=$1
OVS_INT_NAME=$2
pkill i86
pkill iou2net

for i in `ip link show| grep "${TAP_INT_NAME}" | grep -v -e "grep" | cut -d " " -f 2 | cut -d ":" -f 1`; do ip tuntap delete mode tap dev $i; done;
ovs-vsctl del-br ${OVS_INT_NAME}
else
echo "Usage: $0 tap_interface_name ovs_bridge_name"
fi;