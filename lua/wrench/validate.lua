local M = {}

---Validates a single plugin config.
---@param config PluginConfig The plugin config to validate.
---@return boolean valid True if valid.
---@return string? error Error message if invalid.
function M.config(config)
	if type(config) ~= "table" then
		return false, "Expected a PluginConfig table"
	end

	local url = config[1] or config.url
	if not url or type(url) ~= "string" then
		return false, "Missing URL (provide as first element or 'url' field)"
	end

	if config.commit and not config.branch then
		return false, "commit requires branch to be specified"
	end

	return true
end

---Validates all plugins and their dependencies recursively.
---@param plugins PluginList The list of plugins to validate.
---@return boolean valid True if all valid.
---@return string? error Error message if any invalid.
function M.all(plugins)
	for _, config in ipairs(plugins) do
		local valid, err = M.config(config)
		if not valid then
			local url = type(config) == "table" and (config[1] or config.url) or "unknown"
			return false, url .. ": " .. (err or "unknown error")
		end

		if config.dependencies then
			local dep_valid, dep_err = M.all(config.dependencies)
			if not dep_valid then
				return false, dep_err
			end
		end
	end

	return true
end

return M
