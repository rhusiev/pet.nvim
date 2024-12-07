local M = {}
local conf = { n_skip_above = 1, n_skip_below = 3, n_skip_right = 2, n_skip_left = 0, radius_around_cursor = 3 }
local n_pets = 0
local do_party = false

M._choose_new_spot = function(pet_length)
	local y = math.random(vim.o.lines - conf.n_skip_above - conf.n_skip_below) + conf.n_skip_above
	local x = math.random(vim.o.columns - pet_length)

	return x, y
end

M._choose_next_spot = function(config, moving)
	local x, y = config["col"], config["row"]
    if moving then
        local direction = math.random(4)

        if direction == 1 then
            x = x - 1
        elseif direction == 2 then
            y = y - 1
        elseif direction == 3 then
            x = x + 1
        elseif direction == 4 then
            y = y + 1
        end
    end

	-- local cursor_y = vim.api.nvim_win_get_cursor(0)[1]
    -- vim.notify(vim.inspect(vim.api.nvim_win_get_position(vim.api.nvim_get_current_win())))
	-- if conf.radius_around_cursor then
	-- 	for i = 0, conf.radius_around_cursor do
	-- 		if y == cursor_y + conf.n_skip_above - i then
	-- 			if direction == 1 or direction == 2 then
	-- 				y = y - 1
	-- 			elseif direction == 3 or direction == 4 then
	-- 				y = y + 2 * i + 1
	-- 			end
	-- 		end
	-- 		if y == cursor_y + conf.n_skip_above + i then
	-- 			if direction == 1 or direction == 2 then
	-- 				y = y - 2 * i - 1
	-- 			elseif direction == 3 or direction == 4 then
	-- 				y = y + 1
	-- 			end
	-- 		end
	-- 	end
	-- end

	if x < conf.n_skip_left then
		x = vim.o.columns - conf.n_skip_right
	elseif x > vim.o.columns - conf.n_skip_right then
		x = conf.n_skip_left
	end

	if y < conf.n_skip_above then
		y = vim.o.lines - conf.n_skip_below
	elseif y > vim.o.lines - conf.n_skip_below then
		y = conf.n_skip_above
	end

	config["col"] = x
	config["row"] = y

	return x, y
end

M.add_pet = function(step_period, wait_pediod, pet_string, repeats, attached_to_party)
    n_pets = n_pets + 1
	if not step_period then
		step_period = 150
	end
	if not wait_pediod then
		wait_pediod = 1000
	end
	if not pet_string then
		pet_string = "🐧"
	end
    if not repeats then
        repeats = 100
    end
	local pet_length = #pet_string

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, 1, true, { pet_string })
	local x, y = M._choose_new_spot(pet_length)
	local pet = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		style = "minimal",
		row = y,
		col = x,
		width = 2,
		height = 1,
	})

	local timer = vim.uv.new_timer()
	local i = 1

    local moving = true

	timer:start(
		wait_pediod,
		step_period,
		vim.schedule_wrap(function()
			local config = vim.api.nvim_win_get_config(pet)
            if math.random(100) <= 5 then
                moving = not moving
            end
			M._choose_next_spot(config, moving)
			vim.api.nvim_win_set_config(pet, config)
			if i == repeats or attached_to_party and not do_party then
				timer:close()
				vim.api.nvim_buf_delete(buf, { force = true })
                n_pets = n_pets - 1
			end
			i = i + 1
		end)
	)
end

M.start_pet_party = function(max_pets, spawn_period, step_period, wait_pediod, pet_string, repeats)
    if not max_pets then
        max_pets = 4
    end
    if not spawn_period then
        spawn_period = 2000
    end
    local spawner = vim.uv.new_timer()
    if do_party then
        vim.notify("Penguin party is already happening! Can't start another one.", vim.log.levels.WARN)
        return
    end
    do_party = true
    spawner:start(500, spawn_period, vim.schedule_wrap(function()
        if n_pets < max_pets then
            M.add_pet(step_period, wait_pediod, pet_string, repeats, true)
        end
        if not do_party then
            spawner:close()
        end
    end))
end

M.stop_pet_party = function()
    do_party = false
end

return M
