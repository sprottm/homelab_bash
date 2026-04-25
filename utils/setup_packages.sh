#!/bin/bash

function set_mirrors()
{
  local readonly mirrorlist=/etc/pacman.d/mirrorlist
  echo 'Server = https://mirror.arizona.edu/archlinux/$repo/os/$arch' > ${mirrorlist}
  echo 'Server = https://mirrors.mit.edu/archlinux/$repo/os/$arch' >> ${mirrorlist}
  echo 'Server = https://mirrors.ocf.berkeley.edu/archlinux/$repo/os/$arch' >> ${mirrorlist}
}

function install_packages()
{
  # Install base packages
  pacstrap -K /mnt base linux linux-firmware amd-ucode

  # Install filesystem packages
  pacstrap -K /mnt xfsprogs lvm2

  # Install AMD drivers and ucode
  pacstrap -K /mnt amd-ucode mesa vulkan-radeon libva-mesa-driver xf86-video-amdgpu xf86-video-ati

  # Install networking tools
  pacstrap -K /mnt wpa_supplicant networkmanager

  # Install audio server and drivers
  pacstrap -K /mnt sof-firmware pipewire wireplumber pipewire-pulse pipewire-alsa pavucontrol alsa-ucm-conf alsa-utils 

  # Install display manager and display environment
  pacstrap -K /mnt xfce4 lightdm lightdm-slick-greeter

  # Configure the system for post-install configuration
  pacstrap -K /mnt ansible openssh vim sudo
}

function postinstall()
{
  local -r volume_group="${1}"

  # Configure localization
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/US/Eastern /etc/localtime
  arch-chroot /mnt hwclock --systohc
  sed -ie 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /mnt/etc/locale.gen
  arch-chroot /mnt locale-gen
  echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
  echo 'KEYMAP=us' > /mnt/etc/vconsole.conf

  # Set my hostname
  echo "blacktower" > /mnt/etc/hostname

  # Use systemd-boot as the bootloader
  bootctl --path=/mnt/boot install

  # Configure the bootloader
  local readonly loader_config=/mnt/boot/loader/loader.conf
  printf "%-12s %-9s\n" "default" "arch.conf" > ${loader_config}
  printf "%-12s %-9s\n" "timeout" "3" >> ${loader_config}
  printf "%-12s %-9s\n" "console-mode" "max" >> ${loader_config}

  # Create our bootloader option
  local readonly arch_boot_entry=/mnt/boot/loader/entries/arch.conf
  local readonly root_vol_path="/dev/mapper/${volume_group}-lv_root"
  printf "%-8s %-30s\n" "title" "Arch Linux" > ${arch_boot_entry}
  printf "%-8s %-30s\n" "linux" "/vmlinuz-linux" >> ${arch_boot_entry}
  printf "%-8s %-30s\n" "initrd" "/amd-ucode.img" >> ${arch_boot_entry}
  printf "%-8s %-30s\n" "initrd" "/initramfs-linux.img" >> ${arch_boot_entry}
  printf "%-8s %-30s\n" "options" "root=${root_vol_path} rw" >> ${arch_boot_entry}

  # Insert lvm2 into hooks before filesystems and regenerate initramfs
  sed -i '/^HOOKS=/s/lvm2 //g' /mnt/etc/mkinitcpio.conf
  sed -ie 's/filesystems/lvm2 filesystems/g' /mnt/etc/mkinitcpio.conf
  arch-chroot /mnt mkinitcpio -p linux

  # Setup user account and their permissions
  arch-chroot /mnt useradd -m -u 1000 -c "Mike" -g wheel mike
  arch-chroot /mnt passwd mike
  echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /mnt/etc/sudoers.d/admin

  # Configure the slick greeter for lightdm
  echo '[Greeter]' > /mnt/etc/lightdm/slick-greeter.conf
  echo 'enable-hidpi=on' >> /mnt/etc/lightdm/slick-greeter.conf
  echo 'background=/usr/share/backgrounds/xfce/custom.png' >> /mnt/etc/lightdm/slick-greeter.conf

  # Make sure SSH service will launch
  arch-chroot /mnt ssh-keygen -A

  # Ensure my core services are enabled
  arch-chroot /mnt systemctl enable NetworkManager.service \
                                    sshd.service \
                                    lightdm.service \
                                    lvm2-monitor.service

  arch-chroot /mnt systemctl --global enable wireplumber.service \
                                             pipewire.service \
                                             pipewire-pulse.service
}
