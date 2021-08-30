#!/bin/sh

WIFI_START_SCRIPT="/mnt/data/bin/wifi_start.sh"
MIIO_RECV_LINE="/mnt/data/bin/miio_recv_line"
MIIO_SEND_LINE="/mnt/data/bin/miio_send_line"
WIFI_MAX_RETRY=3
WIFI_RETRY_INTERVAL=3
WIFI_SSID=

DEFAULT_TIMEZONE_LINK="/usr/share/zoneinfo/Asia/Shanghai"

GLIBC_TIMEZONE_DIR="/usr/share/zoneinfo"
UCLIBC_TIMEZONE_DIR="/usr/share/zoneinfo"

YOUR_LINK_TIMEZONE_FILE="/mnt/data/etc/TZ"
YOUR_TIMEZONE_DIR=$UCLIBC_TIMEZONE_DIR

LINK_HOSTS_FILE="/mnt/data/hosts"
PRC_LINK_HOSTS_FILE="/mnt/data/hosts.prc"
GLOBAL_LINK_HOSTS_FILE="/mnt/data/hosts.global"

# contains(string, substring)
#
# Returns 0 if the specified string contains the specified substring,
# otherwise returns 1.
contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

send_helper_ready() {
    ready_msg="{\"method\":\"_internal.helper_ready\"}"
    echo $ready_msg
    $MIIO_SEND_LINE "$ready_msg"
}

req_wifi_conf_status() {
    wifi_ready=`mortoxc get nvram default bind_status`
    if [ x"$wifi_ready" != x"ok" ] ; then
	wifi_ready="no"
    else
	wifi_ready="yes"
    fi

#    is_ft_p2p=`/bin/cat  /tmp/ft_mode`

    REQ_WIFI_CONF_STATUS_RESPONSE=""
 #   if [ $wifi_ready = "yes" ] || [ $is_ft_p2p = "3" ]; then
    if [ $wifi_ready = "yes" ]; then
	REQ_WIFI_CONF_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_conf_status\",\"params\":1}"
    else
	REQ_WIFI_CONF_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_conf_status\",\"params\":0}"
    fi
}

request_dinfo() {
    dinfo_file=$DEVICE_CONFIG_FILE

    dinfo_did=`factory get did`
    dinfo_key=`factory get key`
    dinfo_vendor=`factory get vendor`
    dinfo_mac=`factory get mac`
    dinfo_model=`factory get model`

    echo $dinfo_did
#    echo $dinfo_key
    echo $dinfo_vendor
    echo $dinfo_mac
    echo $dinfo_model

    RESPONSE_DINFO="{\"method\":\"_internal.response_dinfo\",\"params\":{"
    if [ x$dinfo_did != x ]; then
	RESPONSE_DINFO="$RESPONSE_DINFO\"did\":$dinfo_did"
    fi
    if [ x$dinfo_key != x ]; then
	RESPONSE_DINFO="$RESPONSE_DINFO,\"key\":\"$dinfo_key\""
    fi
    if [ x$dinfo_vendor != x ]; then
	RESPONSE_DINFO="$RESPONSE_DINFO,\"vendor\":\"$dinfo_vendor\""
    fi
    if [ x$dinfo_mac != x ]; then
	RESPONSE_DINFO="$RESPONSE_DINFO,\"mac\":\"$dinfo_mac\""
    fi
    if [ x$dinfo_model != x ]; then
	RESPONSE_DINFO="$RESPONSE_DINFO,\"model\":\"$dinfo_model\""
    fi
    RESPONSE_DINFO="$RESPONSE_DINFO}}"
}

request_dtoken() {
    dtoken_string=$1
    dtoken_dir=${dtoken_string##*dir\":\"}
    dtoken_dir=${dtoken_dir%%\"*}
    dtoken_token=${dtoken_string##*ntoken\":\"}
    dtoken_token=${dtoken_token%%\"*}

    wifi_ready=`mortoxc get nvram default bind_status`
    if [ x"$wifi_ready" != x"ok" ] ; then
	wifi_ready="no"
    else
	wifi_ready="yes"
    fi

    if [ $wifi_ready = "no" ]; then
	mortoxc unset nvram default miio_token
	mortoxc sync nvram > /dev/null 2>&1
    fi

    miio_token=`mortoxc get nvram default miio_token`
    if [ x$miio_token = x ]; then
	mortoxc set nvram default miio_token $dtoken_token
	mortoxc sync nvram
	miio_token=`mortoxc get nvram default miio_token`
    fi

    miio_country=`mortoxc get nvram default miio_country`
    if [ -f $LINK_HOSTS_FILE ]; then
	unlink $LINK_HOSTS_FILE
    fi

    if [ x"$miio_country" = x ]; then
	ln -sf $PRC_LINK_HOSTS_FILE $LINK_HOSTS_FILE
    else
	ln -sf $GLOBAL_LINK_HOSTS_FILE $LINK_HOSTS_FILE
    fi

    new_tz=`mortoxc get nvram default timezone`
    if [ x"$new_tz" != x -a -f $new_tz ]; then
	ln -sf  $new_tz $YOUR_LINK_TIMEZONE_FILE
    else
	ln -sf  $DEFAULT_TIMEZONE_LINK $YOUR_LINK_TIMEZONE_FILE
    fi

    offline_time=`mortoxc get nvram default offline_time`
    if [ x"$offline_time" = x ]; then
	offline_time=0
    fi
    offline_reason=`mortoxc get nvram default offline_reason`
    if [ x"$offline_reason" = x ]; then
	offline_reason=0
    fi
    improve_program=`mortoxc get nvram default improve_program`
    if [ x"$improve_program" = x"on" ]; then
	improve_program=1
    else
	improve_program=0
    fi
    offline_ip=`mortoxc get nvram default offline_ip`
    if [ x"$offline_ip" = x ]; then
	offline_ip=0
    fi

    offline_port=`mortoxc get nvram default offline_port`
    if [ x"$offline_port" = x ]; then
	offline_port=0
    fi
    echo "response offline_time: $offline_time"
    echo "response offline_reason: $offline_reason"
    RESPONSE_DCOUNTRY="{\"method\":\"_internal.response_dcountry\",\"params\":\"${miio_country}\"}"
    RESPONSE_DTOKEN="{\"method\":\"_internal.response_dtoken\",\"params\":\"${miio_token}\"}"
    RESPONSE_OFFLINE="{\"method\":\"_internal.response_offline\",\"params\":{\"offline_time\":${offline_time},\"offline_reason\":${offline_reason},\"improve_program\":${improve_program},\"offline_ip\":${offline_ip},\"offline_port\":${offline_port}}}"
}

save_wifi_conf() {
    miio_ssid=$1
    miio_passwd=$2
    miio_uid=$3
    miio_country=$4

    if [ -f $LINK_HOSTS_FILE ]; then
	unlink $LINK_HOSTS_FILE
    fi
    if [ x"$miio_country" = x ]; then
	ln -sf $PRC_LINK_HOSTS_FILE $LINK_HOSTS_FILE
    else
	ln -sf $GLOBAL_LINK_HOSTS_FILE $LINK_HOSTS_FILE
    fi

    mortoxc set nvram default miio_ssid "$miio_ssid"

    if [ x"$miio_passwd" = x ]; then
	mortoxc unset nvram default miio_passwd
	mortoxc set nvram default key_mgmt "NONE"
    else
	mortoxc set nvram default miio_passwd "$miio_passwd"
	mortoxc set nvram default key_mgmt "WPA"
    fi

    if [ x$miio_uid = x ]; then
	mortoxc unset nvram default miio_uid
    else
	mortoxc set nvram default miio_uid $miio_uid
    fi

    if [ x"$miio_country" = x ]; then
	mortoxc unset nvram default miio_country
    else
	mortoxc set nvram default miio_country "$miio_country"
    fi
    mortoxc sync nvram
}

clear_wifi_conf() {
	mortoxc unset nvram default miio_ssid
	mortoxc unset nvram default miio_passwd
	mortoxc unset nvram default miio_uid
	mortoxc unset nvram default miio_country
	mortoxc unset nvram default bind_status
	mortoxc sync nvram
}

save_tz_conf() {
	new_tz=$YOUR_TIMEZONE_DIR/$1
	echo $new_tz
	if [ -f $new_tz ]; then
		mortoxc set nvram default timezone "$new_tz"
		mortoxc sync nvram
		unlink $YOUR_LINK_TIMEZONE_FILE
		ln -sf  $new_tz $YOUR_LINK_TIMEZONE_FILE
		echo "timezone set success:$new_tz"
	else
		echo "timezone is not exist:$new_tz"
	fi
}

sanity_check() {
    if [ ! -e $WIFI_START_SCRIPT ]; then
	echo "Can't find wifi_start.sh: $WIFI_START_SCRIPT"
	echo 'Please change $WIFI_START_SCRIPT'
	exit 1
    fi
}

main() {
    while true; do
	BUF=`$MIIO_RECV_LINE`
	if [ $? -ne 0 ]; then
	    sleep 1;
	    continue
	fi
	if contains "$BUF" "_internal.info"; then
	    STRING=`wpa_cli status`

	    ifname=${STRING#*\'}
	    ifname=${ifname%%\'*}
	    echo "ifname: $ifname"

	    if [ "x$WIFI_SSID" != "x" ]; then
		ssid="$WIFI_SSID"
	    else
		ssid=`mortoxc get nvram default miio_ssid`
		WIFI_SSID=${ssid}
	    fi
	    # handle special char, e.g.: '"', '\'
	    # Here we're using sed, we might switch to jshon
	    #ssid=$(echo $ssid | sed -e 's/^"/\\"/' | sed -e 's/\([^\]\)"/\1\\"/g' | sed -e 's/\([^\]\)"/\1\\"/g' | sed -e 's/\([^\]\)\(\\[^"\\\/bfnrtu]\)/\1\\\2/g' | sed -e 's/\([^\]\)\\$/\1\\\\/')
	    ssid=$(jshon -s "$ssid")
	    ssid=$(echo "$ssid" | sed 's/^"//' | sed 's/"$//')

	    echo "ssid: $ssid"

	    bssid=${STRING##*bssid=}
	    bssid=`echo ${bssid} | cut -d ' ' -f 1 | tr '[:lower:]' '[:upper:]'`
	    echo "bssid: $bssid"

	    freq=${STRING##*freq=}
	    freq=`echo ${freq} | cut -d ' ' -f 1`
	    echo "freq: $freq"

	    rssi=`cat /proc/net/rtl8189fs/wlan0/rx_signal | grep rssi | cut -d ':' -f 2`
	    echo $rssi
	    if [ "x$rssi" = "x" ]; then
		rssi=0
	    fi

	    ip=${STRING##*ip_address=}
	    ip=`echo ${ip} | cut -d ' ' -f 1`
	    echo "ip: $ip"

	    STRING=`ifconfig ${ifname}`

	    netmask=${STRING##*Mask:}
	    netmask=`echo ${netmask} | cut -d ' ' -f 1`
	    echo "netmask: $netmask"

	    gw=`route -n|grep 'UG'|tr -s ' ' | cut -f 2 -d ' '`
	    echo "gw: $gw"

	    # get vendor and then version
	    vendor=`factory get vendor | tr '[:lower:]' '[:upper:]'`
	    sw_version=`grep "${vendor}_VERSION" /etc/os-release | cut -f 2 -d '='`
	    if [ -z $sw_version ]; then
		sw_version="unknown"
	    fi

	    msg="{\"method\":\"_internal.info\",\"partner_id\":\"\",\"params\":{\
\"hw_ver\":\"Linux\",\"fw_ver\":\"$sw_version\",\
\"ap\":{\
 \"ssid\":\"$ssid\",\"bssid\":\"$bssid\",\"rssi\":\"$rssi\",\"freq\":$freq\
},\
\"netif\":{\
 \"localIp\":\"$ip\",\"mask\":\"$netmask\",\"gw\":\"$gw\"\
}}}"

	    echo "$msg"
	    $MIIO_SEND_LINE "$msg"
	elif contains "$BUF" "_internal.req_wifi_conf_status"; then
	    echo "Got _internal.req_wifi_conf_status"
	    req_wifi_conf_status "$BUF"
	    echo $REQ_WIFI_CONF_STATUS_RESPONSE
	    $MIIO_SEND_LINE "$REQ_WIFI_CONF_STATUS_RESPONSE"
	elif contains "$BUF" "_internal.wifi_start"; then

	    miio_ssid=$(echo "$BUF" | jshon -e params -e ssid -u)
	    miio_passwd=$(echo "$BUF" | jshon -e params -e passwd -u)
	    miio_uid=$(echo "$BUF" | jshon -e params -e uid -u)
	    miio_country=$(echo "$BUF" | jshon -e params -e country_domain -u)
	    miio_tz=$(echo "$BUF" | jshon -e params -e tz -u)

	    echo "miio_ssid: $miio_ssid"
	    echo "miio_country: $miio_country"
	    echo "miio_tz: $miio_tz"

	    save_wifi_conf "$miio_ssid" "$miio_passwd" $miio_uid "$miio_country"
	    save_tz_conf "$miio_tz"

	    CMD=$WIFI_START_SCRIPT
	    RETRY=1
	    WIFI_SUCC=1
	    until [ $RETRY -gt $WIFI_MAX_RETRY ]
	    do
		WIFI_SUCC=1
		echo "Retry $RETRY: CMD=${CMD}"
		${CMD} "ENTER_STA_MODEL" && break
		WIFI_SUCC=0
		let RETRY=$RETRY+1
		sleep $WIFI_RETRY_INTERVAL
	    done

	    if [ $WIFI_SUCC -eq 1 ]; then
		msg="{\"method\":\"_internal.wifi_connected\"}"
		echo $msg
		$MIIO_SEND_LINE "$msg"
	    else
		clear_wifi_conf
		CMD=$WIFI_START_SCRIPT
		echo "Back to AP mode, CMD=${CMD}"
		${CMD} "ENTER_AP_MODEL"
		msg="{\"method\":\"_internal.wifi_ap_mode\",\"params\":null}";
		echo $msg
		$MIIO_SEND_LINE "$msg"
	    fi
	elif contains "$BUF" "_internal.request_dinfo"; then
	    echo "Got _internal.request_dinfo"
	    request_dinfo "$BUF"
	    # echo $RESPONSE_DINFO
	    $MIIO_SEND_LINE "$RESPONSE_DINFO"
	elif contains "$BUF" "_internal.request_dtoken"; then
	    echo "Got _internal.request_dtoken"
	    request_dtoken "$BUF"
	    echo $RESPONSE_DCOUNTRY
	    $MIIO_SEND_LINE "$RESPONSE_DCOUNTRY"
	    echo $RESPONSE_OFFLINE
	    $MIIO_SEND_LINE "$RESPONSE_OFFLINE"
	    # echo $RESPONSE_DTOKEN
	    $MIIO_SEND_LINE "$RESPONSE_DTOKEN"
	elif contains "$BUF" "_internal.config_tz"; then
	    echo "Got _internal.config_tz"
	    miio_tz=$(echo "$BUF" | jshon -e params -e tz -u -Q)
	    save_tz_conf "$miio_tz"
	elif contains "$BUF" "_internal.record_offline"; then
	    echo "Got _internal.record_offline_time"
	    offline_time=$(echo "$BUF" | jshon -e params -e offline_time -u -Q)
	    offline_reason=$(echo "$BUF" | jshon -e params -e offline_reason -u -Q)
	    offline_ip=$(echo "$BUF" | jshon -e params -e offline_ip -u -Q)
	    offline_port=$(echo "$BUF" | jshon -e params -e offline_port -u -Q)
	    echo "offline_time is $offline_time"
	    echo "offline_reason is $offline_reason"
	    echo "offline_ip is $offline_ip"
	    echo "offline_port is $offline_port"
	    mortoxc set nvram default offline_time $offline_time
	    mortoxc set nvram default offline_reason $offline_reason
	    mortoxc set nvram default offline_ip $offline_ip
	    mortoxc set nvram default offline_port $offline_port
	    mortoxc sync nvram
	else
	    echo "Unknown cmd: $BUF"
	fi
    done
}

sanity_check
send_helper_ready
main
