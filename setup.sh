#!/bin/bash
set -e

# shellcheck source=$HOME/.bashrc
source ~/.bashrc

# helper function for colored echos
info() {
  util/send_info.sh "$*"
}

# check kubectl
if ! command -v kubectl &> /dev/null; then
  echo "[x] Could not find 'kubectl': not installed. Please install kubectl."
  exit 1
fi

# check minikube
if ! command -v minikube &> /dev/null; then
  echo "[x] Minikube is not installed."
  echo "    Install: https://minikube.sigs.k8s.io/docs/start/"
  exit 1
fi

info "Minikube found."

# start minikube if not running
if ! minikube status &> /dev/null; then
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
if ! kubectl cluster-info &> /dev/null; then
  echo "[x] Could not connect to Kubernetes cluster even after starting minikube."
  exit 1
fi

info "Start deployment in k8s"
(
  ./deploy.sh
)
wait

echo "[+] Done:  Kubernetes cluster reachable."
