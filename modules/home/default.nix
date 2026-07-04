{ pkgs, inputs, username, ... }:

let
  awww = inputs.awww;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    ./hypr/default.nix
    ./quickshell/default.nix
    ./alacritty/default.nix
    ./fish/default.nix
    ./btop.nix
    ./cava/default.nix
    ./spicetify/spicetify.nix
    ./matugen/default.nix
    ./nvim/default.nix
    ./fastfetch/default.nix
    ./yazi.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";
  home.enableNixpkgsReleaseCheck = false;

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    wl-clipboard
    libnotify
    dunst
    waybar
    hyprpaper
    awww.packages.${system}.awww
  ];
}