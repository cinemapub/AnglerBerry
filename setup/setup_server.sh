#!/bin/bash
PROGNAME=$(basename $0)
PROGDIR=$(dirname $0)
if [ "$PROGDIR" == "." ] ; then
	PROGDIR=$(pwd)
fi
. $PROGDIR/lib.sh
NOW=$(date)


if [ ! "$USER" == "root" ] ; then
	echo "$PROGNAME should be run as root" >&2
	echo "Try: sudo $0 $1 $2" >&2
	exit 1
fi

if [ "$0" == "" ] ; then
	echo "$PROGNAME - Nov 2013" >&2
	echo "Usage:   $PROGNAME [WAN IF] [LAN IF] ([TYPE])" >&2
	echo "         [WAN IF]: WAN interface / gets internet via DHCP" >&2
	echo "         [WAN IF]: LAN interface / will set up DHCP server and LAN gateway" >&2
	echo "         [TYPE]:   captive/gateway (default: captive)" >&2
	echo "                   captive: no internet access until approving conditions" >&2
	echo "                   gateway: all clients internet access" >&2
	echo "         [GW IP]:  gateway LAN IP address: 192.168.66.1 " >&2
	echo "Example: $PROGNAME eth0 wlan0 captive 192.168.33.1" >&2
	exit 0
fi

#set -ex
FIRST=$(ask_yn   "Is this the first time you install? (so should I install packages etc...)" )
IFWAN=$(ask_line "WAN interface (connects to internet)" "eth0")
IPWAN=$(ifconfig $IFWAN | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
echo ". WAN SIDE: $IFWAN - $IPWAN"
IFLAN=$(ask_line "LAN interface (lets clients connect)" "wlan0")
IPLAN=$(ifconfig $IFLAN | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
GWIP=$(ask_line "IP address on $IFLAN     (xx.xx.xx.1)" "192.168.66.1")
echo ". LAN SIDE: $IFLAN - $GWIP"
IPRANGE1=$(echo $GWIP | sed "s/\.1$/.100/")
IPRANGE2=$(echo $GWIP | sed "s/\.1$/.255/")
echo ". DHCP: serving IP addresses $IPRANGE1 - $IPRANGE2"
SSID=$(ask_line "Wifi network SSID name" $HOSTNAME )
TYPE=$(ask_line "Gateway type: (captive/gateway)" "captive")

if [ "$FIRST" == "Y" ] ; then
	apt-get -y install hostapd udhcpd php5-cgi nginx
fi

## install DHCP server
customfile ../config/sysctl.conf   /etc/sysctl.conf          "Configure NAT"
customfile ../config/udhcpd.conf   /etc/udhcpd.conf          "Configure DHCP 1/4"
customfile ../config/udhcpd.def    /etc/default/udhcpd       "Configure DHCP 2/4"
customfile ../config/hostapd.conf  /etc/hostapd/hostapd.conf "Configure DHCP 3/4"
customfile ../config/hostapd.def   /etc/default/hostapd      "Configure DHCP 4/4"
echo 1 > /proc/sys/net/ipv4/ip_forward
for f in /proc/sys/net/ipv4/conf/*/rp_filter ; do 
	echo 1 > $f ; 
done
## install network
customfile ../config/interfaces  /etc/network/interfaces     "Configure network"

## INSTALL WEB SERVER

open_server(){
	iptables -I internet 1 -t mangle -p tcp -d $1 --dport 80 -j RETURN
	iptables -I internet 1 -t mangle -p tcp -d $1 --dport 443 -j RETURN
}


TYPE=${TYPE^^}
if [ "$TYPE" == "GATEWAY" ] ; then
	#everything open
	# start from scratch --  cleanup
	echo "*** CONFIGURE AS GATEWAY"
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT

	# set up WAN-to-LAN forwarding
	iptables -t filter -A FORWARD -i $IFWAN -o $IFLAN -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -t filter -A FORWARD -i $IFLAN -o $IFWAN -j ACCEPT
	iptables -t nat -A POSTROUTING -o $IFWAN -j MASQUERADE
fi

if [ "$TYPE" == "CAPTIVE" ] ; then
	set -ex
	#everything closed except ports 80/443
	# start from scratch --  cleanup
	echo "*** CONFIGURE AS CAPTIVE PORTAL"
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -P INPUT ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -A INPUT -i lo -j ACCEPT
	# set up WAN-to-LAN forwarding
	iptables -t filter -A FORWARD -i $IFWAN -o $IFLAN -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -t filter -A FORWARD -i $IFLAN -o $IFWAN -j ACCEPT
	#iptables -p TCP    -A INPUT   -i $IFWAN --dport ssh -j ACCEPT
	iptables -t nat -A POSTROUTING -o $IFWAN -j MASQUERADE

	iptables -t mangle -F
	iptables -t mangle -X
	# Redirect to nginx server
	iptables -t mangle -N internet
	iptables -t mangle -A PREROUTING -p tcp --dport 80 -j internet
	iptables -t mangle -A internet -j MARK --set-mark 99
	iptables -t nat -A PREROUTING -p tcp -m mark --mark 99 -j DNAT --to-destination $GWIP

	# Domain Whitelisting
	# open_server www.brightfish.be
	# open_server itunes.apple.com
	# open_server play.google.com
	# open_server ssl.gstatic.com
	# open_server fonts.googleapis.com
	# open_server ajax.googleapis.com
fi
iptables-save > /etc/iptables.ipv4.nat
