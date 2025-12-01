local M = {}

local ALLOWED_SPEC_FIELDS = {
	url = true,
	[1] = true, -- shorthand for url
	branch = true,
	tag = true,
	commit = true,
	config = true,
	dependencies = true,
	ft = true,
}

---Validates a dependency reference (url only).
---@param dep DependencyRef The dependency to validate.
---@return boolean valid True if valid.
---@return string? error Error message if invalid.
function M.dependency(dep)
	if type(dep) ~= "table" then
		return false, "expected a table"
	end

	local url = dep[1] or dep.url
	if not url or type(url) ~= "string" then
		return false, "missing 'url' field"
	end

	-- Check for disallowed fields
	for key, _ in pairs(dep) do
		if key ~= "url" and key ~= 1 then
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

	local url = spec[1] or spec.url
	if not url or type(url) ~= "string" then
		return false, "missing URL (provide as first element or 'url' field)"
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
			local dep_url = dep[1] or dep.url
			local valid, err = M.dependency(dep)
			if not valid then
				return false, string.format("dependency '%s': %s", dep_url or ("#" .. i), err)
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
			local url = type(spec) == "table" and (spec[1] or spec.url) or "unknown"
			return false, url .. ": " .. (err or "unknown error")
		end
	end

	return true
end

return M
