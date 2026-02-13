#!/bin/sh
set -e

# helper function for colored echos
info() {
  util/send_info.sh "$*"
}

: "${REDIS_PASSWORD:?REDIS_PASSWORD is required}"
: "${NAMESPACE:?NAMESPACE is required}"


# dynamic password replace in deployment
info "Apply Redis as pub-sub and cache layer..."
sed \
  -e "s|{{REDIS_PASSWORD}}|$REDIS_PASSWORD|" \
  deployments/redis.yaml | \
kubectl apply -f - -n "$NAMESPACE"