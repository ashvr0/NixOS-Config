{ config, pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  quickshell = inputs.quickshell;
  awww = inputs.awww;
  nix-gaming = inputs.nix-gaming;
in
{
  environment.systemPackages = [
      quickshell.packages.${system}.default
      awww.packages.${system}.awww
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
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
      python3
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
      ffmpeg
      
      # Graphics and rendering
      mesa
      mesa-demos
      libglvnd

      # Theming and icons
      papirus-icon-theme
      nordic
      matugen

      # fun tools
      fastfetch
      cbonsai
      cmatrix
      cava
      peaclock
      lavat
      pipes

      # Games
      prismlauncher
      osu-lazer-bin

      subfinder
      httpx
      ffuf
      dig
      mpvpaper
    ]);
}
