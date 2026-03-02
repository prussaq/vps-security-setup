#!/usr/bin/env bash
set -euo pipefail

### ========== CHECKS ========== ###
###
if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new_username>"
  exit 1
fi

### ========== PARAMS ========== ###
###
NEW_USER="$1"
SSH_PORT="22"

### ========== SYSTEM UPDATE ========== ###
###
echo "==> Updating system"
apt update && apt upgrade

### ========== NEW USER ========== ###
###
echo "==> Creating user if not exists"

if ! id "$NEW_USER" &>/dev/null; then
  adduser "$NEW_USER"
fi

read -p "Do you want to give $NEW_USER sudo privileges? [y/N]: " give_sudo
give_sudo=${give_sudo,,} # lowercase

if [[ "$give_sudo" == "y" || "$give_sudo" == "yes" ]]; then
    if ! command -v sudo &>/dev/null; then
        echo "Installing sudo..."
        apt install -y sudo
    fi

    usermod -aG sudo "$NEW_USER"
    echo "$NEW_USER added to sudo group"
fi

echo "==> Copying root SSH keys to $NEW_USER"

ROOT_AUTH="/root/.ssh/authorized_keys"
USER_SSH="/home/$NEW_USER/.ssh"

if [[ -f "$ROOT_AUTH" ]]; then
  mkdir -p "$USER_SSH"
  chmod 700 "$USER_SSH"
  cp "$ROOT_AUTH" "$USER_SSH/authorized_keys"
  chmod 600 "$USER_SSH/authorized_keys"
  chown -R "$NEW_USER:$NEW_USER" "$USER_SSH"
else
  echo "WARNING: root has no authorized_keys!"
fi

### ========== SSH ========== ###
###
echo "==> Hardening SSH (port $SSH_PORT)"

SSHD="/etc/ssh/sshd_config"
cp "$SSHD" "$SSHD.bak"

if grep -q "^#\?Port" "$SSHD"; then
  sed -i "s/^#\?Port .*/Port ${SSH_PORT}/" "$SSHD"
else
  echo "Port ${SSH_PORT}" >> "$SSHD"
fi

if grep -q "^#\?PermitRootLogin" "$SSHD"; then
  sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" "$SSHD"
else
  echo "PermitRootLogin no" >> "$SSHD"
fi

if grep -q "^#\?PasswordAuthentication" "$SSHD"; then
  sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" "$SSHD"
else
  echo "PasswordAuthentication no" >> "$SSHD"
fi

if grep -q "^#\?PubkeyAuthentication" "$SSHD"; then
  sed -i "s/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/" "$SSHD"
else
  echo "PubkeyAuthentication yes" >> "$SSHD"
fi

if grep -q "^AllowUsers" "$SSHD"; then
  sed -i "s/^AllowUsers.*/AllowUsers ${NEW_USER}/" "$SSHD"
else
  echo "AllowUsers ${NEW_USER}" >> "$SSHD"
fi

systemctl restart ssh || systemctl restart sshd

### ========== UFW ========== ###
###
echo "==> Configuring UFW"

apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

### ========== Fail2Ban ========== ###
###
echo "==> Installing Fail2Ban"

apt install -y fail2ban

cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ${SSH_PORT}
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 300
bantime = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

### ========== DONE ========== ###
###
echo "==> DONE"
echo "Test:"
echo "ssh ${NEW_USER}@SERVER_IP"
