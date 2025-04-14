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

local function popup(data, filetype)
	local message = prepare_messages(data)

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
	if filetype then
		vim.api.nvim_set_option_value("filetype", filetype, {
			buf = buf,
		})
	end
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

local function find_lootlists(lootlists, id)
	local candidates = {}
	for name, ll in pairs(lootlists) do
		for _, item in ipairs(ll.items) do
			if item.id == id then
				table.insert(candidates, name)
			end
		end
	end
	for _, candidate in ipairs(candidates) do
		vim.list_extend(candidates, find_lootlists(lootlists, candidate))
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


local query = "Gauntlets_of_Swift_Action"

local lootlists = read_lootlists()
local filtered_lootlists = distinct_list(find_lootlists(lootlists, query))
local chests = {}

for _, title in ipairs(read_containers()) do
	if vim.tbl_contains(filtered_lootlists, title.lootlist) then
		table.insert(chests, title)
	end
end


-- Xorshift128 state
local x = 0
local y = 0
local z = 0
local w = 0

local function get_seed(pos_x, pos_z, day)
	local t, _ = math.modf(pos_x + pos_z)
	local long = t * -30676112 + day
	return (long + 2 ^ 31) % 2 ^ 32 - 2 ^ 31
end

local function uintMultiply(a, b)
	a = a % 4294967296
	b = b % 4294967296
	local ah, al = math.floor(a / 65536), a % 65536
	local bh, bl = math.floor(b / 65536), b % 65536
	local high = ((ah * bl) + (al * bh)) % 65536
	return ((high * 65536) + (al * bl)) % 4294967296
end

function Xorshift128_InitSeed(seed)
	x = uintMultiply(seed, 1)
	y = uintMultiply(1812433253, x) + 1
	z = uintMultiply(1812433253, y) + 1
	w = uintMultiply(1812433253, z) + 1
end

function Xorshift128_Next()
	local t = bit.bxor(x, bit.lshift(x, 11))
	x = y; y = z; z = w
	w = bit.bxor(w, bit.rshift(w, 19), t, bit.rshift(t, 8))
	return w
end

function Xorshift128_NextUIntMax(max)
	if (max == 0) then
		return 0
	else
		return Xorshift128_Next() % max
	end
end

function EvaluateLootList(lootlist)
	local items = {}
	local done = false;
	local roll = nil

	local totalWeight = lootlist["total_weight"]

	roll = Xorshift128_NextUIntMax(totalWeight)

	local cumulativeWeight = 0; -- Used for weighted random selection

	for _, lootItem in ipairs(lootlist.items) do
		local shouldAdd = false

		if (lootItem.always == true) then
			shouldAdd = true
		else
			cumulativeWeight = cumulativeWeight + lootItem.weight

			if (roll < cumulativeWeight and done ~= true) then
				shouldAdd = true
				done = true
			end
		end

		if (lootItem.id ~= nil and shouldAdd) then
			for _ = 1, tonumber(lootItem.count) do
				if (lootItem.is_lootlist == true) then
					local childLootList = lootlists[lootItem.id]
					local childItems = EvaluateLootList(childLootList)

					if (childItems ~= nil) then
						for i = 1, #childItems do
							items[#items + 1] = childItems[i]
						end
					end
				else
					items[#items + 1] = lootItem.id
				end
			end
		end
	end

	return items
end

local function make_query()
	for _, chest in ipairs(chests) do
		for day = 1, 20 do
			local seed = get_seed(tonumber(chest.x), tonumber(chest.z), day)
			Xorshift128_InitSeed(seed)
			chest["day_" .. day .. "_loot"] = EvaluateLootList(lootlists[chest.lootlist])
		end
	end


	local report = { "### " .. query .. " found in " .. #chests .. " random loot table:" }
	for _, chest in ipairs(chests) do
		local line = "- [" .. chest.location .. "] " .. chest.description .. ", day "
		for day = 1, 20 do
			if vim.tbl_contains(chest["day_" .. day .. "_loot"], query) then
				line = line .. day .. " "
			end
		end
		table.insert(report, line)
	end

	popup(report, "markdown")
end

local function test_seed()
	local report = {}

	local pregen = dofile(vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h') .. "/seed_pregen_data.lua").states
	local equal = 0
	local notEqual = 0

	for k, v in pairs(pregen) do
		Xorshift128_InitSeed(k)

		local ux = x
		local uy = y
		local uz = z
		local uw = w

		if (ux ~= v[1] or uy ~= v[2] or uz ~= v[3] or uw ~= v[4]) then
			notEqual = notEqual + 1
		else
			equal = equal + 1
		end

		-- table.insert(report, "- seed: " .. k)
		-- table.insert(report, "  - pregen:" .. "x=" .. v[1] .. ", y=" .. v[2] .. ", z=" .. v[3] .. ", w=" .. v[4])
		-- table.insert(report, "  - ourgen:" .. "x=" .. ux .. ", y=" .. uy .. ", z=" .. uz .. ", w=" .. uw)

		if (notEqual > 50) then
			break
		end
	end

	table.insert(report, "pregenerated vs generated states\n\tequal: " .. equal .. "\n\tnot equal: " .. notEqual)
	popup(report, "markdown")
end

-- test_seed()
make_query()
