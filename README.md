# Wrench

> ⚠️ **Disclaimer**: This project was built as a learning exercise for Lua and Neovim plugin development. There's no good reason to use this over established plugin managers like [lazy.nvim](https://github.com/folke/lazy.nvim). Use at your own risk!

A minimal Neovim plugin manager.

## Install

Add to your `init.lua`:

```lua
local wrenchpath = vim.fn.stdpath("data") .. "/wrench"
if not vim.loop.fs_stat(wrenchpath) then
    vim.fn.system({
        "git",
        "clone",
        "https://github.com/TheOneWithTheWrench/wrench.nvim.git",
        wrenchpath,
    })
end
vim.opt.rtp:prepend(wrenchpath)

require("wrench").add({
    { url = "https://github.com/folke/tokyonight.nvim", branch = "main" },
    {
        url = "https://github.com/folke/which-key.nvim",
        branch = "main",
        config = function()
            require("which-key").setup()
        end,
    },
})

vim.cmd.colorscheme("tokyonight")
```

## Plugin spec

```lua
{
    url = "https://github.com/owner/repo",  -- required
    branch = "main",                         -- optional
    tag = "v1.0.0",                          -- optional
    commit = "abc123...",                    -- optional, pins to exact commit
    config = function() ... end,             -- optional, runs after load
    dependencies = { ... },                  -- optional, other plugin specs
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:WrenchUpdate` | Fetch latest, review changes, update |
| `:WrenchSync` | Sync plugins to config |
| `:WrenchRestore` | Restore plugins to lockfile |
| `:WrenchGetRegistered` | Show registered plugins |

## License

MIT
