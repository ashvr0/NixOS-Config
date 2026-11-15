{ pkgs, ... }:
{
  time.timeZone = "Asia/Tokyo";
  
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # i2c-dev lets ddcutil talk to the LG monitor over DDC/CI for brightness
  # control from the power menu — there's no /sys/class/backlight device on
  # this desktop since it's an external display, not a laptop panel.
  boot.kernelModules = [ "i2c-dev" ];

  # /dev/i2c-* defaults to root-only; without this rule ddcutil needs sudo
  # every call, which the power menu's Process calls can't prompt for.
  # Matched on SUBSYSTEM rather than KERNEL name — more reliable across
  # udev versions for i2c-dev nodes specifically.
  services.udev.extraRules = ''
    SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
  '';

  system.stateVersion = "25.11"; # DONT TOUCH!!
}