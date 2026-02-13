#!/bin/bash
set -e

# shellcheck source=$HOME/.bashrc
source ~/.bashrc

# helper function for colored echos
info() {
  util/send_info.sh "$*"
}

info "Cleaning up Kubernetes resources for rubrionmc..."
kubectl delete all --all -n rubrionmc

info "Unset LOCAL_DEV_TAGS for current shell..."
unset LOCAL_DEV_TAGS

BASHRC="$HOME/.bashrc"
if grep -q "export LOCAL_DEV_TAGS=" "$BASHRC"; then
    sed -i.bak "/export LOCAL_DEV_TAGS=/d" "$BASHRC"
    info "LOCAL_DEV_TAGS removed from $BASHRC"
fi

FISH_CONF="$HOME/.config/fish/config.fish"
if grep -q "set -x LOCAL_DEV_TAGS" "$FISH_CONF"; then
    sed -i.bak "/set -x LOCAL_DEV_TAGS/d" "$FISH_CONF"
    info "LOCAL_DEV_TAGS removed from $FISH_CONF (Fish)"
fi

echo "[+] Done! Restart your shell to apply changes."