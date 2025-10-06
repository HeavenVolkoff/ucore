#!/usr/bin/env -S bash -eou pipefail

log() {
  local green='\033[0;32m'
  local no_color='\033[0m' # Reset color

  if [ -z "$1" ]; then
    echo "Usage: log_info \"<message>\""
    return 1
  fi

  echo
  echo -e "${green}INFO:${no_color} $1"
}
