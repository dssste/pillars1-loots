local function split_lines(line)
	local result = {}
	for str in string.gmatch(line, "([^\r\n]*)\r?\n?") do
		if str ~= "" then
			table.insert(result, str)
		end
	end
	return result
end

local function prepare_messages(messages)
	if type(messages) == "string" then
		messages = { messages }
	end

	local result = {}
	for _, line in pairs(messages) do
		for _, part in pairs(split_lines(line)) do
			table.insert(result, part)
		end
	end
	return result
end

local function popup(data)
	local message = prepare_messages(vim.inspect(data))

	local margin = 6

	local opts = {
		anchor = "SE",
		relative = "editor",
		width = vim.api.nvim_get_option_value("columns", {}) - margin * 4,
		height = vim.api.nvim_get_option_value("lines", {}) - margin * 2 - 2,
		row = vim.api.nvim_get_option_value("lines", {}) - margin,
		col = vim.api.nvim_get_option_value("columns", {}) - margin * 2,
		border = "rounded",
	}

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("filetype", "json", {
		buf = buf,
	})
	vim.api.nvim_buf_set_name(buf, "poe1lt://" .. buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, message)
	vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
		callback = function()
			vim.cmd('bdelete! ' .. buf)
		end
	})

	local win = vim.api.nvim_open_win(buf, true, opts)

	return buf, win
end

local function read_file(file_path)
	local file = io.open(file_path, "r")
	if not file then
		print("Error: Could not open file " .. file_path)
		return nil
	end
	local content = file:read("*a")
	file:close()
	return content
end

local function read_all()
	local current_file_path = vim.fn.expand('%:p')
	local current_folder = vim.fn.fnamemodify(current_file_path, ':h')

	local chests = {}
	local append = function(fname)
		local json_file_path = current_folder .. "/" .. fname
		local json_content = read_file(json_file_path)
		if json_content then
			for _, data in ipairs(vim.json.decode(json_content).cargoquery) do
				local title = data.title
				if title.lootlist ~= vim.NIL then
					table.insert(chests, {
						description = title.description,
						-- inventory = title.inventory,
						location = title.location,
						lootlist = title.lootlist,
						x = title["position x"],
						z = title["position z"],
					})
				end
			end
		end
	end

	append("container_page1.json")
	append("container_page2.json")
	append("container_page3.json")

	return chests
end

local all = read_all()
popup(all)
