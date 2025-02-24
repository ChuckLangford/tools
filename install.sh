#!/bin/bash

# Paths
INSTALL_DIR="/usr/local/bin"
DEVTOOLS_DIR="$HOME/.local/share/devtools"
COMMANDS_JSON_SRC="./commands.json"
SHELL_SCRIPTS_DIR="./shell-scripts"

# Dependencies
DEPENDENCIES=("fzf" "jq")

# OS detection functions
is_macos() {
  [[ "$(uname)" == "Darwin" ]]
}

is_linux() {
  [[ "$(uname)" == "Linux" ]]
}

# Ensure the script is run with sudo
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo to modify system directories like $INSTALL_DIR."
    echo "Please rerun with: sudo $0"
    exit 1
  fi
}

# Check if Homebrew is installed (for macOS)
check_brew() {
  if ! command -v brew &>/dev/null; then
    echo "Homebrew is not installed. Please install Homebrew and re-run this script."
    exit 1
  fi
}

check_gcloud() {
  if ! command -v gcloud &>/dev/null; then
    echo "Gcloud is not installed. Please install it via https://cloud.google.com/sdk/docs/install-sdk and re-run this script."
    exit 1
  fi
}

# For Linux, detect the package manager and set the appropriate commands
set_pkg_manager() {
  if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt-get"
    INSTALL_CMD="apt-get install -y"
    UPDATE_CMD="apt-get update"
  elif command -v yum &>/dev/null; then
    PKG_MANAGER="yum"
    INSTALL_CMD="yum install -y"
    UPDATE_CMD=""
  elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="dnf install -y"
    UPDATE_CMD=""
  else
    echo "No supported package manager found. Please install dependencies manually."
    exit 1
  fi
}

# Install dependencies
install_dependencies() {
  if is_macos; then
    for dep in "${DEPENDENCIES[@]}"; do
      if ! command -v "$dep" &>/dev/null; then
        echo "$dep is not installed. Installing with Homebrew..."
        brew install "$dep"
      else
        echo "$dep is already installed."
      fi
    done
  elif is_linux; then
    set_pkg_manager
    if [[ -n "$UPDATE_CMD" ]]; then
      echo "Updating package list..."
      sudo $UPDATE_CMD
    fi
    for dep in "${DEPENDENCIES[@]}"; do
      if ! command -v "$dep" &>/dev/null; then
        echo "$dep is not installed. Installing with $PKG_MANAGER..."
        sudo $INSTALL_CMD "$dep"
      else
        echo "$dep is already installed."
      fi
    done
  else
    echo "Unsupported operating system."
    exit 1
  fi
}

# Prompt user before overwriting a file, only if the file is different
confirm_overwrite() {
  local src_file="$1"
  local dest_file="$2"

  if [[ -e "$dest_file" ]]; then
    if cmp -s "$src_file" "$dest_file"; then
      # Files are identical, no need to ask
      return 0
    else
      # Files are different, ask the user
      read -p "File $dest_file differs from source. Overwrite? [y/N]: " response
      case "$response" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
      esac
    fi
  fi
  return 0
}

# Copy files to their destinations
copy_files() {
  # Ensure the devtools directory exists
  echo "Ensuring $DEVTOOLS_DIR exists..."
  mkdir -p "$DEVTOOLS_DIR"

  # Copy commands.json
  echo "Copying commands.json to $DEVTOOLS_DIR..."
  confirm_overwrite "$COMMANDS_JSON_SRC" "$DEVTOOLS_DIR/commands.json" && cp "$COMMANDS_JSON_SRC" "$DEVTOOLS_DIR/"

  # Copy shell scripts
  echo "Copying shell scripts to $INSTALL_DIR..."
  for script in "$SHELL_SCRIPTS_DIR"/*; do
    script_name=$(basename "$script")
    confirm_overwrite "$script" "$INSTALL_DIR/$script_name" && cp "$script" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$script_name"
  done

  # Copy dt script
  echo "Copying dt to $INSTALL_DIR..."
  confirm_overwrite "./dt" "$INSTALL_DIR/dt" && cp ./dt "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/dt"
}

main() {
  echo "Starting installation..."
  check_root
  if is_macos; then
    check_brew
  fi
  check_gcloud
  install_dependencies
  copy_files
  echo "Installation complete!"
}

# Execute the script
main
