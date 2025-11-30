
local M = {}

---@class CloneOptions
---@field tag? string The tag to checkout after cloning.
---@field branch? string The branch to checkout after cloning.
---@field commit? string The commit hash to checkout after cloning.

---Clones a git repository to the specified destination.
---@param url string The Git repository URL to clone.
---@param path string The destination directory where the repository will be cloned.
---@param opts? CloneOptions Options for cloning.
---@return boolean success True if clone succeeded.
---@return string? error Error message if clone failed.
function M.clone(url, path, opts)
    opts = opts or {}

    local cmd = { "git", "clone" }

    if opts.branch then
        table.insert(cmd, "--branch")
        table.insert(cmd, opts.branch)
    elseif opts.tag then
        table.insert(cmd, "--branch")
        table.insert(cmd, opts.tag)
    end

    table.insert(cmd, url)
    table.insert(cmd, path)

    local result = vim.system(cmd):wait()
    if result.code ~= 0 then
        return false, "git clone failed: " .. (result.stderr or "")
    end

    if opts.commit then
        result = vim.system({ "git", "-C", path, "checkout", opts.commit }):wait()
        if result.code ~= 0 then
            return false, "git checkout failed: " .. (result.stderr or "")
        end
    end

    return true
end

---Pulls the latest changes for a repository.
---@param path string Path to the git repository.
---@return boolean success True if pull succeeded.
---@return string? error Error message if failed.
function M.pull(path)
    local result = vim.system({ "git", "-C", path, "pull" }):wait()
    if result.code ~= 0 then
        return false, "git pull failed: " .. (result.stderr or "")
    end

    return true
end

---Returns the current HEAD commit SHA for a repository.
---@param path string Path to the git repository.
---@return string? sha The 40-character commit SHA, or nil on error.
---@return string? error Error message if failed.
function M.get_head(path)
    local result = vim.system({ "git", "-C", path, "rev-parse", "HEAD" }):wait()
    if result.code ~= 0 then
        return nil, "git rev-parse failed: " .. (result.stderr or "")
    end

    return vim.trim(result.stdout)
end

---Returns the current branch name for a repository.
---@param path string Path to the git repository.
---@return string? branch The branch name, or nil on error (e.g., detached HEAD).
---@return string? error Error message if failed.
function M.get_branch(path)
    local result = vim.system({ "git", "-C", path, "rev-parse", "--abbrev-ref", "HEAD" }):wait()
    if result.code ~= 0 then
        return nil, "git rev-parse failed: " .. (result.stderr or "")
    end

    local branch = vim.trim(result.stdout)
    if branch == "HEAD" then
        return nil, "detached HEAD state"
    end

    return branch
end

---Fetches latest changes from remote.
---@param path string Path to the git repository.
---@return boolean success True if fetch succeeded.
---@return string? error Error message if failed.
function M.fetch(path)
    local result = vim.system({ "git", "-C", path, "fetch" }):wait()
    if result.code ~= 0 then
        return false, "git fetch failed: " .. (result.stderr or "")
    end

    return true
end

---Returns the commit SHA of a remote branch.
---@param path string Path to the git repository.
---@param branch string The branch name.
---@return string? sha The commit SHA, or nil on error.
---@return string? error Error message if failed.
function M.get_remote_head(path, branch)
    local result = vim.system({ "git", "-C", path, "rev-parse", "origin/" .. branch }):wait()
    if result.code ~= 0 then
        return nil, "git rev-parse failed: " .. (result.stderr or "")
    end

    return vim.trim(result.stdout)
end

---Gets commit log between two commits.
---@param path string Path to the git repository.
---@param old_commit string The older commit SHA.
---@param new_commit string The newer commit SHA.
---@return string[]? lines List of log lines, or nil on error.
function M.log_range(path, old_commit, new_commit)
    local result = vim.system({ "git", "-C", path, "log", "--oneline", old_commit .. ".." .. new_commit }):wait()
    if result.code ~= 0 then
        return nil
    end

    local lines = {}
    for line in result.stdout:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    return lines
end

---Gets the latest tag for a commit.
---@param path string Path to the git repository.
---@param commit string The commit SHA.
---@return string? tag The tag name, or nil if no tag.
function M.describe_tag(path, commit)
    local result = vim.system({ "git", "-C", path, "describe", "--tags", "--abbrev=0", commit, "2>/dev/null" }):wait()
    if result.code ~= 0 then
        return nil
    end
    return vim.trim(result.stdout)
end

---Checks out a specific ref (commit, tag, or branch) in a repository.
---@param path string Path to the git repository.
---@param ref string The ref to checkout (commit SHA, tag, or branch).
---@return boolean success True if checkout succeeded.
---@return string? error Error message if failed.
function M.checkout(path, ref)
    local result = vim.system({ "git", "-C", path, "checkout", ref }):wait()
    if result.code ~= 0 then
        return false, "git checkout failed: " .. (result.stderr or "")
    end

    return true
end

return M
