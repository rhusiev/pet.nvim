vim.api.nvim_create_user_command("PetStartParty", function()
	require("pet").start_pet_party()
end, { nargs = 0 })

vim.api.nvim_create_user_command("PetStopParty", function()
	require("pet").stop_pet_party()
end, { nargs = 0 })

vim.api.nvim_create_user_command("PetAdd", function()
	require("pet").add_pet()
end, { nargs = 0 })
