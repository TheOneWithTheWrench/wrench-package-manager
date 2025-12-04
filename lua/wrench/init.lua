-- wrench/init.lua

local M = {}
local log = require("wrench.log")
local lockfile = require("wrench.lockfile")
local utils = require("wrench.utils")
local process = require("wrench.process")
local commands = require("wrench.commands")
local update_ui = require("wrench.update")
local specs = require("wrench.specs")

commands.setup()

--- The merged spec map (URL → canonical spec).
---@type PluginMap
local spec_map = {}

---@class DependencyRef
---@field url string The plugin URL. This is the ONLY allowed field for dependencies.

---@class PluginSpec
---@field url string The full plugin URL.
---@field ft? string[] (Optional) Only load plugin when opening files of this type.
---@field event? string[] (Optional) Only load plugin when opening files of this type.
---@field dependencies? DependencyRef[] (Optional) Plugins that must be loaded first (url only).
---@field branch? string (Optional) Specify a git branch to clone.
---@field tag? string (Optional) Specify a git tag to checkout.
---@field commit? string (Optional) Pin to a specific commit hash.
---@field config? function (Optional) A function to run after the plugin is loaded.

--- A list of plugins to be processed, each as a PluginSpec table.
---@alias PluginList PluginSpec[]

--- A map of plugin URL to its canonical spec.
---@alias PluginMap table<string, PluginSpec>

---Sets up wrench by scanning for plugins in a directory.
---@param import_path string The path relative to lua/ to scan for plugin specs (e.g., "plugins").
function M.setup(import_path)
	if not import_path or type(import_path) ~= "string" then
		log.error("setup() requires an import path (e.g., 'plugins')")
		return
	end

	local plugins, err = specs.find_all(import_path)

	if not plugins then
		log.error("Failed to find plugins: " .. (err or "unknown error"))
		return
	end

	if vim.tbl_isempty(plugins) then
		log.info("No plugins found in " .. import_path)
		return
	end

	M.add(plugins)
end

--- Adds and processes a map of plugins.
---@param plugins PluginMap A map of URL to PluginSpec.
function M.add(plugins)
	if not plugins or type(plugins) ~= "table" then
		log.error("add() requires a PluginMap.")
		return
	end

	-- Merge into global spec_map
	for url, spec in pairs(plugins) do
		spec_map[url] = spec
	end

	local lock_data = lockfile.read(utils.LOCKFILE_PATH)
	local lock_changed = false

	-- Phase 1: Ensure all plugins are installed
	for url, _ in pairs(plugins) do
		if process.ensure_installed(url, spec_map, lock_data) then
			lock_changed = true
		end
	end

	if lock_changed then
		local ok, write_err = lockfile.write(utils.LOCKFILE_PATH, lock_data)
		if not ok then
			log.error("Failed to write lockfile: " .. (write_err or "unknown error"))
		end
	end

	-- Phase 2: Set up loading for all plugins
	for url, _ in pairs(plugins) do
		process.setup_loading(url, spec_map)
	end
end

---Syncs plugins to the commits specified in config.
---Iterates over all registered plugins and checks out the specified commit if different from current.
function M.sync()
	log.info("Syncing plugins...")

	if vim.tbl_isempty(spec_map) then
		log.warn("No plugins registered. Call setup() first.")
		return
	end

	local lock_data = lockfile.read(utils.LOCKFILE_PATH)
	local lock_changed = false

	-- Remove lockfile entries not in spec_map
	for url, _ in pairs(lock_data) do
		if not spec_map[url] then
			log.info("Removing " .. url .. " from lockfile")
			lock_data[url] = nil
			lock_changed = true
		end
	end

	for url, spec in pairs(spec_map) do
		if process.sync(url, spec, lock_data) then
			lock_changed = true
		end
	end

	if lock_changed then
		local ok, write_err = lockfile.write(utils.LOCKFILE_PATH, lock_data)
		if not ok then
			log.error("Failed to write lockfile: " .. (write_err or "unknown error"))
		end
	end
end

---Updates all plugins to latest (ignores pinned commits).
---Fetches latest commits, shows changes, prompts for approval, then restores.
function M.update()
	log.info("Checking for updates...")

	if vim.tbl_isempty(spec_map) then
		log.warn("No plugins registered. Call setup() first.")
		return
	end

	local lock_data = lockfile.read(utils.LOCKFILE_PATH)

	-- Phase 1: Collect all available updates
	local updates = update_ui.collect_all(spec_map, lock_data)

	if #updates == 0 then
		log.info("All plugins up to date.")
		return
	end

	log.info("Found " .. #updates .. " plugin(s) with updates.")

	-- Phase 2: Interactive review
	local approved = update_ui.review(updates)

	if #approved == 0 then
		log.info("No updates selected.")
		return
	end

	-- Phase 3: Apply approved updates to lockfile
	for _, info in ipairs(approved) do
		lock_data[info.url] = info.new_commit
	end

	local ok, write_err = lockfile.write(utils.LOCKFILE_PATH, lock_data)
	if not ok then
		log.error("Failed to write lockfile: " .. (write_err or "unknown error"))
		return
	end

	-- Phase 4: Restore (checkout the new commits)
	log.info("Applying " .. #approved .. " update(s)...")
	M.restore()
end

---Restores all plugins to the state in the lockfile.
---Plugins not in lockfile will be removed.
function M.restore()
	log.info("Restoring plugins...")

	local lock_data = lockfile.read(utils.LOCKFILE_PATH)

	if vim.tbl_isempty(lock_data) then
		log.warn("Lockfile is empty. Nothing to restore.")
		return
	end

	-- Get list of installed plugins
	local install_dir = utils.INSTALL_PATH
	if vim.fn.isdirectory(install_dir) == 0 then
		log.warn("No plugins installed.")
		return
	end

	local installed = vim.fn.readdir(install_dir)

	-- Build set of plugin names from lockfile
	local locked_names = {}
	for url, _ in pairs(lock_data) do
		locked_names[utils.get_name(url)] = url
	end

	-- Restore or remove each installed plugin
	for _, name in ipairs(installed) do
		local url = locked_names[name]
		if url then
			-- Plugin is in lockfile — restore to locked commit
			process.restore(url, lock_data[url])
		else
			-- Plugin not in lockfile — remove it
			log.warn("Plugin " .. name .. " not in lockfile, removing...")
			process.remove(name)
		end
	end
end

---Returns all registered plugins (for debugging).
---@return PluginMap
function M.get_registered()
	return spec_map
end

return M
