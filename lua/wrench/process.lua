local M = {}
local log = require("wrench.log")
local git = require("wrench.git")
local utils = require("wrench.utils")

--- Tracks which plugins have been processed (deduplication within a session).
---@type table<string, boolean>
local processed = {}

--- Tracks which plugins have been synced (deduplication within a session).
---@type table<string, boolean>
local synced = {}

---Checks if a plugin install is valid (has more than just .git).
---@param path string The plugin install path.
---@return boolean is_valid True if install is valid.
local function is_valid_install(path)
	if vim.fn.isdirectory(path) == 0 then
		return false
	end
	local entries = vim.fn.readdir(path)
	for _, entry in ipairs(entries) do
		if entry ~= ".git" then
			return true
		end
	end
	return false
end

---Processes a single plugin by URL (and its dependencies first).
---@param url string The plugin URL to process.
---@param spec_map PluginMap The map of all specs.
---@param lock_data LockData The lockfile data to update.
---@return boolean lock_changed True if lockfile was updated.
function M.plugin(url, spec_map, lock_data)
	if processed[url] then
		return false
	end
	processed[url] = true

	local spec = spec_map[url]
	if not spec then
		log.error("No spec found for " .. url)
		return false
	end

	local lock_changed = false

	-- Process dependencies first (recursive)
	if spec.dependencies then
		for _, dep in ipairs(spec.dependencies) do
			local dep_url = dep[1] or dep.url
			if M.plugin(dep_url, spec_map, lock_data) then
				lock_changed = true
			end
		end
	end

	local install_path = utils.get_install_path(url)

	if not is_valid_install(install_path) then
		-- Remove corrupted install if exists
		if vim.fn.isdirectory(install_path) == 1 then
			log.warn("Removing corrupted install: " .. utils.get_name(url))
			vim.fn.delete(install_path, "rf")
		end
		log.info("Installing " .. utils.get_name(url) .. "...")
		local opts = {
			branch = spec.branch,
			tag = spec.tag,
			commit = spec.commit,
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
	if spec.ft then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = spec.ft,
			once = true,
			callback = function()
				vim.opt.rtp:prepend(install_path)
				if spec.config and type(spec.config) == "function" then
					spec.config()
				end
			end,
		})
	else
		vim.opt.rtp:prepend(install_path)
		if spec.config and type(spec.config) == "function" then
			spec.config()
		end
	end

	return lock_changed
end

---Syncs a single plugin to the specified commit/tag/branch.
---@param url string The plugin URL.
---@param spec PluginSpec The plugin spec.
---@param lock_data LockData The lockfile data to update.
---@return boolean lock_changed True if lockfile was updated.
function M.sync(url, spec, lock_data)
	-- Skip if already synced
	if synced[url] then
		return false
	end
	synced[url] = true

	local lock_changed = false
	local install_path = utils.get_install_path(url)

	-- Skip if not installed
	if vim.fn.isdirectory(install_path) == 0 then
		return lock_changed
	end

	local ok, err
	local new_commit

	if spec.commit then
		-- Specific commit requested — checkout if different
		local current_commit = git.get_head(install_path)
		if current_commit and current_commit ~= spec.commit then
			ok, err = git.checkout(install_path, spec.commit)
			if ok then
				new_commit = spec.commit
				log.info("Synced " .. url .. " to " .. spec.commit:sub(1, 7))
			end
		else
			-- Already at correct commit, but ensure lockfile is updated
			new_commit = spec.commit
		end
	elseif spec.tag then
		-- Tag requested — checkout tag
		ok, err = git.checkout(install_path, spec.tag)
		if ok then
			new_commit = git.get_head(install_path)
			log.info("Synced " .. url .. " to tag " .. spec.tag)
		end
	elseif spec.branch then
		-- Branch only — checkout branch first (in case of detached HEAD), then pull
		ok, err = git.checkout(install_path, spec.branch)
		if ok then
			ok, err = git.pull(install_path)
			if ok then
				new_commit = git.get_head(install_path)
				log.info("Synced " .. url .. " to latest on " .. spec.branch)
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
---@param name string The plugin name (directory name).
---@return boolean success True if removal succeeded.
function M.remove(name)
	local install_path = utils.INSTALL_PATH .. "/" .. name

	if vim.fn.isdirectory(install_path) == 0 then
		return true -- Already gone
	end

	local ok = vim.fn.delete(install_path, "rf")
	if ok == 0 then
		log.info("Removed " .. name)
		return true
	else
		log.error("Failed to remove " .. name)
		return false
	end
end

return M
