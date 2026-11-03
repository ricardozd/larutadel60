-- Usage: luajit dump_guide.lua <compiled-guide.lua> <guide-id>
-- Loads a compiled guide the way the WoW client would and prints ns.Guides[id] as JSON.
local path, id = arg[1], arg[2]
local ns = {}
assert(loadfile(path))("LaRutaDel60", ns)
local guide = assert(ns.Guides and ns.Guides[id], "guide not registered: " .. tostring(id))

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function encodeString(s)
	local escaped = s:gsub('[%c"\\]', function(c)
		return ESCAPES[c] or string.format("\\u%04x", c:byte())
	end)
	return '"' .. escaped .. '"'
end

local function arrayLength(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	for i = 1, count do
		if t[i] == nil then
			return nil
		end
	end
	return count
end

local encode
encode = function(value)
	local kind = type(value)
	if kind == "table" then
		local length = arrayLength(value)
		local parts = {}
		if length then
			for i = 1, length do
				parts[i] = encode(value[i])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for key in pairs(value) do
			assert(type(key) == "string", "non-string key in guide table")
			keys[#keys + 1] = key
		end
		table.sort(keys)
		for i, key in ipairs(keys) do
			parts[i] = encodeString(key) .. ":" .. encode(value[key])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return encodeString(value)
	elseif kind == "number" then
		return string.format("%.17g", value)
	elseif kind == "boolean" then
		return tostring(value)
	end
	error("unsupported type in guide: " .. kind)
end

io.write(encode(guide))
