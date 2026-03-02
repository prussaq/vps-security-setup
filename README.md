# Minimal security setup for fresh VPS

Tested systems:
- Ubuntu 24.04 LTS
- Debian 13

This project provides a minimal, predictable baseline hardening for a fresh VPS:
- Key-only SSH authentication
- Root login disabled
- UFW firewall baseline
- Fail2Ban for SSH protection
- Backs up original /etc/ssh/sshd_config

---

## Setup Flow

### 1. Local part

Run:
    cd <path-to-files>
    bash run.sh root@SERVER_IP

This will:
- Generate an ed25519 SSH key if missing
- Copy the key to root
- Upload vps_setup.sh to /root/

---

### 2. Remote part

    ssh root@SERVER_IP
    bash /root/vps_setup.sh <new_username>

---

## What the script does

User:
- Creates the new user (if not exists)
- Adds user to sudo group (prompts if needed)
- Copies root authorized_keys to the new user
- Fixes ownership and permissions

SSH:
- Port 22 (configurable in script)
- PermitRootLogin no
- PasswordAuthentication no
- PubkeyAuthentication yes
- AllowUsers <new_user>
- Backs up original sshd_config to: /etc/ssh/sshd_config.bak

Firewall (UFW):
- Default deny incoming
- Default allow outgoing
- Allows:
  - 22/tcp
  - 80/tcp
  - 443/tcp

Fail2Ban:
- Enables sshd jail
- maxretry = 5
- findtime = 300
- bantime = 3600

---

## After setup

Test login:

    ssh newuser@SERVER_IP

If successful:
- Root login is disabled
- Password authentication is disabled
- Key-based authentication only

---

This is a minimal security baseline, not a complete security policy.
Adjust SSH, UFW, and Fail2Ban settings according to your workload.
