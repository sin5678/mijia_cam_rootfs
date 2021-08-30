#!/bin/sh

# Written by Yin Kangkai for network status governor
#
# Description of the variables
#
# INTERVAL = How long will wait (sleep) between commands
# STATUS = 0 good, 1 missed ip, 2 wifi scanning, 3 AP mode, 4 no wlan0 (fatal error), 5 missing wpa, 6 missing wpa_event, 7 missing gateway, 100 unknown

WPASTATE=""
MYIP="0.0.0.0"
PUBLICIP=""
INTERVAL="60"
STATUS="0"
COUNT=0
COUNT_MAX=3
WPA_SUPPLICANT_CONFIG_FILE="/tmp/wpa_supplicant.conf"
model=`factory get model`

interval() {
	sleep $INTERVAL
}

getmyip() {
	if ! ifconfig wlan0 > /dev/null 2>&1; then
		STATUS=4
		return
	fi
	if ! wpa_cli status > /dev/null 2>&1; then
		if iwconfig wlan0 | grep ESSID:\"mijia-camera-; then
		    STATUS=3
		else
		    STATUS=5
		fi
		return
	fi

	wpa_EVENT=`ps | grep "wpa_event" | grep -v grep`
	if [ "x$wpa_EVENT" == "x" ];then
		STATUS=6
		return
	fi

	WPASTATE=`wpa_cli status | grep wpa_state | cut -d '=' -f 2`
	if [ "x$WPASTATE" == x"SCANNING" ]; then
		STATUS="2"
		return
	fi

	MYIP=`wpa_cli status | grep ip_address | cut -d '=' -f 2`
	if [ "x$MYIP" == "x" ]; then
		STATUS="1"
		return
	fi

	if ! ( ip r | grep -q default ); then
		STATUS=7
		return
	fi

	STATUS=0
	COUNT=0
}

checkping() {
	if [ "$STATUS" -lt 2 ]; then
		if ping -c 1 -W 5 -w 5 $PUBLICIP > /dev/null; then
			INTERVAL=60
			STATUS=0
		else
			STATUS=$((STATUS + 1))
			INTERVAL=10
		fi
	fi
}

report() {
	if [ "$STATUS" == 1 ]; then
		logger -t governor "missed ip...$COUNT"
		wpa_cli status | logger -t governor
		iwconfig wlan0 | logger -t governor
		ifconfig wlan0 | logger -t governor
	elif [ "$STATUS" == 2 ]; then
		logger -t governor "wifi scanning..."
		wpa_cli status | logger -t governor
	elif [ "$STATUS" == 3 ]; then
		logger -t governor "wifi AP mode..."
	elif [ "$STATUS" == 4 ]; then
		logger -t governor "No wlan0..."
		dmesg | grep mt | tail -n 1 | logger -t governor
	elif [ "$STATUS" == 5 ]; then
		logger -t governor "No wpa_supplicant?..."
		ps | grep wpa | logger -t governor
		iwconfig wlan0 | logger -t governor
		ifconfig wlan0 | logger -t governor
	elif [ "$STATUS" == 6 ]; then
		logger -t governor "No wpa_cli event..."
		ps | grep wpa | logger -t governor
	elif [ "$STATUS" == 7 ]; then
		logger -t governor "No default gateway..."
		ip r | logger -t governor
	fi
}


refreshdhcp() {
	(
	killall -SIGUSR2 udhcpc &&
	sleep 2 &&
	killall -SIGUSR1 udhcpc
	) || udhcpc -i wlan0 -S -x hostname:$model
}

reloadwifi() {
	if [ "$STATUS" == 1 ] || [ "$STATUS" == 7 ]; then
		refreshdhcp
		STATUS=0
		MYIP="0.0.0.0"
		INTERVAL=60
	elif [ "$STATUS" == 2 ]; then
	# no action yet, let's see
		STATUS=0
		WPASTATE=""
		INTERVAL=60
	elif [ "$STATUS" == 3 ]; then
	# no action in AP mode
		STATUS=0
		WPASTATE=""
		INTERVAL=60
	elif [ "$STATUS" == 4 ]; then
	# Need a reboot?
		ifconfig wlan0 down
		sleep 1
		ifconfig wlan0 up
		STATUS=0
		WPASTATE=""
		INTERVAL=60
	elif [ "$STATUS" == 5 ]; then
		# No wpa_supplicant
		# reload wifi .ko seems buggy, will kernel oops
		# /etc/init.d/S41wifi restart
		wpa_supplicant -Dnl80211 -iwlan0 -c $WPA_SUPPLICANT_CONFIG_FILE -B
		wpa_cli -i wlan0 -B -a /mnt/data/bin/wpa_event.sh
		STATUS=0
		WPASTATE=""
		INTERVAL=60
	elif [ "$STATUS" == 6 ]; then
		wpa_cli -i wlan0 -B -a /mnt/data/bin/wpa_event.sh
		STATUS=0
		WPASTATE=""
		INTERVAL=60
	fi
}

while :; do
	interval
	getmyip
	# checkping
	report
	reloadwifi
done
