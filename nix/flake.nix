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

        # CLI + GUI apps you listed (apt kept for system daemons)
        packages = with pkgs; [
          # CLI/dev tools
          cmake buildPackages.stdenv.cc  # gcc
          git gh curl make tree tmux openssh openssh_hpn_client
          neovim ffmpeg python311Full python311Packages.pip
          python311Packages.venv
          libfuse2 speedtest-cli pandoc nodejs jq
          yt-dlp latexmk texliveFull
          libudev gtk4 udev # headers/libs where helpful
          fish uv
          rustup

          # GUI apps (will be wrapped by nixGL for NVIDIA)
          discord obs-studio obsidian
          signal-desktop zoom-us
          jellyfin-media-player  # client only
          ghostty
          orca-slicer
          nextcloud-client
          sunshine
          tailscale
          llama-cpp llama-cpp-server
        ];

        # A single buildEnv you can `nix profile install` from
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

