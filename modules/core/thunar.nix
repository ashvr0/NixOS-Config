{ pkgs, ... }:
{
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-volman
      thunar-archive-plugin
    ];
  };

  services.gvfs.enable = true;
  programs.dconf.enable = true;

  environment.sessionVariables.GTK_THEME = "adw-gtk3-dark";
}