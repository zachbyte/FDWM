-- Used by tests/nvim-load.sh, loaded with --cmd so it runs before init.lua:
-- records every error, then once startup is over loads every plugin (the
-- lazy-loaded ones too) and quits, failing if anything errored.
local errors = {}

local notify = vim.notify
vim.notify = function(msg, level, opts)
	if level and level >= vim.log.levels.ERROR then
		table.insert(errors, tostring(msg))
	end
	return notify(msg, level, opts)
end

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		vim.schedule(function()
			local ok, err = pcall(function()
				local lazy = require("lazy")
				local names = {}
				for _, plugin in ipairs(lazy.plugins()) do
					table.insert(names, plugin.name)
				end
				lazy.load({ plugins = names })
			end)
			if not ok then
				table.insert(errors, "loading plugins: " .. tostring(err))
			end
			if vim.v.errmsg ~= "" then
				table.insert(errors, "v:errmsg: " .. vim.v.errmsg)
			end
			for _, e in ipairs(errors) do
				io.stderr:write("ERROR: " .. e .. "\n")
			end
			io.stderr:write(("%d plugins loaded, %d error(s)\n"):format(#require("lazy").plugins(), #errors))
			io.stderr:write(("colorscheme %s\n"):format(vim.g.colors_name))
			local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
			io.stderr:write(("normal #%06x on #%06x\n"):format(normal.fg or 0, normal.bg or 0))
			vim.cmd(#errors > 0 and "cquit 1" or "qall!")
		end)
	end,
})
