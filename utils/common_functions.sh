#!/bin/bash
#
# Common functions with minimal dependencies meant to be sourced into scripts

# Displays log messages depending on a user defined log level
# Globals:
#   USER_LOG_LEVEL
# Arguments:
#   msg_level
#   msg
# Outputs:
#   * A log message if log level is equal to or less than USER_LOG_LEVEL
# Usage:
#
#   custom_log "warn" "Not all items in /etc/fstab can be mounted"
#
function custom_log()
{
  # Assign variables to inputs
  local msg_level=${1,,}
  local readonly msg=${@:2}
  if [[ -n "${USER_LOG_LEVEL}" ]]; then
    local readonly user_level=${USER_LOG_LEVEL,,}
  else
    local readonly user_level="info"
  fi

  # Make sure the logic of the function doesn't break if "color" is defined globally
  unset color

  # For eqdh log level, determine if it is within the scope of the user log level
  # If so, assign the label a color so that it will be displayed later
  case "${msg_level}" in
    debug)
      [[ "${user_level}" =~ ^(debug)$ ]] && local readonly color=39
    ;;
    info)
      [[ "${user_level}" =~ ^(debug|info)$ ]] && local readonly color=46
    ;;
    warn)
      [[ "${user_level}" =~ ^(debug|info|warn)$ ]] && local readonly color=214
    ;;
    error)
      [[ "${user_level}" =~ ^(debug|info|warn|error)$ ]] && local readonly color=196
    ;;
    fatal)
      [[ "${user_level}" =~ ^(debug|info|warn|error|fatal)$ ]] && local readonly color=196
    ;;
    * )
      custom_log "WARN" "${msg_level} is not a valid log level!"
      local readonly color=240
    ;;
    esac

  # If a color isn't assigned, then the log message can be skipped
  [[ -z "${color}" ]] && return 0

  # Colorize the log level font based on what was defined above
  local readonly colored="\033[38;5;${color};1m"
  local readonly default="\033[0m"

  # Display the log
  printf "%s [${colored}%s${default}] %s\n" "$( date +"%d %b %H:%M" )" "${msg_level^^}" "${msg}"
}

# Check that variables for the sourcing script are defined
# Globals:
#   None
# Arguments:
#   vars
# Outputs:
#   * An error message if required variables are not set
# Usage:
#
#   local readonly required_variables=( var1 var2 ... )
#   check_required_variables ${required_variables[@]}
#   local return_code=$?
#   if [[ ${return_code} -ne 2 ]]; then
#     custom_log 1 "Required variables are not set!"
#     exit ${return_code}
#   fi
#
function check_required_variables()
{
  # For each variable that is required, check if it is defined
  local readonly vars=${@}
  local return_code=0
  for var in ${vars[@]}; do
    if declare -p ${var} &>/dev/null; then
      custom_log "debug" "${var} is set!"
    else
      custom_log "error" "${var} is not set and is required!"
      local return_code=$(( ${return_code} + 1 ))
    fi
  done

  # Tells the sourcing script how many errors were encountered
  return ${return_code}
}

# Sources in script dependencies
# Globals:
#   None
# Arguments:
#   script_dependencies
# Outputs:
#   * Sources in dependencies or returns an error if dependencies cannot be sourced in
# Usage:
#
#   local readonly script_dependencies=( /tmp/dep1 /tmp/dep2 )
#   source_dependencies ${script_dependencies[@]}
#   local return_code=$?
#   if [[ ${return_code} =~ ^[6-7]$ ]]; then
#     custom_log 1 "Dependencies could not be sourced in"
#     exit ${return_code}
#   fi
#
function source_dependencies()
{
  local readonly dependencies=${@}
  local return_code=0
  for dependency in ${dependencies[@]}; do
    # For each dependency, first ensure if it is readable
    if [[ ! -r ${dependency} ]]; then
      custom_log "error" "Unable to source ${dependency}; ${dependency} not readable"
      local return_code=$(( ${return_code} + 1 ))
      continue
    fi
    custom_log "debug" "Able to read ${dependency}"
    # If the script dependency is readable, try sourcing it in
    source ${script_dependency}
    if [[ $? -eq 0 ]]; then
      custom_log "debug" "Successfuly sourced in ${dependency}"
    else
      custom_log "error" "Unable to source in ${dependency}"
      local return_code=$(( ${return_code} + 1 ))
    fi
  done

  # Tells the sourcing script how many errors were encountered
  return ${return_code}
}

