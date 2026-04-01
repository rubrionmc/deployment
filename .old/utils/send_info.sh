#!/bin/sh
set -e

BLUE='\033[34m'
RESET='\033[0m'


if [ "$#" -eq 0 ]; then
  echo "Usage: $0 \"message\""
  exit 1
fi

# shellcheck disable=SC3037
echo -e "${BLUE} => $*${RESET}"
