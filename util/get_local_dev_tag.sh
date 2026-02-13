#!/bin/sh
set -e

TARGET_IMAGE="$1"
TAG=""

if [ -n "$LOCAL_DEV_TAGS" ]; then
  OLD_IFS="$IFS"
  IFS=','
  for t in $LOCAL_DEV_TAGS; do
    IFS="$OLD_IFS"
    case "$t" in
      $TARGET_IMAGE:*)
        TAG="${t#"$TARGET_IMAGE":}"
        break
        ;;
    esac
  done
fi

echo "$TAG"