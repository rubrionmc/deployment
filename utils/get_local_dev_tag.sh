#!/bin/sh
set -e

TARGET_IMAGE="$1"
TAG=""
DEV_TAGS_FILE="$(dirname "$0")/../.run/DEV_TAGS"

if [ -f "$DEV_TAGS_FILE" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [ -z "$line" ] || [ "${line# }" = "" ] || [ "${line#\#}" != "$line" ]; then
            continue
        fi
        case "$line" in
            $TARGET_IMAGE:*)
                TAG="${line#"$TARGET_IMAGE":}"
                break
                ;;
        esac
    done < "$DEV_TAGS_FILE"
fi

echo "$TAG"