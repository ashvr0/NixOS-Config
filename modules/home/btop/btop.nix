{ ... }:
{
  
  programs.btop.enable = true;

  home.file.".config/btop/btop.conf".text = ''
    color_theme="TTY"
    theme_background=False
    update_ms=500
    rounded_corners=False
  '';
}
