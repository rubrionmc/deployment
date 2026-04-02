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

# check for usage
if [ "$1" = "" ]; then
  echo "[x] Wrong usage: deployment <command> [args...]"
  exit 1
fi


# setting constants
RUNTIME_DIR=".runtime"
GO_DIR="${RUNTIME_DIR}/go"
GO_BIN="${GO_DIR}/bin/go"
GO_FILE="./src"

GO_MOD_FILE="go.mod"
GO_MODULE="module deployment"
GO_VERSION="1.25.1"

DEPLOYMENT_ENV="RUBRION_DEPLOYMENT_DIR"

install_deployment() {

  # start timer for install_deployment
  INSTALL_PROCESS_START_TIME=$(date +%s)
  echo "[+] Installing Deployment..."

  # check for fitting go.mod
  if [ ! -f "$GO_MOD_FILE" ] || ! read -r first_line < "$GO_MOD_FILE" || [ "$first_line" != "$GO_MODULE" ]; then
      echo "[x] Install command can only be executed in the deployment folder"
      exit 1
  fi

  # set deployment dir
  SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  WORKSPACE_DIR="$(dirname "$SCRIPT_PATH")"

  info "Setting ${DEPLOYMENT_ENV}=$WORKSPACE_DIR"

  # export for bash
  sed -i "/export ${DEPLOYMENT_ENV}=/d" "$HOME/.bashrc" 2>/dev/null || true
  echo "export ${DEPLOYMENT_ENV}=\"$WORKSPACE_DIR\"" >> "$HOME/.bashrc"

  # export for zsh
  sed -i "/export ${DEPLOYMENT_ENV}=/d" "$HOME/.zshrc" 2>/dev/null || true
  echo "export ${DEPLOYMENT_ENV}=\"$WORKSPACE_DIR\"" >> "$HOME/.zshrc"

  # export for fish
  mkdir -p "$HOME/.config/fish"
  sed -i "/set -x ${DEPLOYMENT_ENV}/d" "$HOME/.config/fish/config.fish" 2>/dev/null || true
  echo "set -x ${DEPLOYMENT_ENV} \"$WORKSPACE_DIR\"" >> "$HOME/.config/fish/config.fish"

  # export for current shell
  export ${DEPLOYMENT_ENV}="$WORKSPACE_DIR"

  # check for sh export
  if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    info "${RESET_CONSOLE_COLOR_CHAR}[i] Please restart your shell or run: source ~/.bashrc"
  fi

  # check kubectl
  info "Checking for kubectl"
  command -v kubectl >/dev/null || { echo "[x] kubectl not installed"; exit 1; }
  info "Found kubectl"

  # calculate runtime of install process after command finishes
  INSTALL_PROCESS_ENC_TIME=$(date +%s)
  INSTALL_PROCESS_RUNTIME=$((INSTALL_PROCESS_ENC_TIME - INSTALL_PROCESS_START_TIME))
  echo "[*] Done: installed Deployment in ${INSTALL_PROCESS_RUNTIME}s"
}

download_go() {
  # start timer for download_go
  GO_DOWNLOAD_PROCESS_START_TIME=$(date +%s)
  echo "[+] Downloading go..."

  # detect platform
  case "$(uname | tr '[:upper:]' '[:lower:]')" in
      linux*)  OS=linux ;;
      darwin*) OS=darwin ;;
      *) echo "[x] Unsupported OS"; exit 1 ;;
    esac

    case "$(uname -m)" in
      x86_64|amd64)   ARCH=amd64 ;;
      arm64|aarch64)  ARCH=arm64 ;;
      *) echo "[x] Unsupported architecture"; exit 1 ;;
    esac

  mkdir -p "$RUNTIME_DIR"

  TAR_FILE="${RUNTIME_DIR}/go.tar.gz"
  GO_URL="https://go.dev/dl/go${GO_VERSION}.${OS}-${ARCH}.tar.gz"

  info "Downloading Go ${GO_VERSION} for ${OS}/${ARCH}"

  # download via curl or wget
  if command -v curl >/dev/null 2>&1; then
    curl -L "$GO_URL" -o "$TAR_FILE"
  elif command -v wget >/dev/null 2>&1; then
    wget "$GO_URL" -O "$TAR_FILE"
  else
    echo "curl or wget required"
    exit 1
  fi

  info "Extracting Go runtime"

  # extracting go
  rm -rf "$GO_DIR"
  tar -xzf "$TAR_FILE" -C "$RUNTIME_DIR"

  rm "$TAR_FILE"

  # calculate runtime of download_go process after command finishes
  GO_DOWNLOAD_PROCESS_ENC_TIME=$(date +%s)
  GO_DOWNLOAD_PROCESS_RUNTIME=$((GO_DOWNLOAD_PROCESS_ENC_TIME - GO_DOWNLOAD_PROCESS_START_TIME))
  echo "[*] Done: installed go in ${GO_DOWNLOAD_PROCESS_RUNTIME}s"
}

run_go() {
  local GO_EXEC="$1"

  info "Running Go file using: $GO_EXEC"

  "$GO_EXEC" run "$GO_FILE" "$@"
}

# check for install command
if [ "$1" = "install" ]; then
  install_deployment
  exit 0
fi

# check if installed
if [ -z "${!DEPLOYMENT_ENV}" ]; then
    echo "[x] Deployment cound not be found: Environment variable $DEPLOYMENT_ENV is not set."
    exit 1
fi

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