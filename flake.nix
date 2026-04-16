{
  description = "radiosilence dotfiles — nix-darwin + home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }: let
    username = "james.cleveland";

    # Shared home-manager modules — portable across macOS and Linux
    homeModules = [
      ./nix/home.nix
    ];

    mkHomeArgs = {
      dotfiles = self.outPath;
    };
  in {
    # ── macOS (nix-darwin + home-manager) ─────────────────────────────
    darwinConfigurations."James-Cleveland-Mac" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./nix/darwin.nix
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = { imports = homeModules; };
            extraSpecialArgs = mkHomeArgs;
          };

          users.users.${username} = {
            name = username;
            home = "/Users/${username}";
          };
        }
      ];
    };

    # ── Linux (standalone home-manager, no NixOS required) ────────────
    homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = homeModules;
      extraSpecialArgs = mkHomeArgs;
    };

    # ── Convenience apps ──────────────────────────────────────────────
    apps.aarch64-darwin.switch = {
      type = "app";
      program = let
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        script = pkgs.writeShellScript "darwin-switch" ''
          darwin-rebuild switch --flake "${self}" "$@"
        '';
      in "${script}";
    };

    apps.x86_64-linux.switch = {
      type = "app";
      program = let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        script = pkgs.writeShellScript "hm-switch" ''
          home-manager switch --flake "${self}" "$@"
        '';
      in "${script}";
    };
  };
}
