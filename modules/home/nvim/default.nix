{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      ripgrep
      fd
      lua-language-server
      pyright
      nil
      nixpkgs-fmt
    ];

plugins = with pkgs.vimPlugins; [
  tokyonight-nvim
  alpha-nvim
  nvim-web-devicons

  nvim-treesitter.withAllGrammars

  telescope-nvim
  telescope-fzf-native-nvim
  telescope-ui-select-nvim

  nvim-tree-lua

  lualine-nvim
  bufferline-nvim

  gitsigns-nvim
  which-key-nvim
  indent-blankline-nvim

  nvim-autopairs
  comment-nvim

  nvim-lspconfig

  nvim-cmp
  cmp-nvim-lsp
  cmp-buffer
  cmp-path
  cmp-cmdline
  cmp_luasnip

  luasnip
  friendly-snippets

  vim-fugitive
  plenary-nvim
  trouble-nvim
  todo-comments-nvim
];
  };

  xdg.configFile."nvim/init.lua".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/modules/home/nvim/init.lua";
}