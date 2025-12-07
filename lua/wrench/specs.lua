local M = {}
local log = require("wrench.log")
local validate = require("wrench.validate")

---Recursively scans a directory for .lua files.
---@param path string The directory path to scan.
---@return string[] files List of absolute file paths.
local function scan_directory(path)
	local files = {}

	if vim.fn.isdirectory(path) == 0 then
		return files
	end

	local entries = vim.fn.readdir(path)
	for _, entry in ipairs(entries) do
		local full_path = path .. "/" .. entry

		if vim.fn.isdirectory(full_path) == 1 then
			local nested = scan_directory(full_path)
			for _, file in ipairs(nested) do
				table.insert(files, file)
			end
		elseif entry:match("%.lua$") then
			table.insert(files, full_path)
		end
	end

	return files
end

---Converts a file path to a require-able module name.
---@param file_path string Absolute path to lua file.
---@param base_path string Base lua directory path.
---@return string module_name The module name for require().
local function path_to_module(file_path, base_path)
	local relative = file_path:sub(#base_path + 2)
	local module = relative:gsub("%.lua$", ""):gsub("/", ".")
	return module
end

---Checks if a table is a single PluginSpec (has url field).
---@param tbl table The table to check.
---@return boolean is_single True if it's a single PluginSpec.
local function is_single_spec(tbl)
	return tbl.url ~= nil
end

---Checks if a spec has configuration (more than just url).
---@param spec PluginSpec The spec to check.
---@return boolean has_config True if spec has config or other fields.
local function has_configuration(spec)
	return spec.config ~= nil
		or spec.branch ~= nil
		or spec.tag ~= nil
		or spec.commit ~= nil
		or spec.ft ~= nil
		or spec.keys ~= nil
		or spec.dependencies ~= nil
end

---Merges a new spec into the spec map.
---Returns error if there's a conflict (two specs with config for same URL).
---@param spec_map PluginMap The map to merge into.
---@param spec PluginSpec The spec to merge.
---@param source_file string The file this spec came from (for error messages).
---@param sources table<string, string> Map of URL to source file.
---@return boolean success True if merged successfully.
---@return string? error Error message if conflict.
local function merge_spec(spec_map, spec, source_file, sources)
	local url = spec.url

	local existing = spec_map[url]
	if not existing then
		spec_map[url] = spec
		sources[url] = source_file
		return true
	end

	local existing_has_config = has_configuration(existing)
	local new_has_config = has_configuration(spec)

	if existing_has_config and new_has_config then
		return false, string.format(
			"conflict: plugin '%s' has configuration in both '%s' and '%s'",
			url,
			sources[url],
			source_file
		)
	end

	-- New spec has config, existing doesn't → new wins
	if new_has_config then
		spec_map[url] = spec
		sources[url] = source_file
	end
	-- Otherwise keep existing (it either has config or both are bare)

	return true
end

---Collects dependency URLs from a spec into the spec map (as bare refs).
---@param spec_map PluginMap The map to collect into.
---@param spec PluginSpec The spec whose dependencies to collect.
---@param sources table<string, string> Map of URL to source file.
local function collect_dependencies(spec_map, spec, sources)
	if not spec.dependencies then
		return
	end

	for _, dep in ipairs(spec.dependencies) do
		local url = dep.url
		if not spec_map[url] then
			-- Add as bare spec (just url, no config)
			spec_map[url] = { url = url }
			sources[url] = "(dependency)"
		end
	end
end

---Scans a directory for plugin specs and returns a merged map.
---@param import_path string The import path relative to lua/ (e.g., "plugins").
---@return PluginMap? spec_map Map of URL to canonical spec, or nil on error.
---@return string? error Error message if scanning failed.
function M.find_all(import_path)
	local base_path = vim.fn.stdpath("config") .. "/lua"
	local full_path = base_path .. "/" .. import_path

	if vim.fn.isdirectory(full_path) == 0 then
		log.warn("Plugin directory not found: " .. full_path)
		return {}
	end

	local files = scan_directory(full_path)

	-- Phase 1: Require and validate all specs
	---@type {spec: PluginSpec, source: string}[]
	local all_specs = {}

	for _, file in ipairs(files) do
		local module_name = path_to_module(file, base_path)
		local relative_path = file:sub(#base_path + 2)

		local ok, result = pcall(require, module_name)
		if not ok then
			log.error("Failed to require " .. relative_path .. ": " .. result)
		elseif result ~= nil then
			if type(result) ~= "table" then
				log.error("Invalid spec in " .. relative_path .. ": expected PluginSpec or PluginList, got " .. type(result))
			elseif is_single_spec(result) then
				local valid, err = validate.spec(result)
				if valid then
					table.insert(all_specs, { spec = result, source = relative_path })
				else
					return nil, relative_path .. ": " .. err
				end
			else
				for _, spec in ipairs(result) do
					local valid, err = validate.spec(spec)
					if valid then
						table.insert(all_specs, { spec = spec, source = relative_path })
					else
						local url = spec.url or "unknown"
						return nil, relative_path .. " (" .. url .. "): " .. err
					end
				end
			end
		end
	end

	-- Phase 2: Merge specs by URL
	---@type PluginMap
	local spec_map = {}
	---@type table<string, string>
	local sources = {}

	for _, entry in ipairs(all_specs) do
		local ok, err = merge_spec(spec_map, entry.spec, entry.source, sources)
		if not ok then
			return nil, err
		end
	end

	-- Phase 3: Collect bare dependency refs (for plugins not explicitly configured)
	for _, entry in ipairs(all_specs) do
		collect_dependencies(spec_map, entry.spec, sources)
	end

	return spec_map
end

return M
