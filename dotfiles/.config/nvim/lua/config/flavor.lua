-- The Catppuccin flavor to use: the one fdwm-theme last switched the desktop
-- to (~/.config/fdwm/flavor), or Mocha until then.
local path = vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "fdwm", "flavor")
local file = io.open(path)
local flavor = file and file:read("l")
if file then
	file:close()
end

local flavors = { latte = true, frappe = true, macchiato = true, mocha = true }
return flavors[flavor] and flavor or "mocha"
