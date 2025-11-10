{
  description = "Pinned user environment for Ubuntu via Nix (non-NixOS)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  # ADD THIS: bring in nixGL (and follow your nixpkgs to avoid duplication)
  inputs.nixgl.url = "github:nix-community/nixGL";
  inputs.nixgl.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, nixgl, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        };

        # nixGL packages for this system (provides nixGLNvidia, etc.)
        nixglPkgs = nixgl.packages.${system};

        packages = with pkgs; [
          cmake gcc git gh curl gnumake tree tmux
          openssh jq
          python311 uv
          ffmpeg yt-dlp pandoc speedtest-cli
          nodejs_22
          texlive.combined.scheme-full

          # GUI apps (you wrap these with nixGLNvidia)
          discord obs-studio obsidian signal-desktop zoom-us
          ghostty orca-slicer nextcloud-client sunshine

          llama-cpp
          # ADD THIS: the actual wrapper binary
          # (will be on PATH as 'nixGLNvidia')
        ] ++ [
          nixglPkgs.nixGLNvidia
        ];

        userEnv = pkgs.buildEnv { name = "user-env"; paths = packages; };
      in {
        packages.user-env = userEnv;
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.git pkgs.stow pkgs.nixVersions.latest ];
        };
      });
}

