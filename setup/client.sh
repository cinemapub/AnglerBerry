#!/bin/bash
PROGNAME=$(basename $0)
DIRNAME=$(dirname $0)
VERSION="0.1 (Nov 2013)"
AUTHOR="Peter Forret"
if [ "$1" == "" ] ; then
	echo "$PROGNAME $VERSION - $AUTHOR" >&2
	echo "Usage: $PROGNAME [add|del|list] [IP]" >&2
	echo "       $PROGNAME add [IP]: add IP address of this client to list of accepted clients (surf anywhere)" >&2
	echo "       $PROGNAME del [IP]: remove IP address of this client from list of accepted clients" >&2
	echo "       $PROGNAME list: list clients that are accepted or not" >&2
	exit 0
fi

if [ ! "$USER" == "root" ] ; then
	echo "$PROGNAME $VERSION - $AUTHOR" >&2
	echo "Error: $PROGNAME should be run as root" >&2
	echo "       try [sudo $0]" >&2
	exit 1
fi

ACTION=$1

rmtrack(){
          /usr/sbin/conntrack -L -p tcp 2>/dev/null \
        | grep ESTAB \
        | grep $1 \
        | grep 'dport=80' \
        | awk \
                "{ system(\"conntrack -D --orig-src $1 --orig-dst \" \
                    substr(\$6,5) \" -p tcp --orig-port-src \" substr(\$7,7) \" \
                    --orig-port-dst 80\"); print \"Rem: \" substr(\$6,5)}"
}


case "${ACTION^^}" in
"ADD")
	IP=$2
	MAC=$(/usr/sbin/arp -an $IP | awk '/ether/ {print $4}')
	MAC=${MAC^^}
	echo "IP:  [$IP]"
	echo "MAC: [$MAC]"
	echo "DO:  add $MAC line to iptables"
	iptables -I internet 1 -t mangle -m mac --mac-source $MAC -j RETURN
	rmtrack $IP
	sleep 1
	;;
"DEL")
	IP=$2
	MAC=$(/usr/sbin/arp -an $IP | awk '/ether/ {print $4}')
	MAC=${MAC^^}
	echo "IP:  [$IP]"
	echo "MAC: [$MAC]"
	echo "RUN: DELETE CLIENT"
	while [ ! $(iptables -t mangle -L -n | grep $MAC | wc -l) == 0 ] ; do
		echo "DO:  remove $MAC line from iptables"
		iptables -D internet -t mangle -m mac --mac-source $MAC -j RETURN
	done	
	rmtrack $IP
	sleep 1
	;;
"LIST")
	ACCMAC=$(iptables-save | awk '/mac-source/ {printf "%s ",$6}')
	if [ ! "$ACCMAC" == "" ] ; then
		ACCMAC=${ACCMAC^^} 
		/usr/sbin/arp -an -i wlan0 | awk "{ if(\"$ACCMAC\" ~ toupper(\$4)){print \$2,\$4,\"IN\"}else{ print \$2,\$4,\"OUT\"}}"
	else
		echo "No whitelisted clients" >&2
	fi
	;;
*)
	echo "Error: unknown command [$ACTION]" >&2
	exit 1
esac
