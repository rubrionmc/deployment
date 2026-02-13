#!/bin/bash
set -e

# load .env if it exists
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  echo " => Loading environment variables from $ENV_FILE"
  set -a
  # shellcheck source=src/util.sh
  . <(grep -v '^#' "$ENV_FILE")
  set +a
fi

# check env vars
if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "[x] Please set GITHUB_USERNAME and GITHUB_TOKEN environment variables (or in .env file)"
  exit 1
fi

# check kubectl
if ! command -v kubectl &> /dev/null; then
  echo "[x] Could not find 'kubectl': not installed. Please install kubectl."
  exit 1
fi

# check kubectl cluster connection
if ! kubectl cluster-info &> /dev/null; then
  echo "[x] Could not connect to Kubernetes cluster. Is your kubeconfig correct?"
  exit 1
fi

# check minikube
if command -v minikube &> /dev/null; then
  if ! minikube status &> /dev/null; then
    echo "[!] Minikube installed but cluster not running or not reachable."
  fi
fi

# check kind
if command -v kind &> /dev/null; then
  if ! kind get clusters &> /dev/null; then
    echo "[!] Kind installed but no clusters found."
  fi
fi

# check namespace
NAMESPACE="rubrionmc"
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
  echo " => Namespace '$NAMESPACE' does not exist. Creating..."
  kubectl create namespace "$NAMESPACE"
else
  echo " => Namespace '$NAMESPACE' already exists."
fi

echo "[+] All pre-checks passed!"

#clean up old deployment
echo " => Clean up all old rubrion deployments"
kubectl delete all --all -n rubrionmc

# create GHCR secret dynamically
echo " => Creating Kubernetes secret for GHCR..."
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USERNAME" \
  --docker-password="$GITHUB_TOKEN" \
  --docker-email=ghcr@localhost \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# apply deployment YAMLs
echo " => Applying Kubernetes deployments..."

# apply wayguard
echo " => Apply wayguard..."
kubectl apply -f deployments/wayguard.yaml -n "$NAMESPACE"
echo " => Restarting wayguard to pick up new local image..."
kubectl rollout restart deployment wayguard-deployment -n "$NAMESPACE" # maby remove in prod
