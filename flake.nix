{
  description = "A post-modern text editor.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixCargoIntegration = {
      url = "github:yusdacra/nix-cargo-integration";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flakeCompat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    helix = {
      url = "https://github.com/helix-editor/helix.git";
      type = "git";
      flake = false;
      submodules = true;
    };
  };

  outputs = inputs@{ nixCargoIntegration, helix, ... }:
    nixCargoIntegration.lib.makeOutputs {
      root = ./.;
      buildPlatform = "crate2nix";
      renameOutputs = { "helix-term" = "helix"; };
      # Set default app to hx (binary is from helix-term release build)
      # Set default package to helix-term release build
      defaultOutputs = { app = "hx"; package = "helix"; };
      overrides = {
        crateOverrides = common: _: {
          helix-term = prev: { buildInputs = (prev.buildInputs or [ ]) ++ [ common.cCompiler.cc.lib ]; };
          # link runtime since helix-core expects it because of embed_runtime feature
          helix-core = _: { preConfigure = "ln -s ${common.root + "/runtime"} ../runtime"; };
          # link languages and theme toml files since helix-view expects them
          helix-view = _: { preConfigure = "ln -s ${common.root}/{languages.toml,theme.toml} .."; };
          helix-syntax = prev: {
            src = common.pkgs.runCommand prev.src.name { } ''
              mkdir -p $out
              ln -s ${prev.src}/* $out
              ln -sf ${helix}/helix-syntax/languages $out
            '';
          };
        };
        shell = common: prev: {
          packages = prev.packages ++ (with common.pkgs; [ lld_10 lldb ]);
          env = prev.env ++ [
            { name = "HELIX_RUNTIME"; eval = "$PWD/runtime"; }
            { name = "RUST_BACKTRACE"; value = "1"; }
            { name = "RUSTFLAGS"; value = "-C link-arg=-fuse-ld=lld -C target-cpu=native"; }
          ];
        };
        build = _: prev: { rootFeatures = prev.rootFeatures ++ [ "embed_runtime" ]; };
      };
    };
}
