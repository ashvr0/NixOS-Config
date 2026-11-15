{ config, pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  nix-gaming = inputs.nix-gaming;
in
{
  environment.systemPackages = [
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
      proton-vpn
      openvpn

      # Media tools
      vlc
      yt-dlp
      playerctl
      obsidian
      obs-studio

      # Wayland and Hyprland ecosystem
      hypridle
      hyprsunset
      slurp
      grim
      cliphist
      brightnessctl
      ddcutil
      quickshell
      
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
      bibata-cursors
      matugen
      mpvpaper
      awww
      adw-gtk3

      # fun tools
      fastfetch
      cbonsai
      cmatrix
      cava
      peaclock
      lavat
      pipes

      # Games/Apps
      prismlauncher
      osu-lazer-bin
      vesktop
      steam
    ]);
}
