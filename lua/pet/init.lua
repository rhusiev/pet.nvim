local M = {}
local active_pets = {}
local do_party = false

require("pet.types")
local utils = require("pet.utils")
local defaults = require("pet.defaults")

local cache_group = vim.api.nvim_create_augroup("PetPluginCache", { clear = true })
local base_areas_cache = {}

local function invalidate_cache()
	base_areas_cache = {}
end

vim.api.nvim_create_autocmd({
	"WinScrolled",
	"WinResized",
	"VimResized",
	"TextChanged",
	"TextChangedI",
	"BufWinEnter",
	"TabEnter",
	"TabLeave",
	"CursorMoved",
	"CursorMovedI",
}, {
	group = cache_group,
	callback = invalidate_cache,
})

local function get_config_hash(config)
	return string.format(
		"%s_%s_%s_%s_%s_%s",
		tostring(config.avoid_text),
		config.min_skip_above,
		config.min_skip_below,
		config.min_skip_left,
		config.min_skip_right,
		config.pet_length
	)
end

local function get_base_areas(config)
	local hash = get_config_hash(config)
	if base_areas_cache[hash] then
		return base_areas_cache[hash]
	end

	local areas = {}
	for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local win_conf = vim.api.nvim_win_get_config(win_id)
		if win_conf.relative == "" then
			local wininfos = vim.fn.getwininfo(win_id)
			if wininfos and #wininfos > 0 then
				local wininfo = wininfos[1]
				local win_rowstart = wininfo.winrow + config.min_skip_above
				local win_rowend = wininfo.winrow + wininfo.height - 1 - config.min_skip_below
				local win_colstart = wininfo.wincol + wininfo.textoff + config.min_skip_left
				local win_colend = wininfo.wincol + wininfo.width - 1 - config.min_skip_right

				for row = win_rowstart, win_rowend do
					local length = wininfo.wincol + wininfo.textoff - 1
					if config.avoid_text then
						for c = win_colend, wininfo.wincol + wininfo.textoff, -1 do
							if vim.fn.screenchar(row, c) ~= 32 then
								length = c
								if config.debug_marks then
									utils.draw_mark(c, row, "#", config.step_period / 1.05)
								end
								break
							elseif config.debug_marks and c <= wininfo.wincol + wininfo.textoff then
								utils.draw_mark(c, row, "@", config.step_period / 1.1)
							end
						end
					end

					local min_c = math.max(length + 1, win_colstart)
					-- Bake the pet's length into the segment bounds
					local max_c = win_colend - config.pet_length + 1

					if min_c <= max_c then
						if not areas[row] then
							areas[row] = {}
						end
						table.insert(areas[row], {
							min_x = min_c - 1,
							max_x = max_c - 1,
						})
					end
				end
			end
		end
	end
	base_areas_cache[hash] = areas
	return areas
end

local function is_available(x, y, areas, current_pet)
	local intervals = areas[y + 1]
	if not intervals then
		return false
	end

	local inside_base = false
	for _, interval in ipairs(intervals) do
		if x >= interval.min_x and x <= interval.max_x then
			inside_base = true
			break
		end
	end
	if not inside_base then
		return false
	end

	local my_len = current_pet.config.pet_length
	for win_id, other_pet in pairs(active_pets) do
		if win_id ~= current_pet.win and other_pet.global_x and other_pet.global_y then
			if y == other_pet.global_y then
				local other_len = other_pet.config.pet_length
				if x < (other_pet.global_x + other_len) and other_pet.global_x < (x + my_len) then
					return false
				end
			end
		end
	end

	return true
end

---Choose a new random spot for a pet
---@param self Pet
---@param areas table?
---@return number?, number?
local function choose_new_spot(self, areas)
	if not areas then
		areas = get_base_areas(self.config)
	end
	local valid_spots = {}
	for row, intervals in pairs(areas) do
		for _, interval in ipairs(intervals) do
			for col = interval.min_x, interval.max_x do
				if is_available(col, row - 1, areas, self) then
					table.insert(valid_spots, { x = col, y = row - 1 })
				end
			end
		end
	end
	if #valid_spots == 0 then
		return nil, nil
	end
	local spot = valid_spots[math.random(#valid_spots)]
	return spot.x, spot.y
end

---Choose, where to move for a pet
---@param self Pet
---@param areas table?
---@param all_pets table
---@return vim.api.keyset.win_config, boolean
local function choose_next_spot(self, areas, all_pets)
	local config = vim.api.nvim_win_get_config(self.win)
	local x, y = config["col"], config["row"]
	if x == nil or y == nil then
		return config, false
	end

	if areas == nil then
		areas = get_base_areas(self.config)
	end

	if self.config.debug_marks then
		utils.draw_mark(x + 1, y + 1, "$", self.config.step_period / 2)
	end

	local editor_width = vim.o.columns
	local editor_height = vim.o.lines

	local tries = 0
	while true do
		x, y = self.move(self, x, y, all_pets)

		if y < 0 then
			y = editor_height - 1
		elseif y >= editor_height then
			y = 0
		end

		if x < 0 then
			x = editor_width - 1
		elseif x >= editor_width then
			x = 0
		end

		if is_available(x, y, areas, self) then
			break
		end

		tries = tries + 1
		if tries > 1000 then
			return config, false
		end
	end

	if self.config.debug_marks then
		utils.draw_mark(x + 1, y + 1, "$", self.config.step_period / 1.5)
	end

	config["col"] = x
	config["row"] = y
	return config, true
end

M.add_pet = function(conf, attached_to_party)
	conf = conf or {}
	conf.step_period = conf.step_period or defaults.step_period
	conf.wait_period = conf.wait_period or defaults.wait_period
	conf.pet_string = conf.pet_string or defaults.pet_string
	conf.pet_length = conf.pet_length or defaults.pet_length(conf.pet_string)
	conf.repeats = conf.repeats or defaults.repeats
	conf.min_skip_above = conf.min_skip_above or defaults.min_skip_above
	conf.min_skip_below = conf.min_skip_below or defaults.min_skip_below
	conf.min_skip_right = conf.min_skip_right or defaults.min_skip_right
	conf.min_skip_left = conf.min_skip_left or defaults.min_skip_left
	conf.debug_marks = conf.debug_marks or defaults.debug_marks
	conf.avoid_text = conf.avoid_text or defaults.avoid_text
	conf.moving_function = conf.moving_function or defaults.moving_function
	conf.moving_opts = conf.moving_opts or defaults.moving_opts

	local buf = vim.api.nvim_create_buf(false, true)
	local pet = {
		win = nil,
		config = conf,
		state = nil,
		move = conf.moving_function,
		global_x = nil,
		global_y = nil,
	}

	local areas = get_base_areas(conf)
	local x, y = choose_new_spot(pet, areas)
	if not x then
		vim.api.nvim_buf_delete(buf, { force = true })
		return
	end

	pet.global_x = x
	pet.global_y = y

	pet.win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		style = "minimal",
		row = y,
		col = x,
		width = 2,
		height = 1,
	})

	local config = vim.api.nvim_win_get_config(pet.win)
	vim.api.nvim_buf_set_lines(buf, 0, 1, true, { conf.pet_string })

	active_pets[pet.win] = pet

	local timer = vim.uv.new_timer()
	local i = 1

	local function remove_pet()
		active_pets[pet.win] = nil
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end

	timer:start(
		conf.wait_period,
		conf.step_period,
		vim.schedule_wrap(function()
			if not vim.api.nvim_win_is_valid(pet.win) then
				if timer:is_closing() then
					return
				end
				timer:close()
				remove_pet()
				return
			end
			local no_err
			config, no_err = choose_next_spot(pet, nil, active_pets)
			if not no_err then
				if timer:is_closing() then
					return
				end
				timer:close()
				remove_pet()
				return
			end
			vim.api.nvim_win_set_config(pet.win, config)

			pet.global_x = config.col
			pet.global_y = config.row

			if i == conf.repeats or attached_to_party and not do_party then
				timer:close()
				remove_pet()
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
		conf.max_pets = defaults.max_pets
	end
	if not conf.spawn_period then
		conf.spawn_period = defaults.spawn_period
	end
	if do_party then
		vim.notify("Penguin party is already happening! Can't start another one.", vim.log.levels.WARN)
		return
	end
	local spawner = vim.uv.new_timer()
	do_party = true
	spawner:start(
		500,
		conf.spawn_period,
		vim.schedule_wrap(function()
			if vim.tbl_count(active_pets) < conf.max_pets then
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

M.pets = active_pets

return M
