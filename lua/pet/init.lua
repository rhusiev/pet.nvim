local M = {}
local n_pets = 0
local do_party = false

require("pet.types")
local utils = require("pet.utils")
local defaults = require("pet.defaults")

---@class Pet
---@field win integer
---@field attached_to_win integer
---@field config PetConfig
---@field state any
---
---@field move fun(pet: Pet, x: number, y: number): number, number

---Choose a new random spot for a pet
---@param self Pet
---@return number, number
local function choose_new_spot(self)
    local attached_to_wininfo = vim.fn.getwininfo(self.attached_to_win)[1]
    local x, y =
        math.random(attached_to_wininfo.wincol + attached_to_wininfo.width - self.config.pet_length),
        math.random(attached_to_wininfo.height - 1 - self.config.min_skip_below)

    return x, y
end

---Choose, where to move for a pet
---@param self Pet
---@param lengths {[number]: number}?
---@return vim.api.keyset.win_config, boolean
local function choose_next_spot(self, lengths)
    local config = vim.api.nvim_win_get_config(self.win)
    local attached_to_wininfo = vim.fn.getwininfo(self.attached_to_win)[1]
    local x, y = config["col"], config["row"]
    if x == nil or y == nil then
        return config, false
    end
    local abs_x, abs_y = utils.to_absolute(x, y, attached_to_wininfo)

    if lengths ~= nil then
        goto end_lengths
    end
    lengths = {}
    if self.config.debug_marks then
        utils.draw_mark(x, y, "$", self.config.step_period / 2, attached_to_wininfo)
    end
    for row = attached_to_wininfo.winrow, attached_to_wininfo.winrow + attached_to_wininfo.height - 1 do
        local length = attached_to_wininfo.textoff
        if self.config.avoid_text then
            for c = attached_to_wininfo.wincol + attached_to_wininfo.width - self.config.pet_length, attached_to_wininfo.wincol + attached_to_wininfo.textoff, -1 do
                if
                    vim.fn.screenchar(row, c) ~= 32
                    and not (c < abs_x + self.config.pet_length and c >= abs_x and row == abs_y)
                then
                    length = c
                    if self.config.debug_marks then
                        utils.draw_mark(c, row, "#", self.config.step_period / 1.05)
                    end
                    break
                elseif self.config.debug_marks and c <= attached_to_wininfo.textoff then
                    utils.draw_mark(c, row, "@", self.config.step_period / 1.1)
                elseif c <= 5 then
                    vim.print(attached_to_wininfo.textoff)
                end
            end
        end
        local rel_c, rel_row = utils.to_relative(length, row, attached_to_wininfo)
        lengths[rel_row] = rel_c
    end
    ::end_lengths::

    local win_rowend = attached_to_wininfo.height - 1 - self.config.min_skip_below
    local win_rowstart = self.config.min_skip_above
    local win_colend = attached_to_wininfo.width - self.config.pet_length - self.config.min_skip_right
    local win_colstart = self.config.min_skip_left
    if attached_to_wininfo.textoff > win_colstart then
        win_colstart = attached_to_wininfo.textoff
    end

    local tries = 0
    while true do
        x, y = self.move(self, x, y)
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
        tries = tries + 1
        if tries > 30 then
            x, y = choose_new_spot(self)
            return config, false
        end
        if self.config.debug_marks then
            utils.draw_mark(lengths[y], y, "#", self.config.step_period / 1.05, attached_to_wininfo)
            utils.draw_mark(x, y, "$", self.config.step_period / 1.5, attached_to_wininfo)
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

    local attached_to_win = vim.api.nvim_get_current_win()

    local buf = vim.api.nvim_create_buf(false, true)
    local pet = {
        win = nil,
        attached_to_win = attached_to_win,
        config = conf,
        state = nil,
        move = conf.moving_function,
    }
    local x, y = choose_new_spot(pet)
    pet.win = vim.api.nvim_open_win(buf, false, {
        relative = "win",
        style = "minimal",
        row = y,
        col = x,
        width = 2,
        height = 1,
    })
    local config, no_err = choose_next_spot(pet)
    if not no_err then
        vim.api.nvim_buf_delete(buf, { force = true })
        n_pets = n_pets - 1
        return
    end
    vim.api.nvim_win_set_config(pet.win, config)
    vim.api.nvim_buf_set_lines(buf, 0, 1, true, { conf.pet_string })

    local timer = vim.uv.new_timer()
    local i = 1

    timer:start(
        conf.wait_period,
        conf.step_period,
        vim.schedule_wrap(function()
            if not vim.api.nvim_win_is_valid(pet.win) or not vim.api.nvim_win_is_valid(attached_to_win) then
                if timer:is_closing() then
                    return
                end
                timer:close()
                vim.api.nvim_buf_delete(buf, { force = true })
                n_pets = n_pets - 1
                return
            end
            config, no_err = choose_next_spot(pet)
            if not no_err then
                if timer:is_closing() then
                    return
                end
                timer:close()
                vim.api.nvim_buf_delete(buf, { force = true })
                n_pets = n_pets - 1
                return
            end
            vim.api.nvim_win_set_config(pet.win, config)
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
        conf.max_pets = defaults.max_pets
    end
    if not conf.spawn_period then
        conf.spawn_period = defaults.spawn_period
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
