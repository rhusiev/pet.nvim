local M = {}

M.max_pets = 4

M.spawn_period = 2000
M.step_period = 150
M.wait_period = 1000

M.pet_string = "🐧"
M.pet_length = function(pet_string)
	return string.len(pet_string)
end

M.repeats = 100

M.min_skip_above = 0
M.min_skip_below = 0
M.min_skip_right = 0
M.min_skip_left = 0

M.debug_marks = false

M.avoid_text = true

M.moving_opts = {
	stop_moving_probability = 5,
	start_moving_probability = 13,
}

---Choose the next spot for a pet
---@param pet Pet
---@param x number
---@param y number
---@param all_pets {[integer]: Pet}
---@return number, number
M.moving_function = function(pet, x, y, all_pets)
	if pet.state == nil then
		pet.state = {
			moving = true,
			direction = math.random(4),
		}
	end
	if math.random(100) <= 30 then
		pet.state.direction = pet.state.direction + (math.random(2) - 1) * 2 - 1
		if pet.state.direction < 1 then
			pet.state.direction = 4
		elseif pet.state.direction > 4 then
			pet.state.direction = 1
		end
	end
	if (not pet.state.moving) and math.random(100) <= pet.config.moving_opts.start_moving_probability then
		pet.state.moving = true
	end
	if pet.state.moving and math.random(100) <= pet.config.moving_opts.stop_moving_probability then
		pet.state.moving = false
	end
	if not pet.state.moving then
		return x, y
	end
	if pet.state.direction == 1 then
		x = x - 1
	elseif pet.state.direction == 2 then
		y = y - 1
	elseif pet.state.direction == 3 then
		x = x + 1
	elseif pet.state.direction == 4 then
		y = y + 1
	end
	return x, y
end

local function shortest_toroidal_vector(val_1, val_2, max_val)
	local d = val_2 - val_1
	local half = max_val / 2
	if math.abs(d) > half then
		d = d > 0 and (d - max_val) or (d + max_val)
	end
	return d
end

local function all_neighbors(pet, all_pets)
	local neighbors = {}
	for _, other_pet in pairs(all_pets) do
		if other_pet ~= pet then
			if vim.api.nvim_win_is_valid(other_pet.win) then
				local cfg = vim.api.nvim_win_get_config(other_pet.win)
				if cfg and type(cfg.col) == "number" and type(cfg.row) == "number" then
					table.insert(neighbors, {
						x = cfg.col,
						y = cfg.row,
						velocity = other_pet.state and other_pet.state.velocity,
					})
				end
			end
		end
	end
	return neighbors
end

---@param pet Pet
---@param x number
---@param y number
---@param all_pets {[integer]: Pet}
---@return number, number
M.flocking_function = function(pet, x, y, all_pets)
	if pet.state == nil or pet.state.velocity == nil then
		local angle = math.random() * math.pi * 2
		pet.state = { velocity = { x = math.cos(angle), y = math.sin(angle) } }
	end

	local opts = pet.config.moving_opts or {}
	local separation_radius = opts.separation_radius or 5
	local alignment_radius = opts.alignment_radius or 7
	local separation_weight = opts.separation_weight or 7.5
	local cohesion_weight = opts.cohesion_weight or 0.05
	local alignment_weight = opts.alignment_weight or 1.2
	local noise = opts.noise or 0.2
	local max_speed = opts.max_speed or 2.0
	local drag = opts.drag or 0.75

	local y_ratio = 2.0

	local win_width = vim.o.columns
	local win_height = vim.o.lines

	local neighbors = all_neighbors(pet, all_pets)
	local sep_x, sep_y = 0, 0
	local coh_x, coh_y = 0, 0
	local ali_x, ali_y = 0, 0
	local cohesion_count = 0
	local alignment_count = 0

	for _, neighbor in ipairs(neighbors) do
		local dx = shortest_toroidal_vector(x, neighbor.x, win_width)
		local dy = shortest_toroidal_vector(y, neighbor.y, win_height)

		local visual_dy = dy * y_ratio
		local dist = math.sqrt(dx * dx + visual_dy * visual_dy)

		if dist > 0.01 then
			cohesion_count = cohesion_count + 1
			coh_x = coh_x + dx
			coh_y = coh_y + dy

			if dist < separation_radius then
				sep_x = sep_x - (dx / dist)
				sep_y = sep_y - (dy / dist)
			end

			if dist < alignment_radius and neighbor.velocity then
				local v_mag = math.sqrt(neighbor.velocity.x ^ 2 + neighbor.velocity.y ^ 2)
				if v_mag > 0.01 then
					alignment_count = alignment_count + 1
					ali_x = ali_x + (neighbor.velocity.x / v_mag)
					ali_y = ali_y + (neighbor.velocity.y / v_mag)
				end
			end
		end
	end

	local vx = pet.state.velocity.x * drag
	local vy = pet.state.velocity.y * drag

	vx = vx + sep_x * separation_weight
	vy = vy + sep_y * separation_weight

	if cohesion_count > 0 then
		vx = vx + (coh_x / cohesion_count) * cohesion_weight
		vy = vy + (coh_y / cohesion_count) * cohesion_weight
	end

	if alignment_count > 0 then
		vx = vx + (ali_x / alignment_count) * alignment_weight
		vy = vy + (ali_y / alignment_count) * alignment_weight
	end

	vx = vx + (math.random() - 0.5) * noise
	vy = vy + (math.random() - 0.5) * noise

	local speed = math.sqrt(vx * vx + vy * vy)
	if speed > max_speed then
		vx = (vx / speed) * max_speed
		vy = (vy / speed) * max_speed
	elseif speed < 0.2 then
		local angle = math.random() * math.pi * 2
		vx = math.cos(angle) * 0.5
		vy = math.sin(angle) * 0.5
	end

	pet.state.velocity = { x = vx, y = vy }

	local abs_vx = math.abs(vx)
	local abs_vy = math.abs(vy)
	local total = abs_vx + abs_vy

	if total < 0.01 then
		return x, y
	end

	local next_x, next_y = x, y
	if math.random() < (abs_vx / total) then
		next_x = x + (vx > 0 and 1 or -1)
	else
		next_y = y + (vy > 0 and 1 or -1)
	end

	return next_x, next_y
end

return M
