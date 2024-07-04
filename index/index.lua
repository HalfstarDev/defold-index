--- A Lua module for Defold to automacitally create an index of custom resources, and to load that index.
-- by Halfstar

local dir = require "index.dir"

local M = {}

local SEP = package.config:sub(1,1)
local index_name = ".index.txt"
local index_path = index_name
local hidden_prefixes = {"%."}

local files = {}
local folders = {}
local tree
local index



local function is_windows()
	if editor and editor.platform then
		return editor.platform == "x86-win32" or editor.platform == "x86_64-win32"
	elseif sys and sys.get_sys_info then
		return sys.get_sys_info().system_name == "Windows"
	else
		return SEP == "\\"
	end
end

local function is_hidden(name)
	if name == "." or name == ".." then
		return true
	end
	if hidden_prefixes then
		for k, v in pairs(hidden_prefixes) do
			if string.match(name, "^" .. v) then
				return true
			end
		end
	end
end

local function is_path_folder(path)
	if not path or type(path) ~= "string" then return false end
	local result = string.match(path, ".*/$")
	return result and #result > 0
end

local function is_in_path(file, path)
	if not path then
		return true
	else
		if not is_path_folder(path) then
			path = path .. "/"
		end
		local length = #path
		local s = string.sub(file, 1, length)
		if s == path then
			return true
		end
	end
end

local function trim_slashes(s)
	return string.match(string.match(s, "^[/\\]*([^/\\].*)$"), "(.*[^/\\])[/\\]*$")
end

local function trim_dot(s)
	if string.sub(s, 1, 1) == "." then
		return string.sub(s, 2, -1)
	end
	return s
end

local function trim_path(path)
	return trim_slashes(trim_dot(path))
end

local function get_path(path, separator)
	separator = separator or SEP
	if path then
		return string.gsub(path, "[/\\]", separator)
	else
		return "."
	end
end

local function split_lines(lines)
	local list = {}
	if lines then
		for line in lines:gmatch("[^\r\n]+") do
			table.insert(list, line)
		end
	end
	return list
end

local function split_path(path)
	local list = {}
	for line in path:gmatch("[^/\\]+") do
		table.insert(list, line)
	end
	return list
end

local function is_tree_folder(subtree)
	return type(subtree) == "table"
end

local function is_tree_file(subtree)
	return type(subtree) == "string"
end

local function if_file_folder_windows(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
		return false
	else
		return true
	end
end

local function if_file_folder_unix(path)
	local f = io.open(path, "rb")
	if f then
		local data = f:read("*a")
		f:close()
		return data == nil
	else
		return true
	end
end

local function if_file_folder(path)
	path = get_path(path)
	if is_windows() then
		return if_file_folder_windows(path)
	else
		return if_file_folder_unix(path)
	end
end

local function write(data)
	local path = get_path(index_path)
	local f = io.open(path, "w")
	if f then
		f:write(data)
		f:close()
	end
end

local function get_list_folders(path)
	local list = {}
	for _, line in pairs(dir.get_list_folders(path)) do
		if not is_hidden(line) then
			table.insert(list, line)
		end
	end
	return list
end

local function get_list_files(path)
	local list = {}
	for _, line in pairs(dir.get_list_files(path)) do
		if not is_hidden(line) then
			table.insert(list, line)
		end
	end
	return list
end

local function get_custom_resources()
	local file = io.open("game.project", "r")
	if file then
		for line in file:lines() do
			local s = string.match(line, "custom_resources =(.*)")
			if s then
				local custom_resources = {}
				for w in string.gmatch(s .. ",", "%s*([^,]*)%s*,") do
					table.insert(custom_resources, w)
				end
				return custom_resources
			end
		end
	end
end

local function add_file(path)
	table.insert(files, path)
end

local function add_folder(path)
	table.insert(folders, path)
end

local function add_folders(path)
	if if_file_folder(path) then
		add_folder(path)
		local list = get_list_folders(path)
		for _, v in pairs(list) do
			local folder_path = path .. "/" .. v
			add_folders(folder_path)
		end
	end
end

local function add_files(path)
	local list = get_list_files(path)
	for _, v in pairs(list) do
		local file_path = path .. "/" .. v
		add_file(file_path)
	end
end

local function create_tree()
	folders = {}
	files = {}

	for _, v in pairs(index) do
		if is_path_folder(v) then
			table.insert(folders, v)
		else
			table.insert(files, v)
		end
	end

	tree = {}
	for k, v in pairs(folders) do
		local split = split_path(v)
		local current = tree
		for i = 1, #split do
			local folder = split[i]
			if not current[folder] then
				current[folder] = {}
			end
			current = current[folder]
		end
	end
	for k, v in pairs(files) do
		local split = split_path(v)
		local current = tree
		for i = 1, #split - 1 do
			local folder = split[i]
			if not current[folder] then
				current[folder] = {}
			end
			current = current[folder]
		end
		local file = split[#split]
		current[file] = v
	end
end

local function get_from_tree(tree_root, path)
	if not path then
		return tree_root
	else
		local split = split_path(path)
		local current = tree_root
		for i, v in ipairs(split) do
			if current and current[v] then
				current = current[v]
			else
				return current
			end
		end
		return current
	end
end

local function read_index()
	local data, error = sys.load_resource("/" .. index_path)
	if data then
		index = split_lines(data)
	else
		local custom_resources = get_custom_resources()
		for _, v in pairs(custom_resources) do
			data, error = sys.load_resource("/" .. v .. "/" .. index_name)
			if data then
				index = split_lines(data)
				return
			end
		end
	end
end

local function get_index()
	if not index then
		read_index()
	end
	return index
end

local function get_folder(path, hide_folders, hide_files)
	if not index then
		read_index()
	end
	if not tree then
		create_tree()
	end
	local subtree = get_from_tree(tree, path)
	local folder = {}
	for k, v in pairs(subtree) do
		if type(v) == "table"  then
			if not hide_folders then
				if path then
					folder[k] = path .. "/" .. k .. "/"
				else
					folder[k] = k .. "/"
				end
			end
		else
			if not hide_files then
				folder[k] = v
			end
		end
	end
	return folder
end

local function find_in_tree(subtree, name)
	for k, v in pairs(subtree) do
		if is_tree_folder(v) then
			local result = find_in_tree(v, name)
			if result then
				return result
			end
		else
			if k == name then
				return v
			end
		end
	end
	return false
end





-- index.create()
-- This will create the index file
-- Should be used in hooks.editor_script
function M.create()
	local custom_resources = get_custom_resources()
	local custom_resources_folders = {}
	local custom_resources_files = {}
	if custom_resources then
		for _, v in pairs(custom_resources) do
			if if_file_folder(v) then
				if not is_hidden(v) then
					table.insert(custom_resources_folders, v)
				end
			else
				if not is_hidden(v) then
					table.insert(custom_resources_files, v)
				end
			end
		end
	end
	local index_in_root = false
	for _, path in pairs(custom_resources) do
		if path == index_path then
			index_in_root = true
		end
	end
	if not index_in_root then
		if #custom_resources_folders == 0 then
			print("ERROR: You have to add .index.txt to your custom resources in game.project.")
			return
		else
			index_path = custom_resources_folders[1] .. "/" .. index_name
		end
	end

	folders = {}
	files = {}
	for _, v in pairs(custom_resources_folders) do
		add_folders(v)
	end
	for _, v in pairs(folders) do
		add_files(v)
	end
	for _, v in pairs(custom_resources_files) do
		add_file(v)
	end

	local all = {}
	for k, v in pairs(folders) do
		table.insert(all, v .. "/")
	end
	for k, v in pairs(files) do
		table.insert(all, v)
	end
	table.sort(all)

	local s = ""
	for _, v in pairs(all) do
		s = s .. v .. "\n"
	end
	write(s)
end

-- index.is_folder(path_or_tree)
-- Returns true is the given path or tree node is a folder
function M.is_folder(path_or_tree)
	if not path_or_tree then return end
	return is_tree_folder(path_or_tree) or is_path_folder(path_or_tree)
end

-- index.is_file(path_or_tree)
-- Returns true is the given path or tree node is a file
function M.is_file(path_or_tree)
	if not path_or_tree then return end
	return is_tree_file(path_or_tree) and not is_path_folder(path_or_tree)
end

-- index.get_list([path])
-- Returns a list of all files and folders reachable from given path, or from root if no path is given
-- The list will have integer indices as keys, the full paths as values, and will be sorted alphabetically
-- 
--[[ Example:
{
	1 = "assets/",
	2 = "assets/data.txt",
	3 = "assets/images/",
	4 = "assets/images/enemy.png",
	5 = "assets/images/player.png",
	6 = "assets/levels/",
	7 = "assets/levels/1.txt",
	8 = "assets/levels/2.txt",
	9 = "assets/levels/3.txt"
}
--]]
function M.get_list(path)
	local list = {}
	for k, v in pairs(get_index()) do
		if is_in_path(v, path) then
			list[#list + 1] = v
		end
	end
	return list
end

-- index.get_list_files([path])
-- Returns a list of all files reachable from given path, or from root if no path is given
--[[ Example:
{
	1 = "assets/data.txt",
	2 = "assets/images/enemy.png",
	3 = "assets/images/player.png",
	4 = "assets/levels/1.txt",
	5 = "assets/levels/2.txt",
	6 = "assets/levels/3.txt"
}
--]]
function M.get_list_files(path)
	local list = {}
	for k, v in pairs(M.get_list(path)) do
		if not is_path_folder(v) then
			list[#list + 1] = v
		end
	end
	return list
end

-- index.get_list_folders([path])
-- Returns a list of all folders reachable from given path, or from root if no path is given
--[[ Example:
{
	1 = "assets/",
	2 = "assets/images/",
	3 = "assets/levels/"
}
--]]
function M.get_list_folders(path)
	local list = {}
	for k, v in pairs(M.get_list(path)) do
		if is_path_folder(v) then
			list[#list + 1] = v
		end
	end
	return list
end

-- index.get_tree([path])
-- Returns a tree in form of a nested table with all files and folders reachable from path, or from root if no path given
-- For files, keys are the name of the file, and values the full path of the file
-- For folders, keys are the name of the folder, and values are a tree with the content of the folder
--[[ Example:
{
	assets = {
		data.txt = "assets/data.txt",
		images = {
			player.txt = "assets/images/player.png",
			enemy.txt = "assets/images/enemy.png"
		},
		levels = {
			1.txt = "assets/levels/1.txt",
			2.txt = "assets/levels/2.txt",
			3.txt = "assets/levels/3.txt",
		}
	}
}
--]]
function M.get_tree(path)
	if not index then
		read_index()
	end
	if not tree then
		create_tree()
	end
	return get_from_tree(tree, path)
end

-- index.get_folder([path])
-- Returns a table with the content of the folder
-- For both files and folders, keys are their name, and values their full path
-- Unlike get_list(), this only contains the content of this folder, and not any deeper levels
--[[ Example:
{
	data.txt = "assets/data.txt",
	images = "assets/images/",
	levels = "assets/levels/"
}
--]]
function M.get_folder(path)
	return get_folder(path)
end

-- index.get_folder_files([path])
-- Returns a table with the files of the folder
-- Like get_folder(), but without folders in folder
function M.get_folder_files(path)
	return get_folder(path, true, false)
end

-- index.get_folder_folders([path])
-- Returns a table with the folders of the folder
-- Like get_folder(), but without files in folder
function M.get_folder_folders(path)
	return get_folder(path, false, true)
end

-- index.is_file_indexed(path)
-- Returns true if there is a file at the given path in the index
-- Does not look for folders, only files
function M.is_file_indexed(path)
	path = trim_path(path) or path
	local list = M.get_list_files()
	for k, v in pairs(list) do
		if v == path then
			return true
		end
	end
	return false
end

-- index.find_file(name, [path])
-- Searches for the file with the given name from the given path, or from the root if no path given 
-- Will do a deep search in all folders in path
-- Returns the full path of the found file, or nil if not found
function M.find_file(name, path)
	if not index then read_index() end
	if not tree then create_tree() end
	local subtree = get_from_tree(tree, path)
	return find_in_tree(subtree, name)
end

return M
