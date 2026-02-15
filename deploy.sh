#!/bin/bash
set -e

# start timer for deployment
START_TIME_DEPLOY=$(date +%s)

# shellcheck source=$HOME/.bashrc
source ~/.bashrc

# helper function for colored echos
info() {
  utils/send_info.sh "$*"
}

echo "[+] Starting deployment to Kubernetes cluster..."

# load .env if it exists
ENV_FILE=".env"
PID_FILE=".run/forward.pid"
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

# kill old port-forward if running
info "Checking for existing port-forward process..."
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        info "Killing old port-forward process (PID $OLD_PID)"
        kill "$OLD_PID"
        #sleep 1
    fi
    rm -f "$PID_FILE"
fi

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
NAMESPACE=$NAMESPACE deployments/nonconnector.sh
NAMESPACE=$NAMESPACE deployments/redis.sh
NAMESPACE=$NAMESPACE deployments/mariadb.sh

info "Deployment complete! Check 'kubectl get pods -n $NAMESPACE' to see the status of your pods."

# start port forwarding for wayguard
info "Start port forwarding for wayguard (port 25565) to access them locally..."
kubectl port-forward -n rubrionmc svc/wayguard 25565:25565 \
    > /dev/null 2>&1 &
NEW_PID=$!
echo "$NEW_PID" > "$PID_FILE"

END_TIME_DEPLOY=$(date +%s)
RUNTIME_DEPLOY=$((END_TIME_DEPLOY - START_TIME_DEPLOY))
echo "[*] Done: deployed in ${RUNTIME_DEPLOY}s"