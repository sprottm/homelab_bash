#!/bin/bash
#
# Used for setting up my Arch Linux system from the liveinstall
# Not using Archinstall because I want more customizability

# Display script usage and exit
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
function display_usage()
{
  echo "Usage: ${0} [OPTIONS]"
    echo ''

    local FORMAT="  %-3s  %-6s  %-18s  %-5s  %s\n"

    printf "\033[1m${FORMAT}\033[0m" "Req" "Short" "Long" "Input" "Description"
    echo ''

    printf "${FORMAT}" "*" "-d" "--drive" "Yes" "Define drive to install Arch Linux onto (i.e. /dev/sda)"
    printf "${FORMAT}" "" "-g" "--volume-group" "Yes" "Define name of volume group (default = vgroot)"
    printf "${FORMAT}" "" "" "--log-level" "Yes" "Define log level for messages (default = info)"
    printf "${FORMAT}" "" "-h" "--help" "No" "Display usage and exit"
}

# Source in the common functions before running the script
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
function source_dependencies()
{
  # Source in utility script, fail if it can't be sourced
  local -r script_directory=$( dirname ${0} )
  local -r script_utils_directory=${script_directory}/utils
  source ${script_utils_directory}/common_functions.sh
  local exit_code=${?}
  if [[ ${exit_code} -ne 0 ]]; then
    echo "[FATAL] Unable to source in common_functions.sh"
    exit ${exit_code}
  fi

  local -r script_dependencies=( \
    utils/setup_partitions.sh \
    utils/setup_packages.sh \
    utils/validation_functions.sh \
  )
  source_dependencies "${script_dependencies[@]}"
  local exit_code=${?}
  if [[ "${exit_code}" -ne 0 ]]; then
    custom_log "error" "Dependencies could not be sourced in"
    exit ${exit_code}
  fi
}

# Define variables used by the other functions depending on user input
# Globals:
#   None
# Arguments:
#   *User input to script
# Outputs:
#   PRIMARY_DRIVE
function define_variables()
{
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d | --drive)
        if is_block_device "${2}"; then
          PRIMARY_DRIVE="${2}"
          shift
        else
          return 1
        fi
      ;;
      -g | --volume-group )
        volume_group="${2}"
        shift
      ;;
      --log-level)
        USER_LOG_LEVEL="${2}"
        shift
      ;;
      -h | --help)
        display_usage
        exit 0
      ;;
      *)
        custom_log "error" "Unknown option: ${1}"
        return 1
      ;;
    esac
    shift
  done 

  [[ -z "${VOLUME_GROUP}" ]] && VOLUME_GROUP="vgroot"

  # Check if required variables were defined
  local readonly required_variables=( PRIMARY_DRIVE VOLUME_GROUP )
  check_required_variables "${required_variables[@]}"
  local return_code=$?
  if [[ "${return_code}" -ne 0 ]]; then
    custom_log "error" "Required variables are not set!"
    return "${return_code}"
  fi
}

source_dependencies
define_variables ${*} || exit 1
is_network_up || exit 1
is_root || exit 1
is_block_device || exit 1
create_partitions "${PRIMARY_DRIVE}"
format_partitions "${PRIMARY_DRIVE}" "${VOLUME_GROUP}"
set_mirrors
install_packages
postinstall "${VOLUME_GROUP}"

