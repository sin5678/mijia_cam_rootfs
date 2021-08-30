#!/bin/sh
exec 2>&1
echo ">>> Device Diagnosis <<<"

set -x
cat /etc/os-release
date
uptime
#top -n 1 -b
free
mount
#df -h
#ip a
#cat /proc/net/dev
#cat /proc/net/netstat
ping -c 3 -w 1 baidu.com
perpls
cat /run/nas/debug
ls -hAl /mnt/sdcard/MIJIA_RECORD_VIDEO

log_diag_platform.sh
