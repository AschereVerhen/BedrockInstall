#!/usr/bin/bash
##Dependencies: Bash, curl, tar(with zstd), network(ie, networkmanager), mkfs.{ext,fat,xfs}, zenity, debootstrap
##Sourcing functions
source ./mounting.sh
source ./getfstab.sh
source ./arch_setup.sh
source ./getbootstrap.sh
source ./logger.sh
set -eau pipefail

zenity --info --text="This Is a simple, primitive installer for bedrock linux. Made to install bedrock linux with an initial strata and add on to it as easily as pie...."

##Setting up logging:
log_setup
log_msg "Script started. Logging begun"
##Now its the time for disks!


##First lets detect if the system is efi or not...
if [ -e /sys/firmware/efi ]; then
    efi_system=0
else 
    efi_system=1
fi 

#Picking Disk

selected_disk=$(zenity --list --title="Its time to select your installation disk!" --column="Name" --column="Size" $(lsblk -dno NAME,SIZE | xargs))
log_msg "User selected drive: /dev/{selected_disk}"
##Selecting Partition Table
partition_table=$(zenity --list --title="Its time to select a partitioning table for your disk!!" --column="Partiton Type" "ext4" "XFS") ##Currently only offering these four partition type... hehe
log_msg "User selected file system: ${partition_table}"
##Asking to Proceed:
zenity --question --text="Are you sure you want to proceed? The disk, /dev/${selected_disk}, will be erased..."
if [ $? -eq 0 ]; then
    cd /
    umount /dev/${selected_disk}* || true ##Umounting the disk to make sure mkfs doesnt throw an error.... Added true to ensure script doesnt fail
    case ${partition_table} in 
        ext4)
            log sudo mkfs.ext4 "/dev/${selected_disk}"
            ;;
        XFS)
            log sudo mkfs.xfs "/dev/${selected_disk}"
            ;;
        *)
            echo -e "[DEBUG]: No partition type selected.\n"
            exit 1
    esac 
else 
    echo -e "Okay... Exitting the installer. Backup your data first and run the installer again."
    exit 1
fi 

##Now, since the disk is partitioned... making partitions.
##Asking if user wants a different /home partition?
if zenity --question --text="Would you like a different /home partition?"; then
    home_partition="y"
    log_msg "User wants home partition."
else 
    home_partition="n"
    log_msg "User does not want home patition"
fi 

efi_part="null"
root_part="null"
home_part="null"
##Making the efi/boot partition and the usual partitions...
if [ "${efi_system}" -eq "0" ] && [ "${home_partition}" = "n" ]; then
    log sudo parted --script "/dev/${selected_disk}" mklabel gpt mkpart ESP fat32 1MiB 1GiB set 1 esp on
    log sudo parted --script "/dev/${selected_disk}" mkpart "${partition_table,,}" 1GiB 100%
    log echo "Partitions made!"
    root_part="/dev/${selected_disk}2"
    efi_part="/dev/${selected_disk}1"
    log sudo mkfs."${partition_table,,}" "${root_part}"
    log sudo mkfs.fat -F32 "${efi_part}"
elif [ "${efi_system}" -eq "1" ] && [ "${home_partition}" = "y" ]; then
    echo -e "No need for a boot partition... Skipping to root and home partitions."
    log sudo parted --script "/dev/${selected_disk}" mklabel msdos mkpart primary "${partition_table}" 1MiB 50% set 1 boot on
    log sudo parted --script "/dev/${selected_disk}" mkpart primary "${partition_table}" 50% 100%
    echo -e "Partitions made!"
    root_part="/dev/${selected_disk}1"
    home_part="/dev/${selected_disk}2"
    log sudo mkfs."${partition_table,,}" "${root_part}"
    log sudo mkfs."${partition_table,,}" "${home_part}"
   
elif [ "${efi_system}" -eq "1" ]  && [ "${home_partition}" = "n" ]; then
    log sudo parted --script "/dev/${selected_disk}" mklabel msdos mkpart primary "${partition_table}" 0% 100% set 1 boot on
    echo -e "Partitions made!"
    root_part="/dev/${selected_disk}1"
    log sudo mkfs."${partition_table,,}" "${root_part}"
else 
    log sudo parted --script "/dev/${selected_disk}" mklabel gpt mkpart ESP fat32 1MiB 1GiB set 1 esp on
    log sudo parted --script "/dev/${selected_disk}" mkpart "${partition_table}" 1GiB 30%
    log sudo parted --script "/dev/${selected_disk}" mkpart "${partition_table}" 30% 100%
    efi_part="/dev/${selected_disk}1"
    root_part="/dev/${selected_disk}2"
    home_part="/dev/${selected_disk}3"
    sudo mkfs.fat -F32 "${efi_part}"
    sudo mkfs."${partition_table,,}" "${root_part}"
    sudo mkfs."${partition_table,,}" "${home_part}"
fi 
##Partitions Made!!

zenity --info --text="The partitions were successfully made!! The new lsblk is: $(lsblk "/dev/${selected_disk}")"

initial_strata=$(zenity --list --title="Initial Strata!!" --column="Distro" "Gentoo" "Arch" "Void" "Debian")

##Mounting the directories:
sudo mkdir -p /mnt/bedrock || true
log sudo mount "${root_part}" /mnt/bedrock
sudo mkdir -p {/mnt/bedrock/boot,/mnt/bedrock/home} || true
log sudo mount "${efi_part}" /mnt/bedrock/boot >&/dev/null || true
log sudo mount "${home_part}" /mnt/bedrock/home >&/dev/null || true
##Now, getting the bootstrap:
cd /mnt/bedrock
get_bootstrap "${initial_strata}" /mnt/bedrock/
sudo mv root*/* /mnt/bedrock
sudo rm -rf /mnt/bedrock/root*/
##Extracting bootstrap:
if [ "${initial_strata}" != "Debian" ]; then
    log sudo tar xpvf *tar* --xattrs-include='*.*' --numeric-owner -C /mnt/bedrock
fi 

##fstab
getfstab /mnt/bedrock

##Setting up:
bedrock-mount /mnt/bedrock
if [ "${initial_strata}" = "Arch" ]; then
    arch_setup_main /mnt/bedrock
elif [ "${initial_strata}" = "Gentoo" ]; then
    gentoo_setup_main
elif [ "${initial_strata}" = "Debian" ]; then
    debian_setup_main
else 
    void_setup_main
fi 

##Last stage... from this point the user will finally be on their own
#bedrock-chroot /mnt/bedrock /bin/bash 
