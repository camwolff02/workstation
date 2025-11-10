# Path and aliases
set -Ux PATH $HOME/.local/bin $HOME/.nix-profile/bin /usr/local/bin /usr/bin $PATH

# Make "vim" open neovim
alias vim="nvim"

# Docker convenience
alias d="docker"
alias dc="docker compose"

# Python via uv
alias venv="uv venv"

# Ensure global Git identity exists (don’t overwrite if already set)
if not git config --global --get user.name >/dev/null 2>/dev/null
    git config --global init.defaultBranch main
    git config --global user.name "cam"
    git config --global user.email "36940948+camwolff02@users.noreply.github.com"
end

### HOTKEYS ###
# === Paths & workspace detection ==================================================
# Ensure local bin comes first (nixGL wrappers live here)
if not contains $HOME/.local/bin $PATH
    set -gx PATH $HOME/.local/bin $PATH
end

# Your workstation repo root (used by svc toggler & dotfile ops)
if not set -q WS_DIR
    if test -d $HOME/workstation
        set -gx WS_DIR $HOME/workstation
    else
        set -gx WS_DIR $HOME   # fallback
    end
end

# === Quality of life ==============================================================
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lt='tree -L 2'
alias vim='nvim'
alias smi='nvidia-smi'

function mkcd --description 'mkdir -p and cd'
    test (count $argv) -lt 1; and echo "Usage: mkcd <dir>"; and return 1
    mkdir -p "$argv[1]"; and cd "$argv[1]"
end

# Jump to repo quickly
function ws --description 'cd to workstation repo'
    cd "$WS_DIR"
end

# === Git =========================================================================
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend --no-edit'
alias gpl='git pull --rebase --autostash'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gcl='git clone'
alias gl='git log --oneline --graph --decorate --all'

function gsw --description 'git switch <branch>'
    test (count $argv) -lt 1; and echo "Usage: gsw <branch>"; and return 1
    git switch "$argv[1]"
end

function gcb --description 'create and switch new branch'
    test (count $argv) -lt 1; and echo "Usage: gcb <new-branch>"; and return 1
    git switch -c "$argv[1]"
end

# === Nix (flakes) ================================================================
# Search, upgrade, and install pinned env
function nup --description 'Update flake lock in ./nix then upgrade profile'
    set save (pwd)
    if test -d "$WS_DIR/nix"
        cd "$WS_DIR/nix"
        nix --extra-experimental-features "nix-command flakes" flake update
        cd $save
        nix profile upgrade '.*'
    else
        echo "No $WS_DIR/nix; skipping."
    end
end
alias npl='nix profile list'
alias npi='nix profile install'     # e.g., npi nixpkgs#ripgrep
alias nprm='nix profile remove'     # e.g., nprm 0

# === Dotfiles (Stow) =============================================================
function ds --description 'stow package(s) to $HOME'
    test (count $argv) -lt 1; and echo "Usage: ds <pkg> [...]"; and return 1
    command stow -v -t $HOME $argv
end

function dus --description 'unstow package(s) from $HOME'
    test (count $argv) -lt 1; and echo "Usage: dus <pkg> [...]"; and return 1
    command stow -v -D -t $HOME $argv
end

# === Service toggler (systemd) ===================================================
# Uses our repo script: $WS_DIR/scripts/svc {apply|enable|disable|list}
function svcl --description 'list toggles'
    sudo "$WS_DIR/scripts/svc" list
end

function svcon --description 'enable a service (SUNSHINE|XORG_VIRTUAL|TAILSCALE)'
    test (count $argv) -lt 1; and echo "Usage: svcon <NAME>"; and return 1
    sudo "$WS_DIR/scripts/svc" enable "$argv[1]"
end

function svcoff --description 'disable a service'
    test (count $argv) -lt 1; and echo "Usage: svcoff <NAME>"; and return 1
    sudo "$WS_DIR/scripts/svc" disable "$argv[1]"
end

function svca --description 'apply current toggle config'
    sudo "$WS_DIR/scripts/svc" apply
end

# Quick helpers for common units
alias xv-on='sudo systemctl enable --now xorg-virtual-display.service'
alias xv-off='sudo systemctl disable --now xorg-virtual-display.service'
alias sun-on='sudo systemctl enable --now sunshine.service'
alias sun-off='sudo systemctl disable --now sunshine.service'
function jfu --description 'tail -f logs for a unit'
    test (count $argv) -lt 1; and echo "Usage: jfu <unit>"; and return 1
    sudo journalctl -u "$argv[1]" -f -n 100
end

# === Docker / NVIDIA Toolkit =====================================================
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f --tail 100'
alias dimg='docker images'
alias drm='docker rm -f'
alias drmi='docker rmi'
alias dgpu='docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi'

# === Tailscale ===================================================================
alias ts='tailscale'
alias tss='tailscale status'
alias tsl='sudo tailscale logout'
alias tsip='tailscale ip'
function tsu --description 'tailscale up (uses /etc/default/tailscale if set)'
    sudo tailscale up --ssh --accept-routes
end
function tssh --description 'tailscale ssh user@host'
    test (count $argv) -lt 1; and echo "Usage: tssh <user@host>"; and return 1
    tailscale ssh "$argv[1]"
end

# === Python / uv / Isaac Sim =====================================================
alias venv='uv venv'         # create venv: venv --python 3.11 .venv
alias uvx='uv run'           # run with resolver: uvx <cmd>

function activate --description 'activate venv in ./env or ./.venv'
    if test -f ./env/bin/activate.fish
        source ./env/bin/activate.fish
    else if test -f ./.venv/bin/activate.fish
        source ./.venv/bin/activate.fish
    else
        echo "No ./env or ./.venv found. Try: uv venv --python 3.11 .venv"
    end
end

function isaac-venv --description 'create & activate Isaac Lab venv'
    uv venv --python 3.11 env_isaaclab
    source env_isaaclab/bin/activate.fish
end

function isaac-install --description 'install Isaac Sim + Torch (CUDA 12.8) into env_isaaclab'
    if not test -f env_isaaclab/bin/activate.fish
        echo "Run isaac-venv first."; return 1
    end
    source env_isaaclab/bin/activate.fish
    pip install "isaacsim[all,extscache]==5.1.0" --extra-index-url https://pypi.nvidia.com
    pip install -U torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cu128
end

function isaac-run --description 'activate env_isaaclab and run isaacsim'
    if not test -f env_isaaclab/bin/activate.fish
        echo "No env_isaaclab. Run isaac-venv && isaac-install."; return 1
    end
    source env_isaaclab/bin/activate.fish
    isaacsim $argv
end

# === Media / Network utils =======================================================
alias speed='speedtest'
alias yt='yt-dlp'
function ytmp3 --description 'yt-dlp -> mp3'
    test (count $argv) -lt 1; and echo "Usage: ytmp3 <url>"; and return 1
    yt-dlp -x --audio-format mp3 "$argv[1]"
end

function ffcut --description 'ffmpeg copy-cut: ffcut <start> <end> <in> [out]'
    if test (count $argv) -lt 3
        echo "Usage: ffcut <start> <end> <input> [output.mp4]"
        return 1
    end
    set start $argv[1]; set end $argv[2]; set in $argv[3]
    set out (basename "$in" .mp4)"-cut.mp4"
    if test (count $argv) -ge 4
        set out $argv[4]
    end
    ffmpeg -ss $start -to $end -i "$in" -c copy "$out"
end

# === App shorthands (use nixGL-wrapped binaries in ~/.local/bin) =================
# Our bootstrap created wrappers named: ghostty, obs-studio, obsidian, signal-desktop,
# zoom-us, jellyfin-media-player, orca-slicer, sunshine
alias obs='obs-studio'
alias jfp='jellyfin-media-player'
# === Help / cheat sheet ==========================================================
function wshelp --description 'Print workstation command cheat sheet'
    set -l C (set_color cyan)
    set -l M (set_color magenta)
    set -l Y (set_color yellow)
    set -l R (set_color normal)

    echo
    echo "$C== Workstation commands (aliases & functions) ==$R"

    echo "$M General$R"
    printf "  %-22s %s\n" "ll / la / l / lt" "ls variants & tree"
    printf "  %-22s %s\n" "vim" "Open Neovim"
    printf "  %-22s %s\n" "smi" "nvidia-smi"
    printf "  %-22s %s\n" "mkcd <dir>" "mkdir -p && cd"
    printf "  %-22s %s\n" "ws" "cd ~/workstation"

    echo
    echo "$M Git$R"
    printf "  %-22s %s\n" "gs, ga, gc, gcm" "status / add / commit / commit -m"
    printf "  %-22s %s\n" "gca" "amend --no-edit"
    printf "  %-22s %s\n" "gpl, gp, gpf" "pull --rebase / push / force-with-lease"
    printf "  %-22s %s\n" "gcl <url>" "git clone"
    printf "  %-22s %s\n" "gl" "pretty log"
    printf "  %-22s %s\n" "gsw <branch>" "git switch"
    printf "  %-22s %s\n" "gcb <new-branch>" "create & switch"

    echo
    echo "$M Nix (flakes)$R"
    printf "  %-22s %s\n" "nup" "update flake + upgrade profile"
    printf "  %-22s %s\n" "npl" "nix profile list"
    printf "  %-22s %s\n" "npi …" "nix profile install"
    printf "  %-22s %s\n" "nprm <idx>" "nix profile remove"

    echo
    echo "$M Dotfiles (Stow)$R"
    printf "  %-22s %s\n" "ds <pkg …>" "stow to \$HOME"
    printf "  %-22s %s\n" "dus <pkg …>" "unstow from \$HOME"

    echo
    echo "$M Services (systemd)$R"
    printf "  %-22s %s\n" "svcl" "list current toggles"
    printf "  %-22s %s\n" "svcon <NAME>" "enable (SUNSHINE|XORG_VIRTUAL|TAILSCALE)"
    printf "  %-22s %s\n" "svcoff <NAME>" "disable"
    printf "  %-22s %s\n" "svca" "apply toggles"
    printf "  %-22s %s\n" "xv-on / xv-off" "start/stop virtual Xorg (:0)"
    printf "  %-22s %s\n" "sun-on / sun-off" "start/stop Sunshine"
    printf "  %-22s %s\n" "jfu <unit>" "follow logs: journalctl -u <unit> -f"

    echo
    echo "$M Docker & NVIDIA$R"
    printf "  %-22s %s\n" "d / dc" "docker / docker compose"
    printf "  %-22s %s\n" "dps" "ps (table)"
    printf "  %-22s %s\n" "dcu / dcd / dcl" "compose up/down/logs"
    printf "  %-22s %s\n" "dgpu" "CUDA test container (nvidia-smi)"

    echo
    echo "$M Tailscale$R"
    printf "  %-22s %s\n" "ts / tss" "tailscale / status"
    printf "  %-22s %s\n" "tsip" "show IP"
    printf "  %-22s %s\n" "tsu" "tailscale up (ssh + routes)"
    printf "  %-22s %s\n" "tssh user@host" "tailscale ssh"

    echo
    echo "$M Python / uv / Isaac$R"
    printf "  %-22s %s\n" "venv" "uv venv (create venv)"
    printf "  %-22s %s\n" "activate" "activate ./env or ./.venv"
    printf "  %-22s %s\n" "isaac-venv" "create+activate env_isaaclab"
    printf "  %-22s %s\n" "isaac-install" "install Isaac Sim + Torch (CUDA 12.8)"
    printf "  %-22s %s\n" "isaac-run …" "run isaacsim in env"

    echo
    echo "$M Media / Network$R"
    printf "  %-22s %s\n" "yt" "yt-dlp"
    printf "  %-22s %s\n" "ytmp3 <url>" "YouTube → mp3"
    printf "  %-22s %s\n" "ffcut <start> <end> <in> [out]" "copy-cut video"
    printf "  %-22s %s\n" "speed" "speedtest"

    echo
    echo "$M Apps (GPU-wrapped)$R"
    printf "  %-22s %s\n" "obs, jfp" "OBS / Jellyfin Media Player"
    printf "  %-22s %s\n" "obsidian, signal-desktop, zoom-us" "Electron apps"
    printf "  %-22s %s\n" "ghostty, orca-slicer, sunshine" "other GUI apps"
    echo
end

alias cheat='wshelp'

# Browsing & mail
alias zen='flatpak run app.zen_browser.zen'
alias pmail='proton-mail'
function set-defaults --description 'Force default browser/mail/calendar'
    xdg-settings set default-web-browser app.zen_browser.zen.desktop
    xdg-mime default app.zen_browser.zen.desktop x-scheme-handler/http
    xdg-mime default app.zen_browser.zen.desktop x-scheme-handler/https
    xdg-mime default app.zen_browser.zen.desktop text/html
    set pm (ls /var/lib/snapd/desktop/applications/proton-mail_*.desktop ^/dev/null | head -n1 | xargs basename)
    if test -n "$pm"
        xdg-mime default $pm x-scheme-handler/mailto
        xdg-mime default $pm text/calendar
        xdg-mime default $pm x-scheme-handler/webcal
        xdg-mime default $pm x-scheme-handler/webcals
        echo "Defaults set to: $pm"
    else
        echo "Could not find Proton Mail desktop file."
    end
end

# Bluetooth / LDAC helpers
alias bt-restart='systemctl --user restart wireplumber pipewire pipewire-pulse'
function bt-info --description 'Show current BT sinks & recent codec lines'
    echo "=== Sinks ==="
    wpctl status | grep -A2 -i bluez || true
    echo; echo "=== Recent WirePlumber logs (codec) ==="
    journalctl --user -u wireplumber -n 200 --no-pager | grep -i -E 'a2dp|codec|ldac' || true
end


