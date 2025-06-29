#!/bin/bash

##This is a module for main.sh that defines fstab logic


mkfstab() {
   
    ##Things that we need: Efi part, if any, home part, if any, and root part... oh, and partition_table variables...
    
    ##Syntax: mkfstab <Filesystem for root and home part> <root part> <home part> <efi part> <directory>...
    local efi_part="$4"
    local home_part="$3"
    local root_part="$2"
    local filesystem="$1"
    local directory="$5"
    > "${directory}"/etc/fstab
    if [ ${efi_part} != "null" ]; then
        efi_part_id=$(blkid -s UUID -o value "${efi_part}")
        echo -e "\n#EFI\nUUID=${efi_part_id}  /boot  vfat defaults    0   0" >> "${directory}"/etc/fstab
    fi 
    
    if [ "${home_part}" != "null" ]; then
        home_part_id=$(blkid -s UUID -o value "${home_part}")
        echo -e "\n#HOME\nUUID=${home_part_id} /home ${filesystem} defaults 0 2" >> "${directory}"/etc/fstab
    fi 

    root_part_id=$(blkid -s UUID -o value "${root_part}")
    echo -e "\n#ROOT\nUUID=${root_part_id} / ${filesystem} defaults 0 1" >> "${directory}"/etc/fstab

    
}

getfstab() {
    ##This is a demo fstab generator that just takes mountpoint and gets everything else by itself.
    ##USAGE: getfstab <directory>
    local directory="$1"

    defaults_vfat="defaults,noatime,umask=0077"

    root_part="$(lsblk -rno NAME,MOUNTPOINT | grep -w ${directory} | cut -d ' ' -f1)"
    home_part="$(lsblk -rno NAME,MOUNTPOINT | grep -w ${directory}/home | cut -d ' ' -f1)"
    efi_part="$(lsblk -rno NAME,FSTYPE | grep -w vfat | cut -d ' ' -f1)"
    efi_part_mount="$(lsblk -rno FSTYPE,MOUNTPOINT | grep -w vfat | cut -d ' ' -f2 | cut -d '/' -f3)"
    home_part_type="$(lsblk -rno FSTYPE,MOUNTPOINT | grep -w ${directory}/home | cut -d ' ' -f1)"
    root_part_type="$(lsblk -rno FSTYPE,MOUNTPOINT | grep -w ${directory} | cut -d ' ' -f1)"

    ##We have gotten everything we needed.
    > "${directory}"/etc/fstab
    if [ ! -z "${efi_part}" ]; then
        efi_part_id=$(blkid -s UUID -o value "${efi_part}")
        echo -e "\n#EFI\nUUID=${efi_part_id}  /${efi_part_mount}  vfat ${defaults_vfat}   0   0" >> "${directory}"/etc/fstab
    fi 
    
    if [ ! -z "${home_part}" ]; then
        home_part_id=$(blkid -s UUID -o value "${home_part}")
        echo -e "\n#HOME\nUUID=${home_part_id} /home ${home_part_type} defaults,noatime" >> "${directory}"/etc/fstab
    fi 

    root_part_id=$(blkid -s UUID -o value "${root_part}")
    echo -e "\n#ROOT\nUUID=${root_part_id} / ${home_part_type} defaults,noatime 0 1" >> "${directory}"/etc/fstab
    ##IT IS FUCKING COMPLETED, BABY!!! COME HIGH BABY!

}
