#!/bin/sh

WPA_SUPPLICANT_CONFIG_FILE="/tmp/wpa_supplicant.conf"
#interface=`wpa_cli stat |grep interface | sed -r "s/.*'(.+)'.*/\1/"`
interface=`ifconfig  |grep "Link encap" |grep -v "lo"|awk '{print $1}' `
if [ "x$interface" == "x" ]; then
	interface=`iwconfig  2>/dev/null| grep Nickname | awk '{print $1}'`
fi

if [ "x$interface" == "x" ]; then
interface=wlan0
fi

echo $interface
update_wpa_conf()
{
    if [ x"$2" = x ]; then
    cat <<EOF > $WPA_SUPPLICANT_CONFIG_FILE
ctrl_interface=/var/run/wpa_supplicant
update_config=1
network={
        ssid="$1"
        key_mgmt=NONE
    scan_ssid=1
}
EOF
    else
    cat <<EOF > $WPA_SUPPLICANT_CONFIG_FILE
ctrl_interface=/var/run/wpa_supplicant
update_config=1
network={
        ssid="$1"
        psk="$2"
        key_mgmt=WPA-PSK
    proto=WPA WPA2
    scan_ssid=1
}
EOF
    fi
}

wifi_ap_mode()
{
    echo "Enabling wifi AP mode"

    # wifi stop
    ifconfig $interface down
    killall -9 udhcpc wpa_supplicant hostapd udhcpd
    ifconfig $interface up
    ifconfig $interface 192.168.14.1 netmask 255.255.255.0

    # AP mode
	MODEL=`factory get model`
	#vendor=`echo ${MODEL} | cut -d '.' -f 1`
	#product=`echo ${MODEL} | cut -d '.' -f 2`
	#version=`echo ${MODEL} | cut -d '.' -f 3`
	#echo "ssid=${vendor}-${product}-${version}_miap$1"
	MODEL=`echo $MODEL| sed 's/\./-/g'`
	echo $MODEL
    cp /etc/hostapd.conf /tmp/
    echo "ssid=${MODEL}_miap$1" >> /tmp/hostapd.conf
    mkdir -p /var/run/hostapd
    hostapd /tmp/hostapd.conf -B

    mkdir -p /var/lib/misc
    touch /var/lib/misc/udhcpd.leases
    udhcpd
}

wifi_sta_mode()
{
    echo "Enabling wifi STA mode"

    get_ssid_passwd
    update_wpa_conf "$ssid" "$passwd"

    #stop uap interface
    killall -9 udhcpc wpa_supplicant hostapd udhcpd
    ifconfig $interface down
    
    ifconfig $interface up
    iwconfig $interface mode Managed
    mkdir -p /var/run/wpa_supplicant
    wpa_supplicant -Dnl80211 -i$interface -c $WPA_SUPPLICANT_CONFIG_FILE -B
	wpa_cli -i $interface -B -a /mnt/data/bin/wpa_event.sh

	MODEL=`factory get model`
	hname=`echo $MODEL| sed "s/\./_/g"`
	echo $hname
    if [ x"$wifi_ready" = x"ok" ]; then
        udhcpc -i $interface -S -x hostname:$hname
    else
        udhcpc -i $interface -t 10 -T 2 -n -S -x hostname:$hname
    fi
    echo 3 > /proc/sys/kernel/printk
    # check if we've got ip
    echo "get ip addr :"
	ip=`wpa_cli status | grep ip_address | cut -d '=' -f 2`
    echo $ip
    if [ x"$ip" == x ];then
        return 1
    else
        return 0
    fi
}

get_ssid_passwd()
{
    key_mgmt=`mortoxc get nvram default key_mgmt`
    if [ $key_mgmt == "NONE" ]; then
    passwd=""
    else
    passwd=`mortoxc get nvram default miio_passwd`
    fi
    ssid=`mortoxc get nvram default miio_ssid`

    echo $ssid
    #echo $passwd
    echo $key_mgmt
}

start()
{
    wifi_ready=`mortoxc get nvram default bind_status`
    echo "++++" $wifi_ready

    if [ x"$wifi_ready" = x"ok" ] || [ x"$1"  = x"ENTER_STA_MODEL" ]; then
    wifi_sta_mode
    else
    # STRING=`ifconfig wlan0`

    # macstring=${STRING##*HWaddr }
    # macstring=`echo ${macstring} | cut -d ' ' -f 1`

    macstring=`factory get mac`

    mac1=`echo ${macstring} | cut -d ':' -f 5`
    mac2=`echo ${macstring} | cut -d ':' -f 6`
    MAC=${mac1}${mac2}

    echo "MAC is " $MAC

    wifi_ap_mode $MAC
    fi
}

start $1
