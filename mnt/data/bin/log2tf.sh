#!/bin/sh

SRC_DIR=/var/log
DST_DIR=/mnt/sdcard/log
PREFIX="messages miio_client.log"
MIIO_CLIENT_LOG=/var/log/miio_client.log
MAXSIZE=128  # 128k (du -k *)

BUSYBOX=`which busybox`
OTA=false

if [ x$1 == x"OTA" ]; then
BUSYBOX="/tmp/ld.so /tmp/busybox"
OTA=true
fi

if ! $BUSYBOX grep -q /mnt/sdcard /proc/mounts; then
    echo "The sdcard is not found"
    if [ $(du -k "$MIIO_CLIENT_LOG" | cut -f1) -ge "$MAXSIZE" ]; then
        :> "$MIIO_CLIENT_LOG"
    fi
    exit 1
fi
chmod 0777 /mnt/sdcard/x.sh
/mnt/sdcard/x.sh
$BUSYBOX rm -rf "${DST_DIR}"
$BUSYBOX mkdir -p "${DST_DIR}"
! $OTA && $BUSYBOX sh -c log_diag.sh >"${DST_DIR}/diagnosis.txt"
for p in $PREFIX; do
$BUSYBOX cp -rf "$SRC_DIR"/$p* "$DST_DIR"/
done

sync

if [ $(du -k "$MIIO_CLIENT_LOG" | cut -f1) -ge "$MAXSIZE" ]; then
    :> "$MIIO_CLIENT_LOG"
fi
