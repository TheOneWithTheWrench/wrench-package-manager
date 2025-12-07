local M = {}

local ALLOWED_SPEC_FIELDS = {
	url = true,
	ft = true,
	event = true,
	keys = true,
	branch = true,
	tag = true,
	commit = true,
	config = true,
	dependencies = true,
}

---Validates a single key spec.
---@param key KeySpec The key spec to validate.
---@return boolean valid True if valid.
---@return string? error Error message if invalid.
function M.key(key)
	if type(key) ~= "table" then
		return false, "expected a table"
	end

	if not key.lhs or type(key.lhs) ~= "string" then
		return false, "missing or invalid 'lhs' field (must be a string)"
	end

	if key.rhs == nil then
		return false, "missing 'rhs' field"
	end

	if type(key.rhs) ~= "function" then
		return false, "invalid 'rhs' field (must be a function)"
	end

	if key.mode ~= nil then
		if type(key.mode) ~= "table" then
			return false, "invalid 'mode' field (must be a table of strings)"
		end
		for i, m in ipairs(key.mode) do
			if type(m) ~= "string" then
				return false, string.format("invalid 'mode[%d]' (must be a string)", i)
			end
		end
	end

	return true
end

---Validates a dependency reference (url only).
---@param dep DependencyRef The dependency to validate.
---@return boolean valid True if valid.
---@return string? error Error message if invalid.
function M.dependency(dep)
	if type(dep) ~= "table" then
		return false, "expected a table"
	end

	if not dep.url or type(dep.url) ~= "string" then
		return false, "missing 'url' field"
	end

	-- Check for disallowed fields
	for key, _ in pairs(dep) do
		if key ~= "url" then
			return false, string.format(
				"should only have 'url' field, found '%s'\n\n       If you need to configure this plugin, create a dedicated spec file.",
				key
			)
		end
	end

	return true
end

---Validates a single plugin spec.
---@param spec PluginSpec The plugin spec to validate.
---@return boolean valid True if valid.
---@return string? error Error message if invalid.
function M.spec(spec)
	if type(spec) ~= "table" then
		return false, "expected a PluginSpec table"
	end

	if not spec.url or type(spec.url) ~= "string" then
		return false, "missing 'url' field"
	end

	-- Check for unknown fields
	for key, _ in pairs(spec) do
		if not ALLOWED_SPEC_FIELDS[key] then
			return false, string.format("unknown field '%s'", key)
		end
	end

	if spec.commit and not spec.branch then
		return false, "commit requires branch to be specified"
	end

	-- Validate dependencies
	if spec.dependencies then
		if type(spec.dependencies) ~= "table" then
			return false, "dependencies must be a table"
		end

		for i, dep in ipairs(spec.dependencies) do
			local valid, err = M.dependency(dep)
			if not valid then
				return false, string.format("dependency '%s': %s", dep.url or ("#" .. i), err)
			end
		end
	end

	-- Validate keys
	if spec.keys then
		if type(spec.keys) ~= "table" then
			return false, "keys must be a table"
		end

		for i, key in ipairs(spec.keys) do
			local valid, err = M.key(key)
			if not valid then
				return false, string.format("key #%d (%s): %s", i, key.lhs or "unknown", err)
			end
		end
	end

	return true
end

---Validates all plugins.
---@param plugins PluginList The list of plugins to validate.
---@return boolean valid True if all valid.
---@return string? error Error message if any invalid.
function M.all(plugins)
	for _, spec in ipairs(plugins) do
		local valid, err = M.spec(spec)
		if not valid then
			local url = type(spec) == "table" and spec.url or "unknown"
			return false, url .. ": " .. (err or "unknown error")
		end
	end

	return true
end

return M
