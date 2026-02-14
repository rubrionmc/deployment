#!/bin/bash
set -e

# shellcheck source=$HOME/.bashrc
source ~/.bashrc

# helper function for colored echos
info() {
  util/send_info.sh "$*"
}

echo "[*] Starting deployment to Kubernetes cluster..."

# load .env if it exists
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  info "Loading environment variables from $ENV_FILE"
  set -a
  # shellcheck source=.env
  . <(grep -v '^#' "$ENV_FILE")
  set +a
fi

# check env vars for GHCR
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

# check namespace
NAMESPACE="rubrionmc"
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
  info "Namespace '$NAMESPACE' does not exist. Creating..."
  kubectl create namespace "$NAMESPACE"
else
  info "Namespace '$NAMESPACE' already exists."
fi

info "All pre-checks passed!"

# clean up old deployment
info "Clean up all old rubrion deployments"
kubectl delete all --all -n rubrionmc

# create GHCR secret if using remote images
info "Creating Kubernetes secret for GHCR..."
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USERNAME" \
  --docker-password="$GITHUB_TOKEN" \
  --docker-email=ghcr@localhost \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -


# apply deployment YAMLs with dynamic image tag
info "Applying Kubernetes deployments..."
NAMESPACE=$NAMESPACE deployments/wayguard.sh
NAMESPACE=$NAMESPACE deployments/redis.sh
NAMESPACE=$NAMESPACE deployments/mariadb.sh

info "Deployment complete! Check 'kubectl get pods -n $NAMESPACE' to see the status of your pods."