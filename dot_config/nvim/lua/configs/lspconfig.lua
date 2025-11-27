require("nvchad.configs.lspconfig").defaults()

-- LSP servers to enable
-- Add more servers as needed from: https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
local servers = {
  -- Web
  "html",
  "cssls",
  "ts_ls",          -- TypeScript/JavaScript
  "tailwindcss",

  -- Go
  "gopls",

  -- Lua
  "lua_ls",

  -- Python
  "pyright",

  -- Rust
  "rust_analyzer",

  -- YAML/JSON/TOML
  "yamlls",
  "jsonls",

  -- Bash
  "bashls",

  -- Docker
  "dockerls",
  "docker_compose_language_service",
}

vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers
