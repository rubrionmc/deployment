#!/bin/bash
set -e

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

echo " => Minikube found."

# start minikube if not running
if ! minikube status &> /dev/null; then
  echo " => Minikube not running. Starting..."
  minikube start --driver=docker
else
  echo " => Minikube already running."
fi

# set kubectl context
echo " => Setting kubectl context to minikube..."
kubectl config use-context minikube >/dev/null

# check cluster connection
echo " => Checking Kubernetes connection..."
if ! kubectl cluster-info &> /dev/null; then
  echo "[x] Could not connect to Kubernetes cluster even after starting minikube."
  exit 1
fi

echo "=> Start deployment in k8s"
(
  ./deploy.sh
)
wait

echo "[+] Done:  Kubernetes cluster reachable."
