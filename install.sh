#!/usr/bin/env bash
set -euo pipefail
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
BOLD="\033[1m"
RESET="\033[0m"
if [[ $EUID -eq 0 ]]; then
echo -e "${RED}Run as normal user, not root.${RESET}"
exit 1
fi
clear
echo -E "$BLUE
  ▄▄▄▄         ▄▄    ▄        ▄▄▄    ▄▄▄ ▄▄▄▄▄ ▄▄▄   ▄▄▄   ▄▄▄▄▄    ▄▄▄▄▄▄▄ 
▄██▀▀██▄       ██    ▀        ████▄  ███  ███  ████▄████ ▄███████▄ █████▀▀▀ 
███  ███ ▄█▀▀▀ ████▄  ▄█▀▀▀   ███▀██▄███  ███   ▀█████▀  ███   ███  ▀████▄  
███▀▀███ ▀███▄ ██ ██  ▀███▄   ███  ▀████  ███  ▄███████▄ ███▄▄▄███    ▀████ 
███  ███ ▄▄▄█▀ ██ ██  ▄▄▄█▀   ███    ███ ▄███▄ ███▀ ▀███  ▀█████▀  ███████▀ 
▄▄▄▄▄                        ▄▄ ▄▄             
 ███               ██        ██ ██             
 ███  ████▄ ▄█▀▀▀ ▀██▀▀ ▀▀█▄ ██ ██ ▄█▀█▄ ████▄ 
 ███  ██ ██ ▀███▄  ██  ▄█▀██ ██ ██ ██▄█▀ ██ ▀▀ 
▄███▄ ██ ██ ▄▄▄█▀  ██  ▀█▄██ ██ ██ ▀█▄▄▄ ██ 
"
REPO_URL="https://github.com/ashvr0/NixOS-Config.git"
TARGET_DIR="/etc/nixos"
clear
echo -e "${BLUE}${BOLD}"
cat << "EOF"
  NixOS Configuration Installer
EOF
echo -e "${RESET}"
read -rp "Enter username: " USERNAME
if [[ ! $USERNAME =~ ^[a-z][a-z0-9_-]*$ ]]; then
echo -e "${RED}Invalid username.${RESET}"
exit 1
fi
read -rp "Enter hostname: " HOSTNAME
if [[ -z "$HOSTNAME" ]]; then
echo -e "${RED}Hostname cannot be empty.${RESET}"
exit 1
fi
read -rp "Machine type (desktop/laptop): " MACHINE_TYPE
if [[ "$MACHINE_TYPE" != "desktop" && "$MACHINE_TYPE" != "laptop" ]]; then
echo -e "${RED}Invalid type. Use desktop or laptop.${RESET}"
exit 1
fi
echo
echo "Summary:"
echo "  Username: $USERNAME"
echo "  Hostname: $HOSTNAME"
echo "  Type: $MACHINE_TYPE"
echo
read -rp "Proceed? [y/N] " CONFIRM
case "$CONFIRM" in
y|Y|yes|YES) ;;
*) echo "Cancelled."; exit 0 ;;
esac
echo
echo -e "${YELLOW}Cloning repo...${RESET}"
if [[ -d "$TARGET_DIR/.git" ]]; then
echo "Updating existing repo..."
sudo git -C "$TARGET_DIR" fetch --all
sudo git -C "$TARGET_DIR" reset --hard origin/main
else
if [[ -d "$TARGET_DIR" ]] && [[ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]]; then
BACKUP_DIR="/etc/nixos-backup-$(date +%Y%m%d_%H%M%S)"
echo "Backing up to $BACKUP_DIR"
sudo mv "$TARGET_DIR" "$BACKUP_DIR"
fi
sudo git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
fi
cd "$TARGET_DIR"

echo
echo -e "${YELLOW}Updating configuration...${RESET}"

sudo sed -i \
  "s|mkHost \"[^\"]*\" \"[^\"]*\" \"$MACHINE_TYPE\";|mkHost \"$HOSTNAME\" \"$USERNAME\" \"$MACHINE_TYPE\";|" \
  flake.nix

if ! grep -q "mkHost \"$HOSTNAME\" \"$USERNAME\" \"$MACHINE_TYPE\";" flake.nix; then
  echo -e "${RED}Failed to update flake.nix. Check that nixosConfigurations.$MACHINE_TYPE exists.${RESET}"
  exit 1
fi

echo
echo -e "${YELLOW}Generating hardware config...${RESET}"
sudo nixos-generate-config --show-hardware-config > /tmp/hw.nix
sudo mv /tmp/hw.nix "hosts/$MACHINE_TYPE/hardware-configuration.nix"
echo
echo -e "${YELLOW}Building system...${RESET}"
sudo nixos-rebuild switch --flake ".#$MACHINE_TYPE"
echo
echo -e "${GREEN}Done.${RESET}"
read -rp "Reboot? [y/N] " REBOOT
case "$REBOOT" in
y|Y|yes|YES) sudo reboot ;;
esac