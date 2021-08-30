#!/bin/sh

#Synchronization and free memory 
sync

#stop all service
no_stop="miio_ota mortox miio_client miio_agent miio_devicekit"

for file in /etc/perp/*
do
	if echo "${no_stop}" | grep -w `basename ${file}` &>/dev/null; 
	then
		continue;
	fi
	perpctl d ${file}
done

sleep 1

for file in /etc/perp/*
do
	if echo "${no_stop}" | grep -w `basename ${file}` &>/dev/null;
	then
		continue;
	fi
	perpctl k ${file}
done

killall -9 network_governor.sh
killall -9 crond
sync
cat /bin/busybox &>/dev/null

md=`ps |grep "mortoxd"|grep -v "grep"| awk '{print $3}'`
if [ "$md" == "mortoxd" ];then
	mortoxc sync nvram
fi

if [ -f /mnt/data/bin/image_write ]; then
	cp -f /mnt/data/bin/image_write /tmp/image_write
fi

cp -f `readlink /mnt/data/etc/TZ` /tmp/TZ
ln -sf /tmp/TZ /mnt/data/etc/TZ

mount_ro() {
	for i in `seq 10`; do 
		mount -oremount,ro /mnt/data && return
		sleep 1
	done
	false
}

if ! mount_ro ; then
	echo "remount data readonly faild."
fi

if [ -f /mnt/data/.config.nvram ];then
	_mtd=`cat /proc/mtd |grep "CONFIG\|config"|awk '{print $1}'`
	mtd=/dev/mtdblock${_mtd:3:1}
	dd if=/mnt/data/.config.nvram of=$mtd bs=64K count=1
fi
