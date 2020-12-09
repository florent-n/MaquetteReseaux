#!/bin/sh
TMP=`realpath $0`
PATH_CURRENT=`dirname $TMP`
WRAPPER=$PATH_CURRENT/../script/wrapper
L3_IMG=$PATH_CURRENT/../script/i86bi-linux-l3-adventerprisek9-15.2.4M1.bin
L2_IMG=$PATH_CURRENT/../script/i86bi-linux-l2-adventerprisek9-15.2a.bin
IOU2NET=$PATH_CURRENT/../script/iou2net.pl
HOSTNAME=`hostname`
PHYS_INTERFACE="ens192"
TAP_INT_NAME="bgp_"
OVS_BRIDGE_NAME="ovs-bgp"

#Tap number
MAX=36
for i in `seq 1 $MAX`;
do
ovs-vsctl del-port ${OVS_BRIDGE_NAME} ${TAP_INT_NAME}$i
ip link set down dev ${TAP_INT_NAME}$i
ip tuntap del mode tap dev ${TAP_INT_NAME}$i
ip tuntap add mode tap dev ${TAP_INT_NAME}$i
ip link set up dev ${TAP_INT_NAME}$i
done

ovs-vsctl del-port ${OVS_BRIDGE_NAME} ${PHYS_INTERFACE}
ovs-vsctl del-br ${OVS_BRIDGE_NAME}

cp $PATH_CURRENT/Gen-Netmap-R0-template $PATH_CURRENT/Gen-Netmap-R0.sh
sed -i "s/HOSTNAME_VAR/$HOSTNAME/g" $PATH_CURRENT/Gen-Netmap-R0.sh
$PATH_CURRENT/Gen-Netmap-R0.sh $i > NETMAP

$WRAPPER -m $L2_IMG -p 6001 -- -s0 -e9 -m 2048 -n 512 -c $PATH_CURRENT/startup-R0.txt 996 &

sleep 30;
ovs-vsctl add-br ${OVS_BRIDGE_NAME}
for i in `seq 1 $MAX`;
do
$IOU2NET -t ${TAP_INT_NAME}$i -p $((i+600)) &
ovs-vsctl add-port ${OVS_BRIDGE_NAME} ${TAP_INT_NAME}$i
ovs-vsctl set port ${TAP_INT_NAME}$i tag=$i
done
ovs-vsctl add-port ${OVS_BRIDGE_NAME} ${PHYS_INTERFACE}
ovs-vsctl set port ${PHYS_INTERFACE} vlan_mode=trunk
ip link set up dev $PHYS_INTERFACE

