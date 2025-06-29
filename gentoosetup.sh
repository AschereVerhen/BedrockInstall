#!/bin/bash

##This is a submodule for main.sh... it is the submodule which defines gentoo_setup_main...

set -eau pipefail

exec_as_chroot() {
    log sudo chroot /mnt/bedrock $@
}

inst() {
    exec_as_chroot emerge -aqv "$@"
}

gentoo_setup() {
    sudo cp -r /etc/resolv.conf /mnt/bedrock/etc/
    exec_as_chroot emerge-webrsync
    exec_as_chroot emerge --sync
}


make.conf_setup() {
    makeconf=$(zenity --title="select default USE presets from the following: " --list --column="Name" --column="info" \
        "Gnome" "A functional default USE for gnome desktop environment"\
        "Kde" "A functional default USE for kde plasma desktop environment"\
        "Hyprland" "A functional default USE for hyprland environments."\
        "Manual" "A option to make your own make.conf(Warn: Only for advanced users. Might break your system.)")
    if [ "${makeconf}" = "Gnome" ]; then
        echo "USE=\"X wayland gnome gtk gtk3 cairo avahi branding -kde -qt5 -qt6\"" | sudo tee -a /mnt/bedrock/etc/portage/make.conf
    elif [ "${makeconf}" = "Kde" ]; then
        echo "USE=\"X wayland kde plasma qt5 qt6 opengl egl systemd pulseaudio\"" | sudo tee -a /mnt/bedrock/etc/portage/make.conf
    elif [ "${makeconf}" = "Hyprland" ]; then
        echo "USE=\"wayland -X -qt5 -qt6 -kde -gnome vulkan pipewire systemd\"" | sudo tee -a /mnt/bedrock/etc/portage/make.conf
    else 
        true
    fi
}


make.conf.man_setup() { ##IF user selected manual in the above section.
    zenity --text-info "Now you can edit your make.conf in the newly opened kitty window."
    sudo cp -r /mnt/bedrock/etc/portage/{make.conf, make.conf.bak}
    kitty --hold bash -c "cd /mnt/bedrock/etc/portage/;sudo vim make.conf"
    zenity --question --text="Alrighty, Are you sure you want to keep the changes?"
    if [ "$?" -eq 0 ]; then
        true
    else 
        sudo rm -rf /mnt/bedrock/etc/portage/make.conf 
        sudo mv /mnt/bedrock/etc/portage/make.conf.bak /mnt/bedrock/etc/portage/make.conf 
    fi 
}

binary_setup() {
    exec_as_chroot getuto ##To install binary package signature incase user uses --getbinpkgs.
}

mirrors_setup() {
    inst app-portage/mirrorselect
    exec_as_chroot mirrorselect -i -o >> /etc/portage/make.conf
}

profile_setup() {
    profile_selected=$(zenity --list --title="Choose your Gentoo profile" \
  --column="Profile Name" --column="Description" \
  "desktop"           "Standard multilib desktop profile(For hyprland)" \
  "no-multilib"       "For minimal 64-bit-only installs (Steam via Flatpak only!)" \
  "desktop/plasma"    "KDE Plasma desktop" \
  "desktop/gnome"     "GNOME desktop" \
  "hardened"          "Security-hardened setup (with PaX/Grsecurity)" \
  "developer"         "For devs with extra tools enabled")
    case "${profile_selected}" in 
        desktop)
            profile_no=$(run_as_chroot eselect profile list | grep -w "desktop (stable)" | grep -v split-usr | cut -d "[" -f2 | cut -d "]" -f1)
            exec_as_chroot eselect profile set "${profile_no}"
            ;;
        no-multilib)
            profile_no=$(run_as_chroot  eselect profile list | grep -w "no-multilib (stable)" | grep -v split-usr | cut -d "[" -f2 | cut -d "]" -f1)
            exec_as_chroot eselect profile set "${profile_no}"
            ;;
        desktop/plasma)
            profile_no=$(run_as_chroot eselect profile list | grep -w "desktop/plasma (stable)" | grep -v split-usr | cut -d "[" -f2 | cut -d "]" -f1)
            exec_as_chroot eselect profile set "${profile_no}"
            ;;
        desktop/gnome)
            profile_no=$(run_as_chroot eselect profile list | grep -w "desktop/gnome (stable)" | grep -v split-usr | cut -d "[" -f2 | cut -d "]" -f1)
            exec_as_chroot eselect profile set "${profile_no}"
            ;;
        hardened)
            profile_no=$(run_as_chroot eselect profile list | grep -w "hardened (stable)" | grep -v no-multilib | grep -v split-usr/ | cut -d "[" -f2 | cut -d "]" -f1)
            exec_as_chroot eselect profile set "${profile_no}"
            ;;
        developer)
            profile_no=$(run_as_chroot eselect profile list | grep -w "developer" | cut -d "[" -f2 | cut -d "]" -f1)
            exec_as_chroot eselect profile set "${profile_no}"
            ;;
        *)
            log_msg "Error log."
            exit 1
            ;;
    esac
}
cpu_flags_setup() {
    inst app-portage/cpuid2cpuflags
    exec_as_chroot echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags
}

licenses_setup() {
    licenses=$(zenity --list --checklist --title="Select which licenses you want." --text="Now, from the options below, select which licenses you want." --column="" --column="Name" --column="Info"\
        "" "@Free" "Software licenses that are free as in freedom. Recommended."\
        "" "@BINARY-REDISTRIBUTABLE" "Software that are atleast allowed to be distributed. (Free as in price)"\
        "" "@EULA" "License agreements that try to take away your rights.")
    if  [ ! -z "${licenses}" ]; then
        echo "ACCEPT_LICENSES=\"$(echo \"${licenses}\" | sed 's/|/ /g' | awk {print $1, $2, $3})\"" | sudo tee -a /mnt/bedrock/etc/portage/make.conf
    else 
        echo "ACCEPT_LICENSES=\"*\"" | sudo tee -a /mnt/bedrock/etc/portage/make.conf
    fi
}

keyword_setup() {
    zenity --question --title="Keywords" --text="Would you like to accept ~amd64 keyword?"
    if [ $? -eq "0" ]; then
        echo "ACCEPT_KEYWORDS=\"~amd64\"" | sudo tee -a /mnt/bedrock/etc/portage/make.conf
    fi 
}

install_kernel() {
    inst linux-firmware

    kernel=$(zenity --list --title="Select your kernel" --text="Would you like Prebuilt Kernel or manually compile one?" --column="Name" --column="Description" "Prebuilt Kernel" "Installs gentoo-kernel-bin. Recommened for New users." "Manual Compilation" "Recommended for veterans.")
    case "${kernel}" in 
        "Prebuilt Kernel")
            echo "*/* dist-kernel" | sudo tee -a /mnt/bedrock/etc/portage/package.use/00kernel
            echo "sys-kernel/installkernel dracut " | sudo tee -a /mnt/bedrock/etc/portage/package.use/00kernel
            inst installkernel gentoo-kernel-bin
            ;;
        "Manual Compilation")
            inst gentoo-sources
            ;;
        *)
            exit 1
            ;;

    esac
}
compile_kernel() {
    zenity --text-info "Now starting compilation of the kernel... make sure to save changes as \".config\""
    cd /mnt/bedrock/usr/src/linux-*
    kitty --hold bash -c "sudo make menuconfig"
    echo "sys-kernel/installkernel dracut " | sudo tee -a /mnt/bedrock/etc/portage/package.use/00kernel
    inst installkernel
    exec_as_chroot sudo make -j12; sudo make -j12 modules; sudo make -j12 modules_install; sudo make -j12 headers; sudo make -j12 headers_install; sudo make install; zenity --text-info "Kernel succesfully compiled" || false; zenity --text-info "Kernel failed to compile. Please see what happened."
}

gpu_setup() {
    inst pciutils
    
    gpu_info=$(lspci | grep -i 'vga\|3d\|display')

    if echo "$gpu_info" | grep -qi nvidia; then
        echo "Detected NVIDIA GPU"
        GPU_TYPE="nvidia"
    elif echo "$gpu_info" | grep -qi amd; then
        echo "Detected AMD GPU"
        GPU_TYPE="amd"
    elif echo "$gpu_info" | grep -qi intel; then
        echo "Detected Intel GPU"
        GPU_TYPE="intel"
    else
        echo "Could not detect known GPU"
        GPU_TYPE="unknown"
    fi
    case "${GPU_TYPE}" in 
        nvidia)
            echo "*/* VIDEO_CARDS: nvidia" >> /mnt/bedrock/etc/portage/package.use/00video_cards
            inst ACCEPT_LICENSE="*" ACCEPT_KEYWORDS="~amd64" x11-drivers/nvidia-drivers || log_msg "Nvidia drivers failed to compile. Panic. Will throw you into tui."
            ;;
        amd)
            echo "*/* VIDEO_CARDS: amdgpu radeon" >> /mnt/bedrock/etc/portage/package.use/00video_cards
            inst x11-drivers/xf86-video-amdgpu || log_msg "Amd drivers failed to compile. Panic. Will throw you into tui."
            ;;
        intel)
            echo "*/* VIDEO_CARDS: intel" >> /mnt/bedrock/etc/portage/package.use/00video_cards
            inst x11-drivers/xf86-video-intel || log_msg "Intel drivers failed to compile. Panic. Will throw you into tui."
            ;;
        *)
            echo "Will have to throw you into the tui as i failed to check the gpu."
            ;;
    esac
}

hostname() {
    host_name="$(zenity --entry --title="Hostname Setting" --text="Please enter your hostname")"
    echo "${host_name}" >> /etc/hostname
}

networking() {
    inst dhcpcd net-wireless/iw net-wireless/wpa_supplicant
    exec_as_chroot rc-update add dhcpcd default
    exec_as_chroot rc-service dhcpcd start || true
}

logger() {
    inst app-admin/sysklogd
    exec_as_chroot rc-update add sysklogd default
}

filesystem() {
    inst sys-fs/e2fsprogs sys-fs/dosfstools sys-fs/btrfs-progs sys-fs/ntfs3g
}

bootloader() {
    local root_part=$1
    boot="$(zenity --list --title="Bootloader" --text="Select a bootloader" --column="Name" --column="Platforms" "GRUB" "EFI&BIOS" \
        "systemd-boot" "EFI only.")"

    case "${boot}" in 
        GRUB)
            if [ -e /sys/firmware/efi ]; then
                inst grub efibootmgr 
                exec_as_chroot grub-install --efi-directory=/boot --bootloader-id="Bedrock" ##Using bedrock installer, this is the only correct was to install. Do not follow the handbook guide. it will break fstab generation.
                exec_as_chroot grub-mkconfig -o /boot/grub/grub.cfg
            else 
                inst grub
                exec_as_chroot grub-install "${root_part}" ##Need to inherit this variable from the main.sh file.
                exec_as_chroot grub-mkconfig -o /boot/grub/grub.cfg
            fi 
            ;;
    esac ##I am not implimenting systemd-boot for now. I do not understand it and will come back later to impliment.
}


arch_setup_user() {
    zenity --text-info "Now making a new useraccount."
    username=$(zenity --entry --title="UserName" --text="Please enter an Username")
    username="${username,,}"
    log_msg "Username is: ${username}"
    password=$(zenity --password --title="Password" --text="Select your password")
    local password_check=$(zenity --password --title="Password Check" --text="Please enter your password again")
    if [ "${password}" = "${password_check}" ]; then
        exec_as_chroot useradd -m -G input,video,audio -s /bin/bash "${username}"
        exec_as_chroot echo "${username}:${password}" | chpasswd
        log_msg "Useraccount created. Now making the user sudo."
        inst sudo
        echo "${username} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/"${username}"
    else 
        log_msg "Useraccount Not created. Skipping."
    fi 
} 

arch_setup_shell() {
    zenity --text-info "Now installing a new shell."
    local shell=$(zenity --list --title "Selecting a shell" --column="Name" --column="info" "bash" "The default shell. simple yet reliable." "zsh" "An improved version of bash." "fish" "A user-friendly shell with pretty looks.")
    case "${shell}" in 
        bash)
            log_msg "Shell selected: Bash. Already installed. Skipping."
            ;;
        zsh) 
            inst zsh
            ;;
        fish)
            inst fish
            ;;
        *)
            true
            ;;
    esac

}



gentoo_setup_main() {
    local root_part=$1
    gentoo_setup
    make.conf_setup
    if [ "${makeconf}" = "Manual" ]; then
        make.conf.man_setup
    fi 
    binary_setup
    mirrors_setup
    profiles_setup
    cpu_flags_setup
    licenses_setup
    keyword_setup
    install_kernel
    if [ "${kernel}" = "Manual Compilation" ]; then
        compile_kernel
        if [ ! $? -eq 0 ]; then
            inst gentoo-kernel-bin; zenity --text-info text="Falling back to binary kernel."
        fi 
    fi 
    gpu_setup
    hostname
    networking
    logger
    filesystem
    bootloader "${root_part}"
    setup_user
    setup_shell
}
