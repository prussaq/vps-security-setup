#!/usr/bin/env bash
set -euo pipefail

### ========== CHECKS ========== ###
###
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 root@server_ip"
  exit 1
fi

### ========== PARAMS ========== ###
###
TARGET="$1"
KEY_PATH="$HOME/.ssh/id_ed25519"
REMOTE_PATH="/root/vps_setup.sh"
LOCAL_SCRIPT="vps_setup.sh"

### ========== SSH ========== ###
###
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

echo "==> Checking SSH key..."

if [[ ! -f "$KEY_PATH" ]]; then
  echo "No ed25519 key found. Generating one..."
  ssh-keygen -t ed25519 -C "vps-bootstrap" -f "$KEY_PATH"
else
  echo "SSH key already exists."
fi

echo "==> Copying SSH key to $TARGET"
ssh-copy-id "$TARGET"

echo "==> Uploading $LOCAL_SCRIPT to $TARGET:$REMOTE_PATH"

if [[ ! -f "$LOCAL_SCRIPT" ]]; then
  echo "ERROR: $LOCAL_SCRIPT not found in current directory."
  exit 1
fi

### ========== VPS SCRIPT ========== ###
###
scp "$LOCAL_SCRIPT" "$TARGET:$REMOTE_PATH"

echo "==> Setting executable permission remotely"
ssh "$TARGET" "chmod +x $REMOTE_PATH"

### ========== DONE ========== ###
###
echo "==> DONE"
echo "SSH into the VPS:"
echo "ssh $TARGET"
echo "Execute VPS setup script:"
echo "bash $REMOTE_PATH <new-username>"
