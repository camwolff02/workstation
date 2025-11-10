{
  description = "Pinned user environment for Ubuntu via Nix (non-NixOS)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };

        # CLI + GUI apps (system daemons still via apt)
        packages = with pkgs; [
          # core build/dev
          cmake
          gcc
          git gh curl gnumake tree tmux
          openssh
          jq

          # Python & tools (3.11 for Isaac Sim)
          python311
          python311Packages.pip
          python311Packages.venv
          uv

          # Media / docs / CLI
          ffmpeg
          yt-dlp
          pandoc
          speedtest-cli

          # NodeJS (pinned)
          nodejs_22

          # TeX (full)
          texlive.combined.scheme-full

          # GUI apps (use nixGL wrappers on Ubuntu)
          discord
          obs-studio
          obsidian
          signal-desktop
          zoom-us
          jellyfin-media-player
          ghostty
          orca-slicer
          nextcloud-client
          sunshine
          tailscale

          # AI
          llama-cpp
        ];

        # buildEnv so you can `nix profile add .#user-env`
        userEnv = pkgs.buildEnv {
          name = "user-env";
          paths = packages;
        };
      in {
        packages.user-env = userEnv;

        devShells.default = pkgs.mkShell {
          packages = [ pkgs.git pkgs.stow pkgs.nixVersions.latest ];
        };
      });
}

