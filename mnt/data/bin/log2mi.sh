#!/bin/sh

BASELOG=/var/log/messages
MIIO_CLIENT_LOG=/var/log/miio_client.log
corp=`factory get model`
did=`factory get did`
timestamp=`date +%Y-%m-%d-%T`
server="https://dlg.io.mi.com/v1/upload"

exec 2>/dev/kmsg

log() {
    echo "log2mi: $@" >&2
}

sanity_check() {
    if [ -n "$(mortoxc get nvram default miio_country)" ]; then
        log "Disabled by country"
        exit 1
    fi

    if [ x"$(mortoxc get nvram default improve_program)" != x"on" ]; then
        log "Disabled by user."
        exit 1
    fi

    if ! curl -V >/dev/null ; then
        log "Can not execute curl"
        exit 1
    fi
}

upload() {
    local id="$1"
    curl --retry 3 --retry-delay 1 --speed-limit 100 --speed-time 10 -X POST -d "corp=$corp&did=$did&id=$id&ts=$timestamp" --data-urlencode data@- "$server"
}

reportone () {
    local file="$1"
    log "reporting $1"

    echo "**** $file ****"
    cat "$file" || return 1
}

merge_logs() {
    local prefix="$1"
    ls -1r "${prefix}."* 2>/dev/null | while read file; do
        cat "$file"
    done

    cat "$prefix"
}

cleanup_logs() {
    rm -vf "${BASELOG}".* "${MIIO_CLIENT_LOG}".*
    :> "${BASELOG}"
    :> "${MIIO_CLIENT_LOG}"
}

log "try upload system log"

sanity_check
(
merge_logs "${BASELOG}"
merge_logs "${MIIO_CLIENT_LOG}"
log_diag.sh
) | upload messages

rc=$?
if [ $rc -eq 0 ]; then
    cleanup_logs
    log "curl upload successful"
else
    log "curl upload failed with code $rc"
fi
