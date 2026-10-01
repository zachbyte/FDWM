return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	config = function()
		-- the desktop's colors: Catppuccin Mocha with each of its colors
		-- replaced by the palette's entry of the same name, in the flavor
		-- fdwm-theme last switched to (Mocha's own until it has run)
		local palette = require("config.palette")
		local colors = {}
		for name in pairs(require("catppuccin.palettes.mocha")) do
			colors[name] = palette[name]
		end
		require("catppuccin").setup({ color_overrides = { mocha = colors } })
		vim.cmd.colorscheme("catppuccin-mocha")
	end,
}
