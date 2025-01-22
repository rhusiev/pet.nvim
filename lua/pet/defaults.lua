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

---Choose the next spot for a pet
---@param pet Pet
---@param x number
---@param y number
---@return number, number
M.moving_function = function(pet, x, y)
    if pet.state == nil then
        pet.state = {
            moving = true,
            direction = math.random(4),
        }
    end
    if math.random(100) <= 30 then
        pet.state.direction = pet.state.direction + (math.random(2) - 1) * 2 - 1
    end
    if (not pet.state.moving) and math.random(100) <= 20 then
        pet.state.moving = true
    end
    if pet.state.moving and math.random(100) <= 2 then
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

return M
