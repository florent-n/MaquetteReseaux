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

echo "\e[36mGenerate NETMAP\e[0m"
#Extrait dernier octet de l'IP de la VM
i=`ip addr show br0 | grep "inet " | sed 's/.*inet *//; s/ .*//' | cut -d "." -f 4 |cut -d "/" -f 1`
#Generate NETMAP which to be different on each VM to avoid MAC conflict of IOU 
#IP start of VM start .21
i=$((i-21))
#Include the hostname before to generate the NETMAP
cp $PATH_CURRENT/Gen-Netmap-template $PATH_CURRENT/Gen-Netmap.sh
sed -i "s/HOSTNAME_VAR/$HOSTNAME/g" $PATH_CURRENT/Gen-Netmap.sh
$PATH_CURRENT/Gen-Netmap.sh $i > NETMAP

echo "\e[36mDelete interface\e[0m"
ovs-vsctl --if-exist del-port ${OVS_BRIDGE_NAME} ${TAP_INT_NAME}4
ovs-vsctl --if-exist del-port ${OVS_BRIDGE_NAME} ${TAP_INT_NAME}5
ovs-vsctl --if-exist del-port ${OVS_BRIDGE_NAME} $PHYS_INTERFACE
ovs-vsctl --if-exist del-br ${OVS_BRIDGE_NAME}
ip link set down dev ${TAP_INT_NAME}4
ip link set down dev ${TAP_INT_NAME}5
ip tuntap del mode tap dev ${TAP_INT_NAME}4
ip tuntap del mode tap dev ${TAP_INT_NAME}5
sleep 2;

echo "\e[36mCreate interface\e[0m"
ip tuntap add mode tap dev ${TAP_INT_NAME}4
ip link set up dev ${TAP_INT_NAME}4
ip tuntap add mode tap dev ${TAP_INT_NAME}5
ip link set up dev ${TAP_INT_NAME}5
echo "\e[36mCreate IOU\e[0m"
$WRAPPER -m $L3_IMG -p 6001 -- -s0 -m 256 -n 256 $((i*10+1)) &
$WRAPPER -m $L3_IMG -p 6002 -- -s0 -m 256 -n 256 $((i*10+2)) &
$WRAPPER -m $L3_IMG -p 6003 -- -s0 -m 256 -n 256 $((i*10+3)) &
#generate right IP to R4 and R5
j=$((i*2+1))

cp "$PATH_CURRENT/startup-RX.txt" startup-R4.txt
sed -i -e "s/192\.0\.2\.X/192\.0\.2\.$j/g" startup-R4.txt
#generate hostname
sed -i -e "s/RX/R4/g" startup-R4.txt

cp "$PATH_CURRENT/startup-RX.txt" startup-R5.txt
sed -i -e "s/192\.0\.2\.X/192\.0\.2\.$((j+1))/g" startup-R5.txt
#generate hostname
sed -i -e "s/RX/R5/g" startup-R5.txt

$WRAPPER -m $L3_IMG -p 6004 -- -s0 -m 256 -n 256 -c startup-R4.txt $((i*10+4)) &
$WRAPPER -m $L3_IMG -p 6005 -- -s0 -m 256 -n 256 -c startup-R5.txt $((i*10+5)) &
$WRAPPER -m $L2_IMG -p 6008 -- -s0 -m 256 -n 256 $((i*10+8)) &
$WRAPPER -m $L2_IMG -p 6009 -- -s0 -m 256 -n 256 $((i*10+9)) &
echo "\e[36mWait 30 s. for each device end to boot\e[0m"
sleep 30;
echo "\e[36mConnect R4 and R5 to real network\e[0m"
$IOU2NET -t ${TAP_INT_NAME}4 -p 1004 &
$IOU2NET -t ${TAP_INT_NAME}5 -p 1005 &
ovs-vsctl add-br ${OVS_BRIDGE_NAME}
ovs-vsctl add-port ${OVS_BRIDGE_NAME} ${TAP_INT_NAME}4
ovs-vsctl add-port ${OVS_BRIDGE_NAME} ${TAP_INT_NAME}5
ovs-vsctl add-port ${OVS_BRIDGE_NAME} $PHYS_INTERFACE
ip link set up dev $PHYS_INTERFACE
ovs-vsctl set port ${TAP_INT_NAME}4 tag=$j
ovs-vsctl set port ${TAP_INT_NAME}5 tag=$((j+1))
ovs-vsctl set port $PHYS_INTERFACE vlan_mode=trunk
ip link set up dev $PHYS_INTERFACE
echo "\e[32m\e[1mFinish\e[0m"
