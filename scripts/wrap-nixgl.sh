#!/usr/bin/env bash
set -euo pipefail
APPS=(ghostty obs-studio obsidian signal-desktop zoom-us jellyfin-media-player orca-slicer sunshine)
BIN="$HOME/.local/bin"
mkdir -p "$BIN"

for app in "${APPS[@]}"; do
  if command -v "$app" >/dev/null 2>&1; then
    cat >"$BIN/$app" <<EOF
#!/usr/bin/env bash
exec nixGLNvidia $(command -v $app) "\$@"
EOF
    chmod +x "$BIN/$app"
    echo "Wrapped $app -> $BIN/$app"
  fi
done

