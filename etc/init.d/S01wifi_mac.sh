#!/bin/sh 

mac=`factory get mac`
echo $mac > /tmp/wifimac.txt

sysctl -w net.ipv4.ip_local_reserved_ports=54322,54321,54320

