return {
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.8",
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = "Telescope",
		keys = {
			{ "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Telescope find files" },
			{ "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Telescope live grep" },
			{ "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Telescope buffers" },
			{ "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Telescope help tags" },
		},
		config = function()
			require("telescope").setup({
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
				},
			})
		end,
	},
	{
		-- loads right after startup (and telescope.nvim with it) so code
		-- actions and other vim.ui.select prompts open in Telescope
		"nvim-telescope/telescope-ui-select.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-telescope/telescope.nvim" },
		config = function()
			require("telescope").load_extension("ui-select")
		end,
	},
}
