#!/bin/bash
#use as yn=$(ask_yn "Should I make a backup?")
	
#set -ex

# from: http://misc.flogisoft.com/bash/tip_colors_and_formatting
normal="\e[0m"
colG="\e[32m"
colB="\e[94m"
colR="\e[31m"
colY="\e[33m"
colO="\e[133m"

ask_yn(){
	# $1 = Question to be asked
	# $2 = Default answer (by default: N)
	# $3 = Timeout (by default: 5 min)
	if [ "$2" == "" ] ; then
		DEF=N
	else
		DEF=$2
	fi
	if [ "$3" == "" ] ; then
		TIMEOUT=300
	else
		TIMEOUT=$3
	fi
	echo -n -e "$colG> $1 [Y/N] $colB>$normal $DEF" >&2
	read -t $TIMEOUT -N 1 YN
	YN=${YN^^}
	if [ ! "$YN" == "Y" ] ; then
		YN=N
	fi
	echo $YN
}

ask_line(){
	# $1 = Question to be asked
	# $2 = Default answer (by default = '')
	# $3 = Timeout (by default: 5 min)
	if [ "$3" == "" ] ; then
		TIMEOUT=300
	else
		TIMEOUT=$3
	fi
	echo -n -e "$colG> $1 $normal " >&2
	if [ "$2" == "" ] ; then
		read -t $TIMEOUT -e -p "> " ANSWER
	else
		read -t $TIMEOUT -e -p "> " -i "$2" ANSWER
	fi
	if [ "$ANSWER" == "" ] ; then
		ANSWER=$2
	fi
	echo $ANSWER
}

ask_password(){
	# $1 = Question to be asked
	# $2 = Timeout (by default: 5 min)
	if [ "$2" == "" ] ; then
		TIMEOUT=300
	else
		TIMEOUT=$3
	fi
	echo -n -e "$colG> $1 (hidden) $colB>$normal " >&2
	read -t $TIMEOUT -s -e ANSWER
	echo $ANSWER
	}
	
customfile(){
	# $1: source file name
	# $2: destination file name
	# $3: text to display
	# $4: backup folder (if any)
	BNAME=$(basename $2)
	echo ". $3 ($BNAME)"
	if [ ! -f $1 ] ; then
		echo "ERROR: source [$1] does not exist"
		exit 1
	fi

	# first take backup
	DESTINATION=$2
	BACKUP=$4
	if [ -f $DESTINATION ] ; then
		if [ ! "$BACKUP" == "" ] ; then
			cp $DESTINATION $BACKUP/
		fi
	fi

	# now install
	cat $1 \
	| sed "s/%IFWAN/$IFWAN/g" \
	| sed "s/%IFLAN/$IFLAN/g" \
	| sed "s/%IPLAN/$GWIP/g" \
	| sed "s/%SSID/$SSID/g" \
	| sed "s/%IPRANGE1/$IPRANGE1/g" \
	| sed "s/%IPRANGE2/$IPRANGE2/g" \
	> $DESTINATION
}
