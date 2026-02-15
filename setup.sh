#!/bin/bash
set -e

# helper function for colored echos
info() {
  utils/send_info.sh "$*"
}

echo "[*] Setting up local Kubernetes cluster with Minikube..."

# check kubectl
command -v kubectl >/dev/null || { echo "[x] kubectl not installed"; exit 1; }

# check minikube
command -v minikube >/dev/null || { echo "[x] minikube not installed"; exit 1; }

info "Minikube found."

# start minikube if not running
if ! minikube status --format='{{.Host}}' | grep -q Running; then
  info "Minikube not running. Starting..."
  minikube start --driver=docker
else
  info "Minikube already running."
fi

# set kubectl context
info "Setting kubectl context to minikube..."
kubectl config use-context minikube >/dev/null

# check cluster connection
info "Checking Kubernetes connection..."
kubectl cluster-info >/dev/null || { echo "[x] Kubernetes not reachable"; exit 1; }

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
WORKSPACE_DIR="$(dirname "$SCRIPT_PATH")"

info "Setting RK8S=$WORKSPACE_DIR"

# bash
sed -i '/export RK8S=/d' "$HOME/.bashrc" 2>/dev/null || true
echo "export RK8S=\"$WORKSPACE_DIR\"" >> "$HOME/.bashrc"

# zsh
sed -i '/export RK8S=/d' "$HOME/.zshrc" 2>/dev/null || true
echo "export RK8S=\"$WORKSPACE_DIR\"" >> "$HOME/.zshrc"

# fish
mkdir -p "$HOME/.config/fish"
sed -i '/set -x RK8S/d' "$HOME/.config/fish/config.fish" 2>/dev/null || true
echo "set -x RK8S \"$WORKSPACE_DIR\"" >> "$HOME/.config/fish/config.fish"

# current shell
export RK8S="$WORKSPACE_DIR"

info "Start deployment in k8s"
./deploy.sh

echo "[+] Done: Kubernetes cluster reachable."
