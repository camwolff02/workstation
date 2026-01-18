if status is-interactive
    # Commands to run in interactive sessions can go here
end

function fish_greeting
    fastfetch
end

alias vim nvim
set -gx NOREPLY 36940948+camwolff02@users.noreply.github.com

switch (uname)
    case Linux
        fish_add_path /home/cam/.pixi/bin
    case Darwin
        alias tailscale "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
end
