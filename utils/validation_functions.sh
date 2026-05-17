#!/usrbin/bash
#
# Validation functions called by other functions and scripts

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

# Ensure that the network is active, as it is required for downloading packages
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
function is_network_up()
{
  if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
    custom_log "debug" "Internet is reachable"
  else
    custom_log "error" "Internet not reachable"
    return 1
  fi
}

# Ensure that the script is being ran as root
# Globals:
#   EUID
# Arguments:
#   None
# Outputs:
#   None
function is_root()
{
  if [[ "${EUID}" -eq 0 ]]; then
    custom_log "debug" "Function is being ran as root"
  else
    custom_log "error" "This function must be run as root."
    return 1
  fi
}
