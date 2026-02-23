#!/bin/bash
#
# From a liveinstall, create and format partitions, then mount them

# Ensures device is a block device
# Globals:
#   None
# Arguments:
#   block_device
# Outputs:
#   None
function is_block_device()
{
  local -r block_device="${1}"

  # Ensure primary_drive is a block device
  if [[  -b "${block_device}" ]]; then
    custom_log "debug" "${block_device} is a valid block device"
  else
    custom_log "error" "${block_device} is not a valid block device" 
    return 1
  fi
}

# Wipe the partitions on my drive and create new ones
# Globals:
#   None
# Arguments:
#   primary_drive
# Outputs:
#   None
function create_partitions()
{
  local -r primary_drive="${1}"

  # Ensure primary_drive is a block device
  is_block_device "${primary_drive}" || return 1

  # Wipe away previous partitions
  custom_log "info" "Wiping ${primary_drive}..."
  if wipefs --all --force "${primary_drive}"; then
    custom_log "info" "Successfully wiped ${primary_drive}"
  else
    custom_log "error" "Failed to wipe ${primary_drive}"
    return 1
  fi

  # Create the new partitions
  custom_log "info" "Partitioning ${primary_drive}..."
  parted --script --align optimal "${primary_drive}" \
    mklabel gpt \
    mkpart primary fat32 1MiB 1024MiB \
    set 1 esp on \
    mkpart primary linux-swap 1024MiB 5633MiB \
    mkpart primary 5633MiB 100% \
    set 3 lvm on
  local -r return_code=$?
  if [[ "${return_code}" -eq 0 ]]; then
    custom_log "info" "Successfully partitioned ${primary_drive}"
  else
    custom_log "error" "Failed to partition ${primary_drive}"
    return "${return_code}"
  fi

  # Do a final sync
  custom_log "info" "Syncing partition changes to the kernel..."
  partprobe "${primary_drive}"
}

# Format the partitions and setup my logical volumes, then mount/activate them
# Globals:
#   None
# Arguments:
#   primary_drive
#   volume_group
# Outputs:
#   None
function format_partitions()
{
  # Set the variables for the script to use
  local -r primary_drive_raw="${1}"
  local -r volume_group="${2}"
  if [[ "${primary_drive_raw##*/}" =~ ^nvme ]]; then
    local primary_drive="${primary_drive_raw}p"
  else
    local primary_drive="${primary_drive_raw}"
  fi

  # Ensure primary_drive is a block device
  is_block_device "${primary_drive}" || return 1

  # Format and activate swap partition
  custom_log "info" "Formatting the swap partition"
  mkswap -f -L "swap" "${primary_drive}2"
  if swapon "${primary_drive}2"; then
    custom_log "info" "Successfully formatted and activated the swap partition"
  else
    custom_log "error" "Failed to format and activate the swap partition"
    return 1
  fi

  # Format the physical volume
  # TODO: Improve the pvdisplay/vgdisplay greps
  custom_log "info" "Formatting the physical volume ${primary_drive}3"
  pvcreate "${primary_drive}3"
  if pvdisplay | grep -q "${primary_drive}3"; then
    custom_log "info" "Successfully formatted physical volume ${primary_drive}3"
  else
    custom_log "error" "Failed to format physical volume ${primary_drive}3"
    return 1
  fi

  # Create the volume group and ensure it was created
  custom_log "info" "Creating the volume group ${volume_group}"
  vgcreate "${volume_group}" "${primary_drive}3" 
  if vgdisplay | grep -q "${volume_group}"; then
    custom_log "info" "Successfully created volume group ${volume_group}"
  else
    custom_log "error" "Failed to create volume group ${volume_group}"
    return 1
  fi

  # Create logical volumes and ensure they were created
  # This is minimal, logical volumes can be extended later
  # TODO: Handle all of the logical volumes with a loop and an array
  lvcreate -L 20G -n lv_root "${volume_group}"
  is_block_device /dev/"${volume_group}"/lv_root || return 1
  lvcreate -L 20G -n lv_home "${volume_group}"
  is_block_device /dev/"${volume_group}"/lv_home || return 1
  lvcreate -L 10G -n lv_var "${volume_group}"
  is_block_device /dev/"${volume_group}"/lv_var || return 1
  lvcreate -L 5G -n lv_audit "${volume_group}"
  is_block_device /dev/"${volume_group}"/lv_audit || return 1
  lvcreate -L 5G -n lv_log "${volume_group}"
  is_block_device /dev/"${volume_group}"/lv_log || return 1
  lvcreate -L 2G -n lv_tmp "${volume_group}"
  is_block_device /dev/"${volume_group}"/lv_tmp || return 1

  # Format our new logical volumes with my preferred filesystem, XFS
  custom_log "info" "Formatting the logical volumes"
  mkfs.xfs -f -L "root" /dev/"${volume_group}"/lv_root
  if mount --mkdir /dev/"${volume_group}"/lv_root /mnt; then
    custom_log "info" "Successfully formatted and mounted the lv_root logical volume"
  else
    custom_log "error" "Failed to format and mount the lv_root logical volume"
    return 1
  fi
  mkfs.xfs -f -L "home" /dev/"${volume_group}"/lv_home
  if mount --mkdir /dev/"${volume_group}"/lv_home /mnt/home; then
    custom_log "info" "Successfully formatted and mounted the lv_home logical volume"
  else
    custom_log "error" "Failed to format and mount the lv_home logical volume"
    return 1
  fi
  mkfs.xfs -f -L "var" /dev/"${volume_group}"/lv_var
  if mount --mkdir /dev/"${volume_group}"/lv_var /mnt/var; then
    custom_log "info" "Successfully formatted and mounted the lv_var logical volume"
  else
    custom_log "error" "Failed to format and mount the lv_var logical volume"
    return 1
  fi
  mkfs.xfs -f -L "log" /dev/"${volume_group}"/lv_log
  if mount --mkdir /dev/"${volume_group}"/lv_log /mnt/var/log; then
    custom_log "info" "Successfully formatted and mounted the lv_log logical volume"
  else
    custom_log "error" "Failed to format and mount the lv_log logical volume"
    return 1
  fi
  mkfs.xfs -f -L "audit" /dev/"${volume_group}"/lv_audit
  if mount --mkdir /dev/"${volume_group}"/lv_audit /mnt/var/log/audit; then
    custom_log "info" "Successfully formatted and mounted the lv_audit logical volume"
  else
    custom_log "error" "Failed to format and mount the lv_audit logical volume"
    return 1
  fi
  mkfs.xfs -f -L "tmp" /dev/"${volume_group}"/lv_tmp
  if mount --mkdir /dev/"${volume_group}"/lv_tmp /mnt/tmp; then
    custom_log "info" "Successfully formatted and mounted the lv_tmp logical volume"
  else
    custom_log "error" "Failed to format and mount the lv_tmp logical volume"
    return 1
  fi

  # Format the boot partition
  custom_log "info" "Formatting the boot partition"
  mkfs.vfat -F 32 -I -n "efi" "${primary_drive}1"
  if mount --mkdir "${primary_drive}1" /mnt/boot; then
    custom_log "info" "Successfully formatted and mounted the boot partition"
  else
    custom_log "error" "Failed to format and mount the boot partition"
    return 1
  fi

  # Create etc directory on new root partition
  mkdir -p /mnt/etc
  if [[ -d /mnt/etc ]]; then
    custom_log "info" "Successfully created etc directory"
  else
    custom_log "error" "Failed to create etc directory"
  fi

  # Create filesystem table on new root partition
  genfstab -L /mnt > /mnt/etc/fstab
  if [[ -f /mnt/etc/fstab ]]; then
    custom_log "info" "Successfully created filesystem table"
  else
    custom_log "error" "Failed to create filesystem table"
  fi
}

