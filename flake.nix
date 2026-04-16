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
    hostname = "James-Cleveland-Mac";
    system = "aarch64-darwin";
  in {
    darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
      inherit system;
      modules = [
        ./nix/darwin.nix
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = import ./nix/home.nix;
            extraSpecialArgs = {
              dotfiles = self.outPath;
            };
          };

          users.users.${username} = {
            name = username;
            home = "/Users/${username}";
          };
        }
      ];
    };

    # Convenience: `nix run .#switch`
    apps.${system}.switch = {
      type = "app";
      program = let
        pkgs = nixpkgs.legacyPackages.${system};
        script = pkgs.writeShellScript "darwin-switch" ''
          darwin-rebuild switch --flake "${self}" "$@"
        '';
      in "${script}";
    };
  };
}
