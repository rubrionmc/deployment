#!/bin/sh
set -e

# helper function for colored echos
info() {
  util/send_info.sh "$*"
}

info "Apply redis as pub-sub and cache layer..."
kubectl apply -f deployments/redis.yaml -n "$NAMESPACE"