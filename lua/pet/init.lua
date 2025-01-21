local M = {}
local n_pets = 0
local do_party = false

require("pet.types")

---Choose a new random spot for a pet
---@param conf table
---@param attached_to_win integer
---@return number, number
local function choose_new_spot(conf, attached_to_win)
	local attached_to_wininfo = vim.fn.getwininfo(attached_to_win)[1]
	local x, y =
		math.random(attached_to_wininfo.wincol + attached_to_wininfo.width - conf.pet_length),
		math.random(attached_to_wininfo.height - 1 - conf.min_skip_below)

	return x, y
end

---Convert x relative to a window to absolute (relative to the whole editor)
---@param x number
---@param attached_to_wininfo Wininfo
---@return number
local function to_absolute_x(x, attached_to_wininfo)
	return x + attached_to_wininfo.wincol
end

---Convert x absolute (relative to the whole editor) to relative to a window
---@param x number
---@param attached_to_wininfo Wininfo
---@return number
local function to_relative_x(x, attached_to_wininfo)
	return x - attached_to_wininfo.wincol
end

---Convert y relative to a window to absolute (relative to the whole editor)
---@param y number
---@param attached_to_wininfo Wininfo
---@return number
local function to_absolute_y(y, attached_to_wininfo)
	return y + attached_to_wininfo.winrow
end

---Convert y absolute (relative to the whole editor) to relative to a window
---@param y number
---@param attached_to_wininfo Wininfo
---@return number
local function to_relative_y(y, attached_to_wininfo)
	return y - attached_to_wininfo.winrow
end

---Convert x and y relative to a window to absolute (relative to the whole editor)
---@param x number
---@param y number
---@param attached_to_wininfo Wininfo
---@return number, number
local function to_absolute(x, y, attached_to_wininfo)
	return to_absolute_x(x, attached_to_wininfo), to_absolute_y(y, attached_to_wininfo)
end

---Convert x and y absolute (relative to the whole editor) to relative to a window
---@param x number
---@param y number
---@param attached_to_wininfo Wininfo
---@return number, number
local function to_relative(x, y, attached_to_wininfo)
	return to_relative_x(x, attached_to_wininfo), to_relative_y(y, attached_to_wininfo)
end

---Draw a character at x,y position
---@param x number
---@param y number
---@param char string
---@param time number the period of time to keep the mark shown
---@param attached_to_wininfo Wininfo? the window, relative to which
-- draw the mark. If nil, the mark is drawn relative to the whole editor
local function draw_mark(x, y, char, time, attached_to_wininfo)
	local abs_x, abs_y = x, y
	if attached_to_wininfo ~= nil then
		abs_x, abs_y = to_absolute(x, y, attached_to_wininfo)
	end
	local buf = vim.api.nvim_create_buf(false, true)
	local new_win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		style = "minimal",
		row = abs_y - 1,
		col = abs_x - 1,
		width = 1,
		height = 1,
	})
	vim.api.nvim_buf_set_lines(buf, 0, 1, true, { char })
	local timer = vim.uv.new_timer()
	timer:start(
		time,
		0,
		vim.schedule_wrap(function()
			vim.api.nvim_win_close(new_win, true)
			timer:close()
		end)
	)
end

---Choose, where to move for a pet
---@param conf PetConfig
---@param pet Pet
---@param moving boolean
---@param attached_to_win integer
---@return vim.api.keyset.win_config, boolean
local function choose_next_spot(conf, pet, moving, attached_to_win)
	local config = vim.api.nvim_win_get_config(pet)
	local attached_to_wininfo = vim.fn.getwininfo(attached_to_win)[1]
	local x, y = config["col"], config["row"]
	if x == nil or y == nil then
		return config, false
	end
	local abs_x, abs_y = to_absolute(x, y, attached_to_wininfo)

	local lengths = {}
	if conf.debug_marks then
		draw_mark(x, y, "$", conf.step_period / 2, attached_to_wininfo)
	end
	for row = attached_to_wininfo.winrow, attached_to_wininfo.winrow + attached_to_wininfo.height - 1 do
		local length = attached_to_wininfo.textoff
		for c = attached_to_wininfo.wincol + attached_to_wininfo.width - conf.pet_length, attached_to_wininfo.wincol + attached_to_wininfo.textoff, -1 do
			if
				vim.fn.screenchar(row, c) ~= 32 and not (c < abs_x + conf.pet_length and c >= abs_x and row == abs_y)
			then
				length = c
				if conf.debug_marks then
					draw_mark(c, row, "#", conf.step_period / 1.05)
				end
				break
			elseif conf.debug_marks and c <= attached_to_wininfo.textoff then
				draw_mark(c, row, "@", conf.step_period / 1.1)
			elseif c <= 5 then
				vim.print(attached_to_wininfo.textoff)
			end
		end
		local rel_c, rel_row = to_relative(length, row, attached_to_wininfo)
		lengths[rel_row] = rel_c
	end

	local win_rowend = attached_to_wininfo.height - 1 - conf.min_skip_below
	local win_rowstart = conf.min_skip_above
	local win_colend = attached_to_wininfo.width - conf.pet_length - conf.min_skip_right
	local win_colstart = conf.min_skip_left
	if attached_to_wininfo.textoff > win_colstart then
		win_colstart = attached_to_wininfo.textoff
	end

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
		if tries > 30 then
			return config, false
		end
		if conf.debug_marks then
			draw_mark(lengths[y], y, "#", conf.step_period / 1.05, attached_to_wininfo)
			draw_mark(x, y, "$", conf.step_period / 1.5, attached_to_wininfo)
		end
	end

	config["col"] = x
	config["row"] = y

	return config, true
end

---Add a moving pet
---@param conf PetConfig?
---@param attached_to_party boolean Whether the pet should be attached to a party. If it's not, it will not disappear with the end of the party.
M.add_pet = function(conf, attached_to_party)
	n_pets = n_pets + 1
	if conf == nil then
		conf = {}
	end
	if not conf.step_period then
		conf.step_period = 150
	end
	if not conf.wait_period then
		conf.wait_period = 1000
	end
	if not conf.pet_string then
		conf.pet_string = "🐧"
	end
	if not conf.pet_length then
		conf.pet_length = string.len(conf.pet_string)
	end
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
	if not conf.stop_moving_probability then
		conf.stop_moving_probability = 3
	end
	if not conf.start_moving_probability then
		conf.start_moving_probability = 10
	end
	if not conf.debug_marks then
		conf.debug_marks = false
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
		conf.wait_period,
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
			if moving and math.random(100) <= conf.stop_moving_probability then
				moving = false
			elseif not moving and math.random(100) <= conf.start_moving_probability then
				moving = true
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

---Start a party
-- Start spawning pets with an interval, keeping them in the limit
-- of `max_pets`.
---@param conf PartyConfig?
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

---Stop a party
M.stop_pet_party = function()
	do_party = false
end

return M
