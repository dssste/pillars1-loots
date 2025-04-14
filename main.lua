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
	vim.api.nvim_buf_set_lines(buf, 0, 0, false, message)
	vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
		callback = function()
			vim.cmd('bdelete! ' .. buf)
		end
	})

	local win = vim.api.nvim_open_win(buf, true, opts)

	return buf, win
end

local function read_containers()
	local current_folder = vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h')

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

local function read_lootlists()
	local current_folder = vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h')
	local lua_table = dofile(current_folder .. "/lootlist_data.lua")
	return lua_table.lootlists
end

local function find_candidates(lootlists, id)
	local candidates = {}
	for name, ll in pairs(lootlists) do
		for _, item in ipairs(ll.items) do
			if item.id == id then
				table.insert(candidates, name)
			end
		end
	end
	for _, candidate in ipairs(candidates) do
		vim.list_extend(candidates, find_candidates(lootlists, candidate))
	end
	return candidates
end

local function distinct_list(list)
	local seen = {}
	local result = {}
	for _, value in ipairs(list) do
		if not seen[value] then
			table.insert(result, value)
			seen[value] = true
		end
	end
	return result
end

local candidates = find_candidates(read_lootlists(), "Gauntlets_of_Swift_Action")
candidates = distinct_list(candidates)

local all = read_containers()

local valid = {}

for _, title in ipairs(all) do
	if vim.tbl_contains(candidates, title.lootlist) then
		table.insert(valid, title)
	end
end

local buf, win = popup(valid)
-- vim.api.nvim_buf_set_lines(buf, -1, -1, false, candidates)
-- vim.api.nvim_buf_set_lines(buf, -1, -1, false, {tostring(#valid)})
