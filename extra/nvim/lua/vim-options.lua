vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.wo.relativenumber = true
vim.wo.number = true

vim.api.nvim_set_keymap('n', '<leader>tn', ':tabe<CR>:Neotree filesystem reveal left<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>tt', ':below split | resize 10 | terminal<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>q', ':tabclose<CR>', { noremap = true, silent = true })

vim.opt.list = true
vim.opt.listchars:append("eol:↴")
vim.opt.listchars:append("space:·")
