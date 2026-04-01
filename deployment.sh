#!/bin/bash
set -e

# start timer for deployment
ROOT_PROCESS_START_TIME=$(date +%s)

# shellcheck source=$HOME/.bashrc
source ~/.bashrc

BLUE_CONSOLE_COLOR_CHAR='\033[34m'
RESET_CONSOLE_COLOR_CHAR='\033[0m'

# helper function for colored echos
info() {
  # shellcheck disable=SC3037
  echo -e "${BLUE_CONSOLE_COLOR_CHAR} => $*${RESET_CONSOLE_COLOR_CHAR}"
}

echo "[+] Executing command: $*"


RUNTIME_DIR=".runtime"
GO_DIR="${RUNTIME_DIR}/go"
GO_BIN="${GO_DIR}/bin/go"
GO_FILE="./src"

GO_VERSION="1.22.5"

detect_platform() {
  OS=$(uname | tr '[:upper:]' '[:lower:]')

  case "$OS" in
    linux*) OS="linux" ;;
    darwin*) OS="darwin" ;;
    *)
      echo "[x] Unsupported OS: $OS"
      exit 1
      ;;
  esac

  ARCH=$(uname -m)

  case "$ARCH" in
    x86_64|amd64)
      ARCH="amd64"
      ;;
    arm64|aarch64)
      ARCH="arm64"
      ;;
    *)
      echo "[x] Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac
}

download_go() {
  detect_platform

  mkdir -p "$RUNTIME_DIR"

  TAR_FILE="${RUNTIME_DIR}/go.tar.gz"
  GO_URL="https://go.dev/dl/go${GO_VERSION}.${OS}-${ARCH}.tar.gz"

  info "Downloading Go ${GO_VERSION} for ${OS}/${ARCH}"

  if command -v curl >/dev/null 2>&1; then
    curl -L "$GO_URL" -o "$TAR_FILE"
  elif command -v wget >/dev/null 2>&1; then
    wget "$GO_URL" -O "$TAR_FILE"
  else
    echo "curl or wget required"
    exit 1
  fi

  info "Extracting Go runtime"

  rm -rf "$GO_DIR"
  tar -xzf "$TAR_FILE" -C "$RUNTIME_DIR"

  rm "$TAR_FILE"
}

run_go() {
  local GO_EXEC="$1"

  info "Running Go file using: $GO_EXEC"

  "$GO_EXEC" run "$GO_FILE" "$@"
}

if command -v go >/dev/null 2>&1; then
  # check system go version
  info "Found system Go"
  run_go go "$@"
elif [ -x "$GO_BIN" ]; then
  # check local go version
  info "Found local runtime Go"
  run_go "$GO_BIN" "$@"
else
  # install and run local go runtime
  info "Go not found Installing runtime"
  download_go
  run_go "$GO_BIN" "$@"
fi

# calculate runtime of root process after command finishes
ROOT_PROCESS_ENC_TIME=$(date +%s)
ROOT_PROCESS_RUNTIME=$((ROOT_PROCESS_ENC_TIME - ROOT_PROCESS_START_TIME))

# finish root process with feedback
echo "[*] Done: executing command in ${ROOT_PROCESS_RUNTIME}s"