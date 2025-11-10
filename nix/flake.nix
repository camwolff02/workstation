{
  description = "Pinned user environment for Ubuntu via Nix (non-NixOS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;  # needed for discord/zoom, etc.
        };

        packages = with pkgs; [
          # CLI/dev
          git gh curl jq tree tmux
          gcc gnumake cmake
          python311
          uv
          ffmpeg yt-dlp pandoc speedtest-cli
          nodejs_22
          texlive.combined.scheme-full

          # GUI apps (run via nixGLNvidia wrapper on Ubuntu)
          discord obs-studio obsidian signal-desktop zoom-us
          ghostty orca-slicer nextcloud-client sunshine

          # AI
          llama-cpp
        ];

      in {
        # One thing to install into your user profile
        packages.user-env = pkgs.buildEnv { name = "user-env"; paths = packages; };

        # Handy dev shell for repo maintenance
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.git pkgs.stow pkgs.nixVersions.latest ];
        };
      });
}

