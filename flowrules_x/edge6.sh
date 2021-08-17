# Tawannnnnnn :)
# Edited from P'Prik's repo
# edge2.sh

# wlan2: SDN-Controlplane
edge1_control_mac="98:48:27:e2:bf:04"
edge2_control_mac="98:48:27:e2:c1:00"
edge3_control_mac="98:48:27:e0:21:2a"
edge4_control_mac="98:48:27:e2:c2:f8"
edge5_control_mac="98:48:27:e0:1d:f4"
edge6_control_mac="98:48:27:e2:e8:c7"

# wlan1: meowmeow
edge1_data_mac="98:48:27:de:a2:ca"
edge2_data_mac="98:48:27:e1:3b:4e"
edge3_data_mac="98:48:27:de:8f:37"
edge4_data_mac="98:48:27:de:9e:2c"
edge5_data_mac="98:48:27:e0:22:92"
edge6_data_mac="98:48:27:de:a8:99"

superedge_control_mac="98:48:27:e2:e3:3a"
superedge_data_mac="98:48:27:e0:1a:fe"

superedge_control_ip="10.0.0.10"
superedge_data_ip="192.168.2.10"

edge1_control_ip="10.0.0.1"
edge2_control_ip="10.0.0.2"
edge3_control_ip="10.0.0.3"
edge4_control_ip="10.0.0.4"
edge5_control_ip="10.0.0.5"
edge6_control_ip="10.0.0.6"
edge6_control_ip="10.0.0.6"

edge1_data_ip="192.168.2.1"
edge2_data_ip="192.168.2.2"
edge3_data_ip="192.168.2.3"
edge4_data_ip="192.168.2.4"
edge5_data_ip="192.168.2.5"
edge6_data_ip="192.168.2.6"

broadcast="ff:ff:ff:ff:ff:ff"

control_interface="wlan2"
data_interface="wlan1"

superedge_control_interface="wlx984827e2e33a"
superedge_data_interface="wlx984827e01afe"


sleep 3
sudo ovs-vsctl --if-exist del-br br0
sudo ovs-vsctl --if-exist del-br br1

sudo ovs-vsctl add-br br0
sudo ovs-vsctl add-br br1

sudo ovs-vsctl set bridge br0 other-config:datapath-id=1000000000000006
sudo ovs-vsctl set bridge br1 other-config:datapath-id=1000000000000060

sudo ovs-vsctl set bridge br0 datapath_type=netdev
sudo ovs-vsctl set bridge br1 datapath_type=netdev

sudo ovs-vsctl add-port br0 $control_interface -- set Interface $control_interface ofport_request=1
sudo ovs-vsctl add-port br1 $data_interface -- set Interface $data_interface ofport_request=2


sudo ifconfig $control_interface 0
sudo ifconfig $data_interface 0
sudo ifconfig br0 $edge6_control_ip netmask 255.255.255.0 up
sudo ifconfig br1 $edge6_data_ip netmask 255.255.255.0 up
sudo iptables -A INPUT -i $control_interface -j DROP #Required to do only OpenVswitch in userspace mode
sudo iptables -A FORWARD -i $control_interface -j DROP #Required to do only OpenVswitch in userspace mode
sudo iptables -A INPUT -i $data_interface -j DROP #Required to do only OpenVswitch in userspace mode
sudo iptables -A FORWARD -i $data_interface -j DROP #Required to do only OpenVswitch in userspace mode

#Connect to RYU controller
sudo ovs-vsctl set-controller br0 tcp:$superedge_control_ip:6633
sudo ovs-vsctl set controller br0 connection-mode=out-of-band
sudo ovs-vsctl set-fail-mode br0 secure
sudo ovs-vsctl set bridge br0 stp_enable=true

sudo ovs-vsctl set-controller br1 tcp:$superedge_control_ip:6633
sudo ovs-vsctl set controller br1 connection-mode=out-of-band
sudo ovs-vsctl set-fail-mode br1 secure
sudo ovs-vsctl set bridge br1 stp_enable=true


#Receive the incoming control and data traffic to edge3 @ edge6
sudo ovs-ofctl add-flow br0 arp,priority=100,in_port=1,dl_src=$edge3_control_mac,arp_tpa=$edge6_control_ip,actions=LOCAL
sudo ovs-ofctl add-flow br1 arp,priority=100,in_port=2,dl_src=$edge3_data_mac,arp_tpa=$edge6_data_ip,actions=LOCAL

sudo ovs-ofctl add-flow br0 ip,priority=100,in_port=1,dl_src=$edge3_control_mac,nw_dst=$edge6_control_ip,actions=LOCAL
sudo ovs-ofctl add-flow br1 ip,priority=100,in_port=2,dl_src=$edge3_data_mac,nw_dst=$edge6_data_ip,actions=LOCAL


#send the control and data packet from edge6 to edge3 and superedge

sudo ovs-ofctl add-flow br0 arp,priority=100,in_port=LOCAL,arp_tpa=$edge3_control_ip,actions=output:1
sudo ovs-ofctl add-flow br0 ip,priority=100,in_port=LOCAL,nw_dst=$edge3_control_ip,actions=output:1
sudo ovs-ofctl add-flow br0 arp,priority=100,in_port=LOCAL,nw_dst=$superedge_control_ip,actions="resubmit(,2)"
sudo ovs-ofctl add-flow br0 ip,priority=100,in_port=LOCAL,nw_dst=$superedge_control_ip,actions="resubmit(,2)"


sudo ovs-ofctl add-flow br1 arp,priority=100,in_port=LOCAL,arp_tpa=$edge3_data_ip,actions=output:2
sudo ovs-ofctl add-flow br1 ip,priority=100,in_port=LOCAL,nw_dst=$edge3_data_ip,actions=output:2
sudo ovs-ofctl add-flow br1 arp,priority=100,in_port=LOCAL,nw_dst=$superedge_data_ip,actions="resubmit(,2)"
sudo ovs-ofctl add-flow br1 ip,priority=100,in_port=LOCAL,nw_dst=$superedge_data_ip,actions="resubmit(,2)"


#Table 2 is to rewrite the destination MAC address into edge3 MAC address @ control plane
sudo ovs-ofctl add-flow br0 table=2,actions=mod_dl_dst:$edge3_control_mac,"load:0->OXM_OF_IN_PORT[],resubmit(,5)"
#Table 2 is to rewrite the destination MAC address into edge1 MAC address @ data plane
sudo ovs-ofctl add-flow br1 table=2,actions=mod_dl_dst:$edge3_data_mac,"load:0->OXM_OF_IN_PORT[],resubmit(,5)"


#Table 5 is to forward to wireless interface @ control plane
sudo ovs-ofctl add-flow br0 table=5,actions=output:1
#Table 5 is to forward to wireless interface @ data plane
sudo ovs-ofctl add-flow br1 table=5,actions=output:2

#To prevent the infinite loop @ control plane
sudo ovs-ofctl add-flow br0 priority=1,in_port=1,actions=drop
#To prevent the infinite loop @ data plane
sudo ovs-ofctl add-flow br1 priority=1,in_port=2,actions=drop


sudo sysctl -p
