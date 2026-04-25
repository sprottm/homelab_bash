#!/bin/bash
#
# Used for setting up my Arch Linux system from the liveinstall
# Not using Archinstall because I want more customizability

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
  local readonly script_directory=$( dirname ${0} )
  local readonly script_utils_directory=${script_directory}/utils
  source ${script_utils_directory}/common_functions.sh
  local exit_code=${?}
  if [[ ${exit_code} -ne 0 ]]; then
    echo "[FATAL] Unable to source in common_functions.sh"
    exit 1
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
  # TODO: Add input validation and make inputs not rely on position
  PRIMARY_DRIVE="${1}"
  VOLUME_GROUP="vgroot" 

  # Check if required variables were defined
  local readonly required_variables=( PRIMARY_DRIVE VOLUME_GROUP )
  check_required_variables "${required_variables[@]}"
  local return_code=$?
  if [[ "${return_code}" -ne 0 ]]; then
    custom_log "fatal" "Required variables are not set!"
    exit "${return_code}"
  fi
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: This function must be run as root." 
  exit 1
fi

source_dependencies
define_variables ${*}
create_partitions "${PRIMARY_DRIVE}"
format_partitions "${PRIMARY_DRIVE}" "${VOLUME_GROUP}"
set_mirrors
install_packages
postinstall

