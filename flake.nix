{
  description = "Ash Nix configuration for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    awww.url = "git+https://codeberg.org/LGFae/awww?ref=main";
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    quickshell.url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
    nix-gaming.url = "github:fufexan/nix-gaming";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";

    mkHost = hostname: username: machineType:
      nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs hostname username machineType;
        };

        modules = [
          {
            nixpkgs.config.allowUnfree = true;
          }
          ./hosts/${machineType}/default.nix
          home-manager.nixosModules.home-manager
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.extraSpecialArgs = {
    inherit inputs hostname username;
  };

  home-manager.users.${username} = {
    imports = [
      ./modules/home
      inputs.spicetify-nix.homeManagerModules.default
    ];
  };
}
        ];
      };
  in
  {
    nixosConfigurations.desktop = mkHost "desktop" "yurxi" "desktop";
    nixosConfigurations.laptop = mkHost "laptop" "yurxi" "laptop";
  };
}