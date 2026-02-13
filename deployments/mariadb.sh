#!/bin/sh
set -e

# helper function for colored echos
info() {
  util/send_info.sh "$*"
}

info "Apply mariadb with persistent volume..."
kubectl apply -f deployments/mariadb.yaml -n "$NAMESPACE"