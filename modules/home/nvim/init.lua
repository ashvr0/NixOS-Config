-- Options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.termguicolors = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.spell = true
vim.opt.spelllang = "en"

vim.g.mapleader = " "

-- TOKYONIGHT + MATUGEN
local function apply_matugen_theme()
  local path = vim.fn.stdpath("config") .. "/matugen_colors.lua"

  local ok, colors = pcall(dofile, path)
  if not ok then
    colors = {}
  end

  require("tokyonight").setup({
    style = "night",
    transparent = false,
    terminal_colors = true,

    on_colors = function(c)
      c.bg = colors.base or c.bg
      c.bg_dark = colors.mantle or c.bg_dark
      c.bg_float = colors.surface0 or c.bg_float

      c.fg = colors.text or c.fg
      c.fg_dark = colors.subtext0 or c.fg_dark
      c.comment = colors.overlay1 or c.comment

      c.red = colors.red or c.red
      c.orange = colors.peach or c.orange
      c.yellow = colors.yellow or c.yellow
      c.green = colors.green or c.green
      c.blue = colors.blue or c.blue
      c.magenta = colors.mauve or c.magenta
      c.cyan = colors.sky or c.cyan

      c.border = colors.overlay0 or c.border
    end,
  })

  vim.cmd.colorscheme("tokyonight")

  pcall(function()
    require("lualine").refresh()
  end)
end

apply_matugen_theme()

local uv = vim.uv or vim.loop
local matugen_path = vim.fn.stdpath("config") .. "/matugen_colors.lua"

local watcher = uv.new_fs_event()
local timer

watcher:start(matugen_path, {}, function()
  if timer then
    timer:stop()
    timer:close()
  end

  timer = uv.new_timer()
  timer:start(100, 0, vim.schedule_wrap(function()
    apply_matugen_theme()

    timer:stop()
    timer:close()
    timer = nil
  end))
end)

-- Nvim Tree
require("nvim-tree").setup()

vim.keymap.set(
  "n",
  "<leader>\\",
  ":NvimTreeToggle<CR>",
  { noremap = true, silent = true }
)

-- Lualine
require("lualine").setup({
  options = {
    theme = "tokyonight",
    component_separators = "",
    section_separators = {
      left = "",
      right = "",
    },
    globalstatus = true,
  },
})

-- Telescope
local builtin = require("telescope.builtin")

vim.keymap.set("n", "<leader>ff", builtin.find_files)
vim.keymap.set("n", "<leader>fg", builtin.live_grep)
vim.keymap.set("n", "<leader>fb", builtin.buffers)
vim.keymap.set("n", "<leader>fh", builtin.help_tags)

-- Alpha Dashboard
local alpha = require("alpha")
local dashboard = require("alpha.themes.dashboard")

dashboard.section.header.val = {
  "███╗   ██╗██╗   ██╗██╗███╗   ███╗",
  "████╗  ██║██║   ██║██║████╗ ████║",
  "██╔██╗ ██║██║   ██║██║██╔████╔██║",
  "██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
  "██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║",
  "╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
  "",
}

dashboard.section.buttons.val = {
  dashboard.button("f", " Find file", "<cmd>Telescope find_files<CR>"),
  dashboard.button("g", " Live grep", "<cmd>Telescope live_grep<CR>"),
  dashboard.button("r", " Recent files", "<cmd>Telescope oldfiles<CR>"),
  dashboard.button("e", " New file", "<cmd>ene<CR>"),
  dashboard.button("q", " Quit", "<cmd>qa<CR>"),
}

alpha.setup(dashboard.config)

