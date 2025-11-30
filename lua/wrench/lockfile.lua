local M = {}

---@class LockEntry
---@field branch string The branch the plugin is on.
---@field commit string The commit SHA.

---@alias LockData table<string, LockEntry> Map of plugin URL to lock entry.

---Reads the lockfile from disk.
---@param path string Path to the lockfile.
---@return LockData data The parsed lockfile, or empty table if file doesn't exist.
---@return string? error Error message if parsing failed.
function M.read(path)
    if vim.fn.filereadable(path) == 0 then
        return {}
    end

    local lines = vim.fn.readfile(path)
    local content = table.concat(lines, "\n")

    local ok, data = pcall(vim.json.decode, content)
    if not ok then
        return {}, "Failed to parse lockfile: " .. data
    end

    return data
end

---Formats lock data as pretty JSON.
---@param data LockData
---@return string
local function format_json(data)
    local lines = { "{" }
    local keys = vim.tbl_keys(data)
    table.sort(keys)
    for i, url in ipairs(keys) do
        local entry = data[url]
        local comma = i < #keys and "," or ""
        table.insert(lines, string.format('  "%s": {"branch": "%s", "commit": "%s"}%s', url, entry.branch, entry.commit, comma))
    end
    table.insert(lines, "}")
    return table.concat(lines, "\n")
end

---Writes lock data to disk as JSON.
---@param path string Path to the lockfile.
---@param data LockData The lock data to write.
---@return boolean success True if write succeeded.
---@return string? error Error message if write failed.
function M.write(path, data)
    local json = format_json(data)
    local lines = vim.split(json, "\n")
    local result = vim.fn.writefile(lines, path)
    if result ~= 0 then
        return false, "Failed to write lockfile"
    end

    return true
end

return M
