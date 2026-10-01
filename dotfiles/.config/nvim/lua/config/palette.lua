-- FDWM's colors, the ones fdwm-theme last generated for the desktop from its
-- palette (~/.config/fdwm/colors.sh), as { base = "#rrggbb", ... }: empty
-- until it has run.
local path = vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "fdwm", "colors.sh")
local colors = {}
local file = io.open(path)
if file then
	for line in file:lines() do
		local name, hex = line:match("^fdwm_([%w_]+)='(#%x%x%x%x%x%x)'$")
		if name then
			colors[name] = hex
		end
	end
	file:close()
end
return colors
