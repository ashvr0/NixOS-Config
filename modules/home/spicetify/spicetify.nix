{ pkgs, inputs, config, lib, ... }:

let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.spicetify = {
    enable = true;
    alwaysEnableDevTools = true;
    experimentalFeatures = true;

    theme = {
      name = "Tui";
      src = ./Tui;
      injectCss = true;
      replaceColors = true;
      overwriteAssets = false;
      sidebarConfig = true;
    };

    colorScheme = "TokyoNight";

    enabledExtensions = with spicePkgs.extensions; [
      shuffle
      hidePodcasts
      adblock
    ];

    enabledCustomApps = with spicePkgs.apps; [
      marketplace
    ];
  };
}