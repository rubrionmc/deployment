#!/bin/sh
set -e

# ANSI colors
BLUE='\033[34m'
RESET='\033[0m'

# helper function for colored echos
info() {
  echo -e "${BLUE} => $*${RESET}"
}

IMAGE="ghcr.io/rubrionmc/wayguard"
info "Determining image tag for $IMAGE from LOCAL_DEV_TAGS='$LOCAL_DEV_TAGS'..."
IMAGE_TAG=$(util/get_local_dev_tag.sh "$IMAGE")

if [ -n "$IMAGE_TAG" ]; then
  PULL_POLICY="Never"
  echo "[i] Using LOCAL development image with tag: $IMAGE:$IMAGE_TAG"
else
  IMAGE_TAG="latest"
  PULL_POLICY="Always"
  echo "[i] Using REMOTE registry image with tag: $IMAGE:$IMAGE_TAG"
fi

# temporarily modify the YAML with correct image tag and pull policy
info "Apply wayguard with tag: $IMAGE_TAG and pullPolicy: $PULL_POLICY..."
sed -e "s|image: ghcr.io/rubrionmc/wayguard:.*|image: ghcr.io/rubrionmc/wayguard:$IMAGE_TAG|" \
    -e "s|imagePullPolicy: .*|imagePullPolicy: $PULL_POLICY|" \
    deployments/wayguard.yaml | \
kubectl apply -f - -n "$NAMESPACE"

info "Restarting wayguard to pick up new image..."
kubectl rollout restart deployment wayguard-deployment -n "$NAMESPACE"