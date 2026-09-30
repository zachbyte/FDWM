return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	config = function()
		-- the desktop's flavor (fdwm-theme)
		vim.cmd.colorscheme("catppuccin-" .. require("config.flavor"))
	end,
}
