{ inputs, host, ... }:
{
  imports = [
    ./bootloader.nix
    ./network.nix
    ./services.nix
    ./system.nix
    ./fonts.nix
    ./packages.nix
    ./user.nix
    ./ly.nix
    ./hyprland.nix
  ];
}
