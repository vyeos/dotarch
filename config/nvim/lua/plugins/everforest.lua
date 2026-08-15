return {
  {
    "neanias/everforest-nvim",
    version = false,
    lazy = false,
    priority = 1000, -- make sure to load this before all the other start plugins
    -- Optional; default configuration will be used if setup isn't called.
    config = function()
      require("everforest").setup({
        -- Your config here
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local generated = vim.fn.expand("~/.cache/vyeos/theme/nvim.lua")
        if vim.uv.fs_stat(generated) then
          dofile(generated)
          vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
        else
          vim.cmd.colorscheme("everforest")
        end
      end,
    },
  },
}
