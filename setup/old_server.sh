#!/bin/bash
#

if [ ! "$USER" == "root" ] ; then
	echo "$0 should be run as root - not as $USER!"
	exit 1
fi

if [ "$2" == "" ] ; then
	echo "Usage  : $0 [if_wan] [if_lan]" >&2
	echo "Example: $0 eth0 wlan0 : create wifi access point"
	exit 0
fi

clear

IFWAN=$1
IFLAN=$2
IPLAN=$3
IPWAN=$4
if [ "$IPLAN" == "" ] ; then
	IPLAN=192.168.66.1
fi
IPRANGE1="${IPLAN}00"
IPRANGE2="${IPLAN}99"


echo "======================================================="
echo "======== Setting up Raspberry Pi WiFi hotspot ========="
echo "======================================================="

echo "Installing dependencies"

#apt-get -y -qq install hostapd udhcpd

cd ./config-files
BACKUP=backup_config.$(date +%Y_%d_%m.%k_%M_%S)
if [ ! -d $BACKUP ] ; then
	mkdir $BACKUP
fi
echo "=== Backup in [$BACKUP]"

replacefile(){
	# $1: source file name
	# $2: destination folder
	# $3: text to display
	echo "... $3"
	if [ ! -f $1 ] ; then
		echo "ERROR: source [$1] does not exist"
		exit 1
	fi

	# first take backup
	FNAME=$(basename $1)
	DESTINATION=$2/$FNAME
	if [ -f $DESTINATION ] ; then
		cp $DESTINATION $BACKUP/
	fi

	# now install
	cat $1 \
	| sed "s/%IFWAN/$IFWAN/g" \
	| sed "s/%IFLAN/$IFLAN/g" \
	| sed "s/%IPLAN/$IPLAN/g" \
	| sed "s/%IPRANGE1/$IPRANGE1/g" \
	| sed "s/%IPRANGE2/$IPRANGE2/g" \
	> $DESTINATION
}

echo "Configuring DHCP"
replacefile ./udhcpd.conf /etc "Configure DHCP 1/2"
replacefile ./udhcpd /etc/default "Configure DHCP 2/2"

replacefile ./interfaces /etc/network "Configure interfaces"

replacefile ./hostapd.conf /etc/hostapd "Configuring Access Point 1/2"
replacefile ./hostapd /etc/default "Configuring Access Point 2/2"

replacefile ./sysctl.conf /etc "Configuring NAT"

replacefile ./iptables.ipv4.nat /etc "Configuring iptables"

touch /var/lib/misc/udhcpd.leases

echo "Initialising access point"
service hostapd start
update-rc.d hostapd enable

echo "Initialising DHCP server"
service udhcpd start
update-rc.d udhcpd enable


echo "================================================================"
echo "=================== Configuration complete! ===================="
echo "================================================================"

echo "+++++++++++++++++  REBOOTING in 10 SECONDS  ++++++++++++++++++++"
sleep 10
reboot
