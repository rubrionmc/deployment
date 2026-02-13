#!/bin/sh
set -e

# helper function for colored echos
info() {
  util/send_info.sh "$*"
}

# --- sanity check for required environment variables ---
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"
: "${NAMESPACE:?NAMESPACE is required}"

info "Applying mariadb deployment with persistent volume..."

# update mariadb.yaml with dynamic placeholders
sed \
  -e "s|{{SECRET_ROOT_PASSWORD}}|$SECRET_ROOT_PASSWORD|" \
  -e "s|{{USER_DATABASE}}|$USER_DATABASE|" \
  -e "s|{{MYSQL_USER}}|MYSQL_USER|" \
  -e "s|{{MYSQL_PASSWORD}}|$MYSQL_PASSWORD|" \
  deployments/mariadb.yaml | kubectl apply -f - -n "$NAMESPACE"
