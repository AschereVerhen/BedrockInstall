#!/bin/bash


set -eu pipefail

echo -e "This Is a simple, primitive installer for bedrock linux. Made to install bedrock linux with an initial strata and add on to it as easily as pie.... /n"

clear

#get_debian_bootstrap="$(debootstrap "${chroot_directory}" stable http://deb.debian.org/debian/)"
#get_arch_bootstrap="$(curl -LO https://mirror.rackspace.com/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst)"
#get_gentoo_bootstrap="latest=$(curl -s https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/latest-stage3-amd64-desktop-openrc.txt | grep stage3-amd64 | cut -d ' ' -f1); curl -LO https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/$latest"
#get_void_bootstrap="$(curl -LO $(curl -s https://voidlinux.org/download/ | grep void-x86_64-musl-ROOTFS | cut -d '"' -f2))"


get_bootstrap() {
    case $1 in 
        debian)
            debootstrap "$2" stable http://deb.debian.org/debian/ ##If passing debian... make sure to add chroot directory, yash.
            ;;
        arch)
            curl -LO https://mirror.rackspace.com/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst
            ;;
        gentoo)
            latest=$(curl -s https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/latest-stage3-amd64-desktop-openrc.txt | grep stage3-amd64 | cut -d ' ' -f1); curl -LO https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/$latest
            ;;
        void)
            curl -LO $(curl -s https://voidlinux.org/download/ | grep void-x86_64-musl-ROOTFS | cut -d '"' -f2)
            ;;
        *)
            echo "DEBUG LOG!! It seems that user didnt enter any of the parent distros and have opted for a derivative... exitting.\n"
            exit 1
            ;;
    esac
}

##End of defining bootstraps.... Now for the checks of essential packages... ie, just tar with zst support(And ofcourse, debootstrap....

for pkg in tar cfdisk debootstrap; do 
    if command -v "${pkg}" --version >&/dev/null; then
        echo -e "[DEBUG]: ${pkg} exists.\n"
    else 
        echo -e "[DEBUG]: ${pkg} does not exist. need to install it...\n"
        ## Searching for whichever package manager the system running this script has...
        for pkg_mgr in apt xbps-install emerge pacman dnf; do 
            if [ ! "$(command -v "${pkg_mgr}" --version >&/dev/null)" = "1" ]; then
                if [ "${pkg_mgr}" = "pacman" ]; then
                    "sudo" "${pkg_mgr}" "-Sy" "${pkg}"
                elif [ "${pkg_mgr}" = "apt" ] || [ "${pkg_mgr}" = "dnf" ]; then
                    "sudo" "${pkg_mgr}" "install" "${pkg}"
                else 
                    "sudo" "${pkg_mgr}" "${pkg}"
                fi 
            else 
                echo -e "[DEBUG]: I cannot determine the linux distro... i need to quit...\n"
                echo -e "\n [USER]: Please install ${pkg} by yourself and run this script again..."
                exit 1
            fi 
        done 
    fi 
done


## The above section was extremely buggy. Need to come back to it...

##Now its the time for disks!

clear ##Clearing the screen

##First lets detect if the system is efi or not...
if [ -e /sys/firmware/efi ]; then
    efi_system=0
else 
    efi_system=1
fi 

lsblk -dno NAME,SIZE ##Outputting the lsblk prompt for the user...
echo -e "/n"; read -p "which disk would you like to install bedrock linux to? (eg: /dev/sda): " disk
echo "Okay... You have selected ${disk}... Now initializing cfdisk... wait."
if [ "${efi_system}" -eq "0" ]; then
    echo -e "\n [USER]: MAKE SURE TO INITIALIZE THE FIRST SECTOR with an EFI PARTITION of size ~100MB"
fi 
sleep 5
cfdisk "${disk}"

##Since the user has by now completed the making of disk, now making the partitions...
if grep -q "nvme" "${disk}"; then
    disk_is_nvme=0
fi 

lsblk "${disk}"

echo "\n";read -p "Which one would you like to use as your /boot(or /efi) partiton?: " disk_boot
echo "\n"; read -p "which one would you like to use as your /(root) partition?: " disk_root
echo "\n"; read -p "which one would you like to use as your /home partition?(just press enter if you dont want a /home partition): " disk_home

mkfs.fat -F32 "${disk_boot}"
mkfs.ext4 "${disk_root}"
mkfs.ext4 "${disk_home}"
echo "DONE!"
