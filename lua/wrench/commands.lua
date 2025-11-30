local M = {}

function M.setup()
	vim.api.nvim_create_user_command("WrenchSync", function()
		require("wrench").sync()
	end, { desc = "Sync plugins to config" })

	vim.api.nvim_create_user_command("WrenchRestore", function()
		require("wrench").restore()
	end, { desc = "Restore plugins to lockfile" })

	vim.api.nvim_create_user_command("WrenchGetRegistered", function()
		print(vim.inspect(require("wrench").get_registered()))
	end, { desc = "Show registered plugins" })

	vim.api.nvim_create_user_command("WrenchUpdate", function()
		require("wrench").update()
	end, { desc = "Update plugins to latest" })
end

return M
