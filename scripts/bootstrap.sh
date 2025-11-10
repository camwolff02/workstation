#!/usr/bin/env bash
set -euo pipefail

# --- Detect user/home/host
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(eval echo ~"$USER_NAME")"
HOST_NAME="$(hostnamectl --static 2>/dev/null || hostname -s)"

echo "User: $USER_NAME | Home: $USER_HOME | Host: $HOST_NAME"

# --- Essentials
sudo apt update
sudo apt install -y git curl stow xz-utils ca-certificates gnupg lsb-release

# --- Docker (official repo)
# https://docs.docker.com/engine/install/ubuntu/
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release; echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER_NAME"

# --- NVIDIA Container Toolkit (after driver is installed)
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL "https://nvidia.github.io/libnvidia-container/gpgkey" | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL "https://nvidia.github.io/libnvidia-container/stable/deb/$distribution/libnvidia-container.list" | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# --- Tailscale (apt; easier system service)
# https://tailscale.com/kb/1031/install-linux
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(. /etc/os-release; echo $VERSION_CODENAME).noarmor.gpg \
  | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(. /etc/os-release; echo $VERSION_CODENAME).tailscale-keyring.list \
  | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
sudo apt update
sudo apt install -y tailscale
sudo systemctl enable --now tailscaled

# --- Nix (multi-user) + flakes
# Official installer; enables nix-command and flakes in nix.conf via dotfiles
sh <(curl -L https://nixos.org/nix/install) --daemon

# Shell session may not know Nix yet:
source /etc/profile.d/nix-daemon.sh || true

# --- Install pinned packages from the flake
# This installs to the user's default profile (~/.nix-profile)
sudo -u "$USER_NAME" nix --extra-experimental-features "nix-command flakes" \
  profile install "$PWD/nix#user-env"

# --- Install nixGL + wrap selected GUI apps for NVIDIA
sudo -u "$USER_NAME" nix-env -iA nixpkgs.nixGLNvidia
sudo -u "$USER_NAME" bash "$PWD/scripts/wrap-nixgl.sh"

# --- Stow dotfiles (run as the real user)
pushd "$PWD/dotfiles" >/dev/null
sudo -u "$USER_NAME" stow -v -t "$USER_HOME" *
popd >/dev/null

# --- Set fish as default shell (user)
if command -v fish >/dev/null; then
  if ! grep -q "$(command -v fish)" /etc/shells; then
    echo "$(command -v fish)" | sudo tee -a /etc/shells
  fi
  sudo chsh -s "$(command -v fish)" "$USER_NAME"
fi

# --- System services config (tailscale up; xorg virtual; sunshine)
sudo install -Dm0644 services/system/tailscale-up.service /etc/systemd/system/tailscale-up.service
sudo install -Dm0644 services/system/xorg-virtual-display.service /etc/systemd/system/xorg-virtual-display.service
sudo install -Dm0644 services/system/sunshine.service /etc/systemd/system/sunshine.service

# Create /etc/default files for secrets (not in git)
sudo install -d -m 0750 /etc/default
sudo bash -c 'cat >/etc/default/tailscale <<EOF
# Put your auth key here (or leave unset to login manually once)
TS_AUTHKEY=
EOF'
sudo chmod 0640 /etc/default/tailscale

# Apply service toggles from services/config.sh
sudo bash -c "source $PWD/services/config.sh && $PWD/scripts/svc apply"

echo "Bootstrap complete. Reboot recommended."
echo "If you set TS_AUTHKEY in /etc/default/tailscale, your node will auto-join on boot."

# --- Flatpak (for Zen Browser)
if ! command -v flatpak >/dev/null 2>&1; then
  sudo apt install -y flatpak xdg-desktop-portal xdg-desktop-portal-gtk
fi
# Add Flathub if missing
if ! flatpak remotes | grep -q flathub; then
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi
# Install Zen Browser (official Flatpak)
sudo -u "$USER_NAME" flatpak install -y flathub app.zen_browser.zen

# Set Zen as default browser (both scheme + mime)
sudo -u "$USER_NAME" xdg-settings set default-web-browser app.zen_browser.zen.desktop || true
sudo -u "$USER_NAME" xdg-mime default app.zen_browser.zen.desktop x-scheme-handler/http
sudo -u "$USER_NAME" xdg-mime default app.zen_browser.zen.desktop x-scheme-handler/https
sudo -u "$USER_NAME" xdg-mime default app.zen_browser.zen.desktop text/html

# --- Proton Mail Desktop (official Snap; auto-updating)
if command -v snap >/dev/null 2>&1; then
  sudo snap install proton-mail
else
  echo "snapd not present; installing..."
  sudo apt install -y snapd
  sudo snap install proton-mail
fi

# Find Proton Mail desktop file (snap exports here)
PM_DESKTOP="$(ls /var/lib/snapd/desktop/applications/proton-mail_*.desktop 2>/dev/null | head -n1)"
# Fallback search just in case
if [ -z "$PM_DESKTOP" ]; then
  PM_DESKTOP="$(basename "$(grep -ril 'Proton Mail' /var/lib/snapd/desktop/applications/ /usr/share/applications/ 2>/dev/null | head -n1)")"
else
  PM_DESKTOP="$(basename "$PM_DESKTOP")"
fi

# Set Proton Mail as default mail + calendar handlers
if [ -n "$PM_DESKTOP" ]; then
  sudo -u "$USER_NAME" xdg-mime default "$PM_DESKTOP" x-scheme-handler/mailto
  sudo -u "$USER_NAME" xdg-mime default "$PM_DESKTOP" text/calendar
  sudo -u "$USER_NAME" xdg-mime default "$PM_DESKTOP" x-scheme-handler/webcal
  sudo -u "$USER_NAME" xdg-mime default "$PM_DESKTOP" x-scheme-handler/webcals
else
  echo "WARN: Could not locate Proton Mail .desktop file to set defaults."
fi

# --- Personal source directory + repo sync --------------------------------------
# Where all personal repos live
SRC_DIR="$USER_HOME/src"
sudo -u "$USER_NAME" mkdir -p "$SRC_DIR"

# Optional repo list (one URL per line, comments allowed with #)
REPOS_FILE="$PWD/scripts/repos.txt"
if [[ -f "$REPOS_FILE" ]]; then
  echo "Syncing repos from $REPOS_FILE into $SRC_DIR ..."
  # Read non-empty, non-comment lines
  while IFS= read -r repo; do
    [[ -z "$repo" || "$repo" =~ ^[[:space:]]*# ]] && continue
    name="$(basename "$repo" .git)"
    dest="$SRC_DIR/$name"
    if [[ -d "$dest/.git" ]]; then
      echo "  -> Updating $name"
      sudo -u "$USER_NAME" git -C "$dest" fetch --all --prune || true
      sudo -u "$USER_NAME" git -C "$dest" pull --ff-only || true
    else
      echo "  -> Cloning $name"
      sudo -u "$USER_NAME" git -C "$SRC_DIR" clone "$repo" || true
    fi
  done < "$REPOS_FILE"
else
  echo "No repo list found at $REPOS_FILE (skipping clone step)."
fi

# --- Global Git config (idempotent) ---------------------------------------------
sudo -u "$USER_NAME" git config --global init.defaultBranch main
sudo -u "$USER_NAME" git config --global user.name "cam"
sudo -u "$USER_NAME" git config --global user.email "36940948+camwolff02@users.noreply.github.com"

echo "Git configured:"
echo "  init.defaultBranch = $(sudo -u "$USER_NAME" git config --global --get init.defaultBranch || echo unset)"
echo "  user.name          = $(sudo -u "$USER_NAME" git config --global --get user.name || echo unset)"
echo "  user.email         = $(sudo -u "$USER_NAME" git config --global --get user.email || echo unset)"

# --- Bluetooth LDAC (PipeWire/WirePlumber) --------------------------------------
# Packages: PipeWire BT plugin + LDAC codec libs
sudo apt update
sudo apt install -y \
  bluez wireplumber pipewire-audio-client-libraries libspa-0.2-bluetooth \
  libldacbt-abr2 libldacbt-enc2

# WirePlumber LDAC config (HQ by default; allow codecs incl. LDAC)
sudo install -d -m 0755 /etc/wireplumber/bluetooth.lua.d
sudo tee /etc/wireplumber/bluetooth.lua.d/51-ldac.lua >/dev/null <<'EOF'
# WirePlumber Bluetooth configuration overrides
# Docs: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
monitor.bluez.properties = {
  bluez5.codecs = [ ldac sbc sbc_xq aac ]     # enable LDAC + useful fallbacks
  bluez5.default.profile = "a2dp_sink"        # prefer A2DP playback
  bluez5.enable-msbc = true
  bluez5.enable-sbc-xq = true
  bluez5.default.rate = 96000                 # prefer 96 kHz (drop to 48000 if unstable)
}

monitor.bluez.rules = [
  {
    matches = [ { device.name = "~bluez_card.*" } ]  # all BT audio devices
    actions = {
      update-props = {
        bluez5.a2dp.ldac.quality = "hq"      # LDAC quality: auto|hq|sq|mq
      }
    }
  }
]
EOF

# Restart user audio stack so settings take effect (no-op if not logged in yet)
sudo -u "$USER_NAME" systemctl --user daemon-reload || true
sudo -u "$USER_NAME" systemctl --user restart wireplumber.service pipewire.service pipewire-pulse.service || true

