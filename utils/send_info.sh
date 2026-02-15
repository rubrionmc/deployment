#!/bin/sh
set -e

# =========================
# ANSI colors
# =========================
BLUE='\033[34m'
RESET='\033[0m'

# =========================
# check args
# =========================
if [ "$#" -eq 0 ]; then
  echo "Usage: $0 \"message\""
  exit 1
fi

# =========================
# print message
# =========================
# shellcheck disable=SC3037
echo -e "${BLUE} => $*${RESET}"
