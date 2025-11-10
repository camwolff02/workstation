{
  description = "Pinned user environment for Ubuntu via Nix (non-NixOS)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        };

        packages = with pkgs; [
          # core build/dev
          cmake
          gcc
          git gh curl gnumake tree tmux
          openssh
          jq

          # Python & tools (Isaac uses 3.11; uv manages venv/pip)
          python311
          uv
          # If you *do* want classic pip:
          # python311Packages.pip

          # media / docs / cli
          ffmpeg
          yt-dlp
          pandoc
          speedtest-cli

          # NodeJS
          nodejs_22

          # TeX (full)
          texlive.combined.scheme-full

          # GUI apps (run via nixGL wrappers on Ubuntu)
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

          # AI
          llama-cpp
        ];

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

