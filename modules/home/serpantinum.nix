{ config, ... }:
{
  programs.serpantinum = {
    enable = true;
    systemd.enable = true;
    settings.wallpaperDir = "/home/${config.home.username}/Pictures/Wallpapers";
  };
}
