local M = {}
local log = require("wrench.log")
local git = require("wrench.git")
local utils = require("wrench.utils")

--- Tracks which plugins have been processed (deduplication).
--- NOTE: Future optimization - plugins at same dependency level could be cloned in parallel.
---@type table<string, boolean>
local processed = {}

--- Tracks which plugins have been synced (deduplication).
---@type table<string, boolean>
local synced = {}

---Processes a single plugin (and its dependencies).
---@param plugin PluginConfig The plugin to process.
---@param lock_data LockData The lockfile data to update.
---@return boolean lock_changed True if lockfile was updated.
function M.plugin(plugin, lock_data)
	local url = plugin[1] or plugin.url

	-- Skip if already processed (deduplication)
	if processed[url] then --- NOTE: Future problem: What if same plugin with different branch/commit?
		return false
	end
	processed[url] = true

	local lock_changed = false

	-- Process dependencies recursively first
	if plugin.dependencies then
		for _, dep in ipairs(plugin.dependencies) do
			if M.plugin(dep, lock_data) then
				lock_changed = true
			end
		end
	end

	local install_path = utils.get_install_path(url)

	-- Clone if not already installed
	if vim.fn.isdirectory(install_path) == 0 then
		log.info("Installing " .. utils.get_name(url) .. "...")
		local opts = {
			branch = plugin.branch,
			tag = plugin.tag,
			commit = plugin.commit,
		}
		local ok, err = git.clone(url, install_path, opts)
		if not ok then
			log.error("Failed to clone " .. url .. ": " .. (err or "unknown error"))
			return lock_changed
		end

		log.info("Installed " .. url)
	end

	-- Ensure lockfile entry exists
	if not lock_data[url] then
		local commit = git.get_head(install_path)
		if commit then
			lock_data[url] = commit
			lock_changed = true
		end
	end

	-- Load plugin (immediately or deferred)
	if plugin.ft then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = plugin.ft,
			once = true,
			callback = function()
				vim.opt.rtp:prepend(install_path)
				if plugin.config and type(plugin.config) == "function" then
					plugin.config()
				end
			end,
		})
	else
		vim.opt.rtp:prepend(install_path)
		if plugin.config and type(plugin.config) == "function" then
			plugin.config()
		end
	end

	return lock_changed
end

---Syncs a single plugin (and its dependencies) to the specified commit/tag/branch.
---@param plugin PluginConfig The plugin to sync.
---@param lock_data LockData The lockfile data to update.
---@return boolean lock_changed True if lockfile was updated.
function M.sync(plugin, lock_data)
	local url = plugin[1] or plugin.url

	-- Skip if already synced (deduplication)
	if synced[url] then
		return false
	end
	synced[url] = true

	local lock_changed = false

	-- Sync dependencies first
	if plugin.dependencies then
		for _, dep in ipairs(plugin.dependencies) do
			if M.sync(dep, lock_data) then
				lock_changed = true
			end
		end
	end

	local install_path = utils.get_install_path(url)

	-- Skip if not installed
	if vim.fn.isdirectory(install_path) == 0 then
		return lock_changed
	end

	local ok, err
	local new_commit

	if plugin.commit then
		-- Specific commit requested — checkout if different
		local current_commit = git.get_head(install_path)
		if current_commit and current_commit ~= plugin.commit then
			ok, err = git.checkout(install_path, plugin.commit)
			if ok then
				new_commit = plugin.commit
				log.info("Synced " .. url .. " to " .. plugin.commit:sub(1, 7))
			end
		else
			-- Already at correct commit, but ensure lockfile is updated
			new_commit = plugin.commit
		end
	elseif plugin.tag then
		-- Tag requested — checkout tag
		ok, err = git.checkout(install_path, plugin.tag)
		if ok then
			new_commit = git.get_head(install_path)
			log.info("Synced " .. url .. " to tag " .. plugin.tag)
		end
	elseif plugin.branch then
		-- Branch only — checkout branch first (in case of detached HEAD), then pull
		ok, err = git.checkout(install_path, plugin.branch)
		if ok then
			ok, err = git.pull(install_path)
			if ok then
				new_commit = git.get_head(install_path)
				log.info("Synced " .. url .. " to latest on " .. plugin.branch)
			end
		end
	end

	if not ok and err then
		log.error("Failed to sync " .. url .. ": " .. err)
	end

	if new_commit then
		lock_data[url] = new_commit
		lock_changed = true
	end

	return lock_changed
end

---Restores a plugin to the commit specified in lockfile.
---@param url string The plugin URL.
---@param commit string The commit SHA to restore to.
---@return boolean success True if restore succeeded.
function M.restore(url, commit)
	local install_path = utils.get_install_path(url)

	if vim.fn.isdirectory(install_path) == 0 then
		log.warn("Cannot restore " .. url .. ": not installed")
		return false
	end

	local current_commit = git.get_head(install_path)
	if current_commit == commit then
		return true -- Already at correct commit
	end

	local ok, err = git.checkout(install_path, commit)
	if ok then
		log.info("Restored " .. url .. " to " .. commit:sub(1, 7))
		return true
	else
		log.error("Failed to restore " .. url .. ": " .. (err or "unknown error"))
		return false
	end
end

---Removes a plugin directory.
---@param url string The plugin URL.
---@return boolean success True if removal succeeded.
function M.remove(url)
	local install_path = utils.get_install_path(url)

	if vim.fn.isdirectory(install_path) == 0 then
		return true -- Already gone
	end

	local ok = vim.fn.delete(install_path, "rf")
	if ok == 0 then
		log.info("Removed " .. url)
		return true
	else
		log.error("Failed to remove " .. url)
		return false
	end
end

return M
