#!/bin/bash

function set_mirrors()
{
  local readonly mirrorlist=/etc/pacman.d/mirrorlist
  echo 'Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch' > ${mirrorlist}
  echo 'Server = https://mirrors.mit.edu/archlinux/$repo/os/$arch' >> ${mirrorlist}
  echo 'Server = https://mirrors.ocf.berkeley.edu/archlinux/$repo/os/$arch' >> ${mirrorlist}
}

function install_packages()
{
  # Install base packages
  pacstrap -K /mnt base linux linux-firmware

  # Install filesystem packages
  pacstrap -K /mnt xfsprogs lvm2

  # Install AMD drivers and ucode
  pacstrap -K /mnt amd-ucode mesa vulkan-radeon libva-mesa-driver xf86-video-amdgpu xf86-video-ati

  # Install networking tools
  pacstrap -K /mnt wpa_supplicant networkmanager

  # Install audio server and drivers
  pacstrap -K /mnt sof-firmware pipewire wireplumber pipewire-pulse pipewire-alsa pavucontrol alsa-ucm-conf alsa-utils 

  # Install display server, display environment, and audio drivers
  pacstrap -K /mnt gnome gnome-shell-extensions gdm

  # Configure the system for post-install configuration
  pacstrap -K /mnt ansible openssh vim sudo
}

function postinstall()
{
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/US/Eastern /etc/localtime
  arch-chroot /mnt hwclock --systohc

  #TODO uncomment line from /etc/locale.gen first
  arch-chroot /mnt locale-gen
  echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

  echo "blacktower" > /mnt/etc/hostname

  # Use systemd-boot as the bootloader
  bootctl --path=/mnt/boot install

  local readonly loader_config=/mnt/boot/loader/loader.conf
  printf "%-12s %-9s\n" "default" "arch.conf" > ${loader_config}
  printf "%-12s %-9s\n" "timeout" "3" >> ${loader_config}
  printf "%-12s %-9s\n" "console-mode" "max" >> ${loader_config}

  local readonly arch_boot_entry=/mnt/boot/loader/entries/arch.conf
  local readonly root_vol_path=/dev/mapper/vg_root-lv_root
  printf "%-8s %-30s\n" "title" "Arch Linux" > ${arch_boot_entry}
  printf "%-8s %-30s\n" "linux" "/vmlinuz-linux" >> ${arch_boot_entry}
  printf "%-8s %-30s\n" "initrd" "/amd-ucode.img" >> ${arch_boot_entry}
  printf "%-8s %-30s\n" "initrd" "/initramfs-linux.img" >> ${arch_boot_entry}
  printf "%-8s %-30s\n" "options" "root=${root_vol_path} rw" >> ${arch_boot_entry}

  # Insert lvm2 into hooks before filesystems and regenerate initramfs
  # TODO remove lvm2 from all hooks first
  sed -ie 's/filesystems/lvm2 filesystems/g'  /mnt/etc/mkinitcpio.conf
  arch-chroot /mnt mkinitcpio -p linux

  arch-chroot /mnt useradd -m -u 1000 -c "John Doe" -g wheel johndoe

  arch-chroot /mnt systemctl enable NetworkManager.service
  arch-chroot /mnt systemctl enable sshd.service
  arch-chroot /mnt systemctl enable gdm.service
  arch-chroot /mnt systemctl enable lvm2-monitor.service
  arch-chroot /mnt systemctl --global enable wireplumber.service
  arch-chroot /mnt systemctl --global enable pipewire.service
  arch-chroot /mnt systemctl --global enable pipewire-pulse.service

  echo "DON'T FORGET TO SET USER PASSWORD!!!"
}

