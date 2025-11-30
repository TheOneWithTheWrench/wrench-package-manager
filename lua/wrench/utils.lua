local M = {}

--- Base path where plugins are installed.
M.INSTALL_PATH = vim.fn.stdpath("data") .. "/wrench/plugins"

--- Path to the lockfile.
M.LOCKFILE_PATH = vim.fn.stdpath("config") .. "/wrench-lock.json"

---Extracts the plugin name from a URL.
---@param url string The full URL (e.g., "https://github.com/folke/lazy.nvim").
---@return string name The plugin name (e.g., "lazy.nvim").
function M.get_name(url)
    local name = url:match(".*/(.+)$") or url
    return name:gsub("%.git$", "")
end

---Gets the install path for a plugin.
---@param url string The full URL.
---@return string path The full install path.
function M.get_install_path(url)
    return M.INSTALL_PATH .. "/" .. M.get_name(url)
end

return M
