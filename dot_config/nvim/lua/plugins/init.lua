return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- format on save
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        -- Core
        "vim", "lua", "vimdoc", "query", "regex",

        -- Web
        "html", "css", "javascript", "typescript", "tsx", "json", "jsonc",

        -- Go
        "go", "gomod", "gosum", "gowork",

        -- Config
        "yaml", "toml", "dockerfile", "bash",

        -- Markdown
        "markdown", "markdown_inline",

        -- Git
        "gitcommit", "gitignore", "git_rebase",
      },
      highlight = {
        enable = true,
      },
      indent = {
        enable = true,
      },
    },
  },
}
