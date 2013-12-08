#!/bin/bash
PROGNAME=$(basename $0)
PROGDIR=$(dirname $0)
if [ ! "$USER" == "root" ] ; then
	echo "$PROGNAME should be run as root" >&2
	echo "Try: sudo $0 $1 $2" >&2
	exit 1
fi

if [ "$2" == "" ] ; then
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

WANIF=$1 # typically: eth0
LANIF=$2 # typically: wlan0
WANIP=$(ifconfig $WANIF | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
LANIP=$(ifconfig $LANIF | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')

TYPE=$3
if [ "$TYPE" == "" ] ; then
	TYPE=captive
fi

GWIP=$4
if [ "$GWIP" == "" ] ; then
	GWIP=192.168.66.1
fi

open_server(){
	iptables -I internet 1 -t mangle -p tcp -d $1 --dport 80 -j RETURN
	iptables -I internet 1 -t mangle -p tcp -d $1 --dport 443 -j RETURN
}

TYPE=${TYPE^^}
case "$TYPE":
"GATEWAY")
	#everything open
	# start from scratch --  cleanup
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT

	# set up WAN-to-LAN forwarding
	iptables -t filter -A FORWARD -i $WANIF -o $LANIF -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -t filter -A FORWARD -i $LANIF -o $WANIF -j ACCEPT
	iptables -t nat -A POSTROUTING -o $WANIF -j MASQUERADE
	
	/sbin/service iptables save
	;;
"CAPTIVE")
	#everything closed except ports 80/443
	# start from scratch --  cleanup
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -A INPUT -i lo -j ACCEPT

	# set up WAN-to-LAN forwarding
	iptables -t filter -A FORWARD -i $WANIF -o $LANIF -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -t filter -A FORWARD -i $LANIF -o $WANIF -j ACCEPT
	iptables -t nat -A POSTROUTING -o $WANIF -j MASQUERADE

	iptables -t mangle -F
	iptables -t mangle -X
	# Redirect to nginx server
	iptables -t mangle -N internet
	iptables -t mangle -A PREROUTING -p tcp --dport 80 -j internet
	iptables -t mangle -A internet -j MARK --set-mark 99
	iptables -t nat -A PREROUTING -p tcp -m mark --mark 99 -j DNAT --to-destination $LANIP

	# Domain Whitelisting
	open_server www.brightfish.be
	# open_server itunes.apple.com
	# open_server play.google.com
	# open_server ssl.gstatic.com
	# open_server fonts.googleapis.com
	# open_server ajax.googleapis.com
	
	/sbin/service iptables save

	;;
esac
