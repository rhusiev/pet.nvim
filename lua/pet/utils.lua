local M = {}

---Convert x relative to a window to absolute (relative to the whole editor)
---@param x number
---@param attached_to_wininfo Wininfo
---@return number
M.to_absolute_x = function(x, attached_to_wininfo)
	return x + attached_to_wininfo.wincol
end

---Convert x absolute (relative to the whole editor) to relative to a window
---@param x number
---@param attached_to_wininfo Wininfo
---@return number
M.to_relative_x = function(x, attached_to_wininfo)
	return x - attached_to_wininfo.wincol
end

---Convert y relative to a window to absolute (relative to the whole editor)
---@param y number
---@param attached_to_wininfo Wininfo
---@return number
M.to_absolute_y = function(y, attached_to_wininfo)
	return y + attached_to_wininfo.winrow
end

---Convert y absolute (relative to the whole editor) to relative to a window
---@param y number
---@param attached_to_wininfo Wininfo
---@return number
M.to_relative_y = function(y, attached_to_wininfo)
	return y - attached_to_wininfo.winrow
end

---Convert x and y relative to a window to absolute (relative to the whole editor)
---@param x number
---@param y number
---@param attached_to_wininfo Wininfo
---@return number, number
M.to_absolute = function(x, y, attached_to_wininfo)
	return M.to_absolute_x(x, attached_to_wininfo), M.to_absolute_y(y, attached_to_wininfo)
end

---Convert x and y absolute (relative to the whole editor) to relative to a window
---@param x number
---@param y number
---@param attached_to_wininfo Wininfo
---@return number, number
M.to_relative = function(x, y, attached_to_wininfo)
	return M.to_relative_x(x, attached_to_wininfo), M.to_relative_y(y, attached_to_wininfo)
end

---Draw a character at x,y position
---@param x number
---@param y number
---@param char string
---@param time number the period of time to keep the mark shown
---@param attached_to_wininfo Wininfo? the window, relative to which
-- draw the mark. If nil, the mark is drawn relative to the whole editor
M.draw_mark = function(x, y, char, time, attached_to_wininfo)
	local abs_x, abs_y = x, y
	if attached_to_wininfo ~= nil then
		abs_x, abs_y = M.to_absolute(x, y, attached_to_wininfo)
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

return M
