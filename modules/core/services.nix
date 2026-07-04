{ config, pkgs, ... }:
{
  services.xserver.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.printing.enable = true;

  services.usbmuxd.enable = true;

  services.pulseaudio.enable = false;

  services.pipewire = {
  enable = true;

  alsa.enable = true;
  alsa.support32Bit = true;

  pulse.enable = true;

  wireplumber.enable = true;
};

  security.rtkit.enable = true;
  security.polkit.enable = true;

  hardware.bluetooth.enable = true;
}