#!/bin/bash
##This is a module for main.sh. this scriipt defines the get_bootstrap function.

get_bootstrap() {
    cd /mnt/bedrock
    case $1 in 
        Debian)
            log sudo debootstrap stable "$(pwd)" http://deb.debian.org/debian/
            ;;
        Arch)
            log sudo curl -LO https://mirror.rackspace.com/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst
            ;;
        Gentoo)
            log sudo latest=$(curl -s https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/latest-stage3-amd64-desktop-openrc.txt | sudo grep stage3-amd64 | sudo cut -d ' ' -f1); sudo curl -LO https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/$latest
            ;;
        Void)
            log sudo curl -LO $(curl -s https://voidlinux.org/download/ | grep void-x86_64-musl-ROOTFS | cut -d '"' -f2)
            ;;
        *)
            log_msg "DEBUG LOG!! It seems that user didnt enter any of the parent distros and have opted for a derivative... exitting.\n"
            exit 1
            ;;
    esac
}
