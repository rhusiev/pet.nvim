local M = {}
local n_pets = 0
local do_party = false

local choose_new_spot = function(conf, attached_to_win)
	local attached_to_wininfo = vim.fn.getwininfo(attached_to_win)[1]
	local x, y =
		math.random(attached_to_wininfo.wincol + attached_to_wininfo.width - conf.pet_length),
		math.random(attached_to_wininfo.height - 1 - conf.min_skip_below)

	return x, y
end

local function choose_next_spot(conf, pet, moving, attached_to_win)
	local config = vim.api.nvim_win_get_config(pet)
	local attached_to_wininfo = vim.fn.getwininfo(attached_to_win)[1]
	local x, y = config["col"], config["row"]
	if x == nil or y == nil then
		return config, false
	end

	local lengths = {}
	for row = attached_to_wininfo.winrow, attached_to_wininfo.winrow + attached_to_wininfo.height - 1 do
		local length = attached_to_wininfo.textoff
		for c = attached_to_wininfo.wincol + attached_to_wininfo.width - conf.pet_length, attached_to_wininfo.wincol + attached_to_wininfo.textoff, -1 do
			if vim.fn.screenchar(row, c) ~= 32 and not (c < x + conf.pet_length and c > x) then
				length = c - attached_to_wininfo.wincol
				break
			end
		end
		lengths[row - attached_to_wininfo.winrow] = length + conf.pet_length
	end

	local win_rowend = attached_to_wininfo.height - 1 - conf.min_skip_below
	local win_rowstart = conf.min_skip_above
	local win_colend = attached_to_wininfo.width - conf.pet_length - conf.min_skip_right
	local win_colstart = conf.min_skip_left

	local direction = math.random(4)
	local tries = 0
	while true do
		local next_direction = direction
		if moving then
			if math.random(100) <= 10 then
				next_direction = direction + (math.random(2) - 1) * 2 - 1
			end
			if next_direction == 1 then
				x = x - 1
			elseif next_direction == 2 then
				y = y - 1
			elseif next_direction == 3 then
				x = x + 1
			elseif next_direction == 4 then
				y = y + 1
			end
		end
		if y < win_rowstart then
			y = win_rowend
		elseif y >= win_rowend then
			y = win_rowstart
		end
		if x < win_colstart then
			x = win_colend
		elseif x >= win_colend then
			x = win_colstart
		end
		if lengths[y] ~= nil and lengths[y] < x then
			break
		end
		if not moving then
			x, y = choose_new_spot(conf, attached_to_win)
			local result = choose_next_spot(conf, pet, true, attached_to_win)
			if not result[0] then
				return config, false
			end
			break
		end
		tries = tries + 1
		if tries > 15 then
			return config, false
		end
	end

	config["col"] = x
	config["row"] = y

	return config, true
end

M.add_pet = function(conf, attached_to_party)
	n_pets = n_pets + 1
	if not conf then
		conf = {}
	end
	if not conf.step_period then
		conf.step_period = 150
	end
	if not conf.wait_pediod then
		conf.wait_pediod = 1000
	end
	if not conf.pet_string then
		conf.pet_string = "🐧"
	end
	conf.pet_length = string.len(conf.pet_string)
	if not conf.repeats then
		conf.repeats = 100
	end
	if not conf.min_skip_above then
		conf.min_skip_above = 0
	end
	if not conf.min_skip_below then
		conf.min_skip_below = 0
	end
	if not conf.min_skip_right then
		conf.min_skip_right = 0
	end
	if not conf.min_skip_left then
		conf.min_skip_left = 0
	end
    if not conf.switch_movement_probability then
        conf.switch_movement_probability = 3
    end

	local attached_to_win = vim.api.nvim_get_current_win()

	local buf = vim.api.nvim_create_buf(false, true)
	local x, y = choose_new_spot(conf, attached_to_win)
	local pet = vim.api.nvim_open_win(buf, false, {
		relative = "win",
		style = "minimal",
		row = y,
		col = x,
		width = 2,
		height = 1,
	})
	local config, no_err = choose_next_spot(conf, pet, true, attached_to_win)
	if not no_err then
		vim.api.nvim_buf_delete(buf, { force = true })
		n_pets = n_pets - 1
		return
	end
	vim.api.nvim_win_set_config(pet, config)
	vim.api.nvim_buf_set_lines(buf, 0, 1, true, { conf.pet_string })

	local timer = vim.uv.new_timer()
	local i = 1

	local moving = true

	timer:start(
		conf.wait_pediod,
		conf.step_period,
		vim.schedule_wrap(function()
			if not vim.api.nvim_win_is_valid(pet) or not vim.api.nvim_win_is_valid(attached_to_win) then
				if timer:is_closing() then
					return
				end
				timer:close()
				vim.api.nvim_buf_delete(buf, { force = true })
				n_pets = n_pets - 1
				return
			end
			if math.random(100) <= conf.switch_movement_probability then
				moving = not moving
			end
			config, no_err = choose_next_spot(conf, pet, moving, attached_to_win)
			if not no_err then
				if timer:is_closing() then
					return
				end
				timer:close()
				vim.api.nvim_buf_delete(buf, { force = true })
				n_pets = n_pets - 1
				return
			end
			vim.api.nvim_win_set_config(pet, config)
			if i == conf.repeats or attached_to_party and not do_party then
				timer:close()
				vim.api.nvim_buf_delete(buf, { force = true })
				n_pets = n_pets - 1
			end
			i = i + 1
		end)
	)
end

M.start_pet_party = function(conf)
	if not conf then
		conf = {}
	end
	if not conf.max_pets then
		conf.max_pets = 4
	end
	if not conf.spawn_period then
		conf.spawn_period = 2000
	end
	local spawner = vim.uv.new_timer()
	if do_party then
		vim.notify("Penguin party is already happening! Can't start another one.", vim.log.levels.WARN)
		return
	end
	do_party = true
	spawner:start(
		500,
		conf.spawn_period,
		vim.schedule_wrap(function()
			if n_pets < conf.max_pets then
				M.add_pet(conf, true)
			end
			if not do_party then
				spawner:close()
			end
		end)
	)
end

M.stop_pet_party = function()
	do_party = false
end

return M
