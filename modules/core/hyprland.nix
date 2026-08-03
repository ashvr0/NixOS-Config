{ config, pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    XCURSOR_THEME = "Nordic-cursors";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Nordic-cursors";
    HYPRCURSOR_SIZE = "24";
  };

  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  boot.blacklistedKernelModules = [ "nouveau" ];

  boot.kernelParams = [
    "nvidia-drm.modeset=1"
  ];
}