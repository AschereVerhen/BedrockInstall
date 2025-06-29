#!/bin/bash

##This is a module of the main.sh script. This defines chrooting.

set -eau pipefail

bedrock-mount() {
    local directory="$1"
    
    ##Resolv.conf Handling
    cp -r /etc/resolv.conf "${directory}"/resolv.conf
    
    ##Mounting
    log mount --types proc /proc "${directory}"/proc || true
    log mount --rbind /sys "${directory}"/sys || true
    log mount --make-rslave ${directory}/sys || true
    log mount --rbind /dev ${directory}/dev || true
    log mount --make-rslave ${directory}/dev || true
    log mount --bind /run ${directory}/run || true
    log mount --make-slave ${directory}/run || true
    log test -l /dev/shm && rm /dev/shm && mkdir /dev/shm
    log mount --types tmpfs --options nosuid,nodev,noexec shm /dev/shm || true
}

bedrock-chroot() {
    local directory="$1"
    local shell="$2"

    log chroot "${directory}" /usr/bin/env TERM=xterm "${shell}"
}
