{ config, pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";

    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    
    # CRITICAL: Force Nvidia to use proper scaling
    __GL_GSYNC_ALLOWED = "0";
    __GL_VRR_ALLOWED = "0";
    
    # Fix for Electron apps (Discord, VSCode, etc.)
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    
    # Disable hardware cursors
    WLR_NO_HARDWARE_CURSORS = "1";
    
    # Force Nvidia EGL
    EGL_PLATFORM = "wayland";
    
    NVIDIA_DRIVER_CAPABILITIES = "compute,graphics,utility";
  };

  # Force QT applications to use Wayland
  environment.sessionVariables.QT_QPA_PLATFORM = "wayland";
  environment.sessionVariables.QT_WAYLAND_FORCE_DPI = "physical";
  
  # Force GDK (GTK) applications to use Wayland
  environment.sessionVariables.GDK_BACKEND = "wayland";
  
  # Set cursor size
  environment.sessionVariables.XCURSOR_SIZE = "24";

  # Cursor theme (Nordic-cursors)
  environment.sessionVariables.XCURSOR_THEME = "Nordic-cursors";
  environment.sessionVariables.HYPRCURSOR_THEME = "Nordic-cursors";
  environment.sessionVariables.HYPRCURSOR_SIZE = "24";

  hardware.graphics = {
    enable = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = true;
    nvidiaSettings = true;
    
    # Use stable driver
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    
    # IMPORTANT: Disable PRIME since you don't have hybrid graphics
    # Remove or comment out the prime section entirely
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  boot.blacklistedKernelModules = [ "nouveau" ];
  
  boot.kernelParams = [ 
    "nvidia-drm.modeset=1" 
    "nvidia-drm.fbdev=1"
  ];
}