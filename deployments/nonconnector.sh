#!/bin/sh
set -e

# helper function for colored echos
info() {
  utils/send_info.sh "$*"
}

: "${NAMESPACE:?NAMESPACE is required}"

IMAGE="ghcr.io/rubrionmc/nonconnector"
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
info "Applying nonconnector with tag: $IMAGE_TAG and pullPolicy: $PULL_POLICY..."
sed -e "s|image: ghcr.io/rubrionmc/nonconnector:.*|image: ghcr.io/rubrionmc/nonconnector:$IMAGE_TAG|" \
    -e "s|imagePullPolicy: .*|imagePullPolicy: $PULL_POLICY|" \
    deployments/nonconnector.yaml | \
kubectl apply -f - -n "$NAMESPACE"