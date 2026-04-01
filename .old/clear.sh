#!/bin/bash
set -e

# start timer for setup
START_TIME_CLEAR=$(date +%s)

# shellcheck source=$HOME/.bashrc
source ~/.bashrc

# helper function for colored echos
info() {
  utils/send_info.sh "$*"
}

echo "[+] Starting cleanup of local Kubernetes cluster and DEV_TAGS file..."

info "Cleaning up Kubernetes resources for rubrionmc..."
kubectl delete all --all -n rubrionmc

info "Clearing DEV_TAGS file..."
DEV_TAGS_FILE="$(dirname "$0")/.run/DEV_TAGS"
. > "$DEV_TAGS_FILE"
info "DEV_TAGS file cleared: $DEV_TAGS_FILE"

END_TIME_CLEAR=$(date +%s)
RUNTIME_CLEAR=$((END_TIME_CLEAR - START_TIME_CLEAR))
echo "[*] Done: Cleared Kubernetes resources and DEV_TAGS file in ${RUNTIME_CLEAR}s."