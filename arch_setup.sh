#!/usr/bin/bash

set -eau pipefail
##This script is for setting up arch, ie, installing bootloaders and shit.
##It requires only one thing:... Well, two things. No, wait... three things.    Kernel, Bootloader and directory
##Dependencies: pacstrap. Just pacstrap.

exec_as_chroot() {
    log sudo chroot /mnt/bedrock "$@" ##For this installer, everything is assumed to be at /mnt/bedrock as per the code. so this is safe to hardcode.
}
arch_setup() {
    local directory=$1
    sudo pacstrap -K "${directory}" base linux-firmware sudo ##Just updating bash and making sure mirrors are available.
    run_as_chroot pacman-key --init
    run_as_chroot pacman-key --populate archlinux ##Setting up keys and all.
    run_as_chroot pacman -Syu --noconfirm
}

inst() {
    run_as_chroot pacman -S --noconfirm $@
}

arch_setup_bootloader() {
    if [ "${bootloader}" = "grub" ]; then
        inst grub efibootmgr
        run_as_chroot grub-install --efi-directory=/boot --bootloader-id="Bedrock Linux" ##/boot is hardcoded to be the efi partition in archlinux
        run_as_chroot grub-mkconfig -o /boot/grub/grub.cfg
    fi 
}

arch_setup_kernel() {
    ##Options: linux, linux-lts, linux-zen.
    kernel=$(zenity --title="Select your kernel" --list --column="NAME" "Linux-Zen" "Linux" "Linux-lts")
    kernel="${kernel,,}"
    
    inst "${kernel}" "${kernel}"-headers
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
            inst pacman -S fish
            ;;
        *)
            true
            ;;
    esac

}

arch_setup_de() {
    zenity --text-info "Now installing a desktop environment"
    local de=$(zenity --list --title "Select An Option from the following." --column="Name" "Gnome" "Kde" "Xfce" "i3" "Hyprland")
    case "${de,,}" in 
        gnome)
            inst gnome gnome-tweaks
            ;;
        kde)
            inst plasma-meta
            ;;
        xfce)
            inst xfce
            ;;
        i3)
            inst i3-wm
            ;;
        hyprland)
            inst hyprland kitty
            ;;
        *)
            true
            ;;
    esac
}

arch_setup_greeter() {
    zenity --text-info "Now installing a greeter"
    local greet=$(zenity --list --title "Select an option from the following." --column="Name" "gdm" "sddm" "tty")
    case "${greet}" in 
        gdm)
            inst gdm
            run_as_chroot systemctl enable gdm
            ;;
        sddm)
            inst gdm
            run_as_chroot systemctl enable sddm
            ;;
        tty)
            log_msg "User just selected tty. Nothing to do in greeter section."
            ;;
        *)
            true
            ;;
    esac
}

arch_setup_extras() {
    extra_packages=$(zenity --title "Installing extra softwares!" --entry --text="Now enter the packages you would like preinstalled. Seperate the packages with a space. eg: firefox waybar ...")
    for pkgs in $extra_packages; do 
        inst "${pkgs}" || true
    done 
}

arch_setup_main() {
    local directory=$1

    arch_setup "${directory}"
    arch_setup_kernel
    arch_setup_bootloader
    arch_setup_user
    arch_setup_shell
    arch_setup_de
    arch_setup_greeter
    arch_setup_extras
}
