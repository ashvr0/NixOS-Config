{ config, pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  quickshell = inputs.quickshell;
  awww = inputs.awww;
  nix-gaming = inputs.nix-gaming;
in
{
  environment.systemPackages =
    [
      quickshell.packages.${system}.default
      awww.packages.${system}.awww
      nix-gaming.packages.${system}.osu-lazer-bin
    ]
    ++ (with pkgs; [
      # Core system utilities
      bash
      git
      ripgrep
      fd
      jq
      tree-sitter
      pam

      # Networking and security
      proton-vpn
      openvpn

      # Media tools
      vlc
      yt-dlp
      playerctl
      obsidian

      # Wayland and Hyprland ecosystem
      hypridle
      slurp
      grim
      cliphist

      # Terminal and shell
      alacritty
      fish
      starship
      btop

      # Development stack
      vscodium
      rustc
      cargo
      nodejs
      qt6.qtwayland
      gcc
      gnumake
      pkg-config
      yazi
      thunar
      unzip
      libreoffice
      librewolf 
      
      # Graphics and rendering
      mesa
      mesa-demos
      libglvnd

      # Theming and icons
      papirus-icon-theme
      nordic
      matugen
      nwg-look

      # fun tools
      fastfetch
      cbonsai
      cmatrix
      cava
      peaclock
      lavat
      prismlauncher
    ]);
}
