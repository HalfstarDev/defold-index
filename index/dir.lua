--- A Lua module for Defold to access file operations from editor scripts.
-- by Halfstar

local M = {}

local SEP = package.config:sub(1,1) or "/"
local sorting = false
local reload_resources = true



----------------
-- Utils
----------------

local function is_windows()
	if sys and sys.get_sys_info then
		return sys.get_sys_info().system_name == "Windows"
	elseif editor and editor.platform then
		return editor.platform == "x86-win32" or editor.platform == "x86_64-win32"
	else
		return SEP == "\\"
	end
end

local function subtract_lists(a, b)
	local list = {}
	for _, va in pairs(a) do
		local found = false
		for _, vb in pairs(b) do
			if va == vb then
				found = true
			end
		end
		if not found then
			list[#list + 1] = va
		end
	end
	return list
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

local function get_path(path, separator)
	separator = separator or SEP
	if path then
		return string.gsub(path, "[/\\]", separator)
	else
		return "."
	end
end


----------------
-- Windows
----------------

local function dir_popen_windows(path, param)
	local lines = {}
	for line in io.popen('dir "' .. path .. '" ' .. param .. ' /b'):lines() do
		lines[#lines + 1] = line
	end
	return lines
end

local function dir_popen_windows_all(path)
	return dir_popen_windows(path, "/a")
end

local function dir_popen_windows_folders(path)
	return dir_popen_windows(path, "/ad")
end

local function dir_editor_windows(path, param)
	local output = editor.execute('cmd.exe', '/c', 'dir', '"' .. path .. '"', param, '/b', {
		reload_resources = reload_resources,
		out = "capture"
	})
	return split_lines(output)
end

local function dir_editor_windows_all(path)
	return dir_editor_windows(path, "/a")
end

local function dir_editor_windows_folders(path)
	return dir_editor_windows(path, "/ad")
end


----------------
-- Unix
----------------

local function dir_popen_unix(path, param)
	local lines = {}
	for line in io.popen('find "' .. path .. '" -maxdepth 1 ' .. param .. '-print'):lines() do
		local match = string.match(line, "[^/]*$")
		if match and match ~= "." and line ~= path then
			lines[#lines + 1] = match
		end
	end
	return lines
end

local function dir_popen_unix_all(path)
	return dir_popen_unix(path, "")
end

local function dir_popen_unix_folders(path)
	return dir_popen_unix(path, "-type d ")
end

local function dir_editor_unix_all(path, param)
	local output = editor.execute('find', path, '-maxdepth', '1', {
		reload_resources = reload_resources,
		out = "capture"
	})
	local list = {}
	local lines = split_lines(output)
	for _, line in pairs(lines) do
		local match = string.match(line, "[^/]*$")
		if match and match ~= "." and line ~= path then
			list[#list + 1] = match
		end
	end
	return list
end

local function dir_editor_unix_folders(path, param)
	local output = editor.execute('find', path, '-maxdepth', '1', '-type', 'd', {
		reload_resources = reload_resources,
		out = "capture"
	})
	local list = {}
	local lines = split_lines(output)
	for _, line in pairs(lines) do
		local match = string.match(line, "[^/]*$")
		if match and match ~= "." and line ~= path then
			list[#list + 1] = match
		end
	end
	return list
end


----------------
-- Lists
----------------

local function get_list_all(path)
	path = get_path(path)
	if is_windows() then
		if editor and editor.execute then
			return dir_editor_windows_all(path)
		else
			return dir_popen_windows_all(path)
		end
	else
		if editor and editor.execute then
			return dir_editor_unix_all(path)
		else
			return dir_popen_unix_all(path)
		end
	end
end

local function get_list_folders(path)
	path = get_path(path)
	if is_windows() then
		if editor and editor.execute then
			return dir_editor_windows_folders(path)
		else
			return dir_popen_windows_folders(path)
		end
	else
		if editor and editor.execute then
			return dir_editor_unix_folders(path)
		else
			return dir_popen_unix_folders(path)
		end
	end
end

local function get_list_files(path)
	local all = get_list_all(path)
	local folders = get_list_folders(path)
	local files = subtract_lists(all, folders)
	return files
end



----------------
-- Public
----------------

function M.get_list_all(path)
	local list = get_list_all(path)
	if sorting then
		table.sort(list)
	end
	return list
end

function M.get_list_folders(path)
	local list = get_list_folders(path)
	if sorting then
		table.sort(list)
	end
	return list
end

function M.get_list_files(path)
	local list = get_list_files(path)
	if sorting then
		table.sort(list)
	end
	return list
end

return M
