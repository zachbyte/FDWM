return {
	"nvim-lualine/lualine.nvim",
	config = function()
		require("lualine").setup({
			options = {
				theme = "catppuccin-mocha", -- in the palette's colors (plugins/catppuccin.lua)
			},
		})
	end,
}
