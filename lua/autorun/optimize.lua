local string = string
local type = type
local getmetatable = getmetatable

local unpack = unpack or table.unpack

local function is_callable(f)
	local tf = type(f)
	if tf == "function" then return true end
	if tf == "table" then
		local mt = getmetatable(f)
		return type(mt) == "table" and is_callable(mt.__call)
	end
	return false
end

local function cache_get(cache, params)
	local node = cache
	for i = 1, #params do
		node = node and node.children
		node = node and node[params[i]]
	end
	return node and node.results or nil
end

local function cache_put(cache, params, results)
	local node = cache
	local param
	for i = 1, #params do
		param = params[i]
		node.children = node.children or {}
		node.children[param] = node.children[param] or {}
		node = node.children[param]
	end
	node.results = results
end

-- public function
local memoize = {}

function memoize.memoize(f, cache)
	cache = cache or {}

	if not is_callable(f) then
		error(string.format(
						"Only functions and callable tables are memoizable. Received %s (a %s)",
						 tostring(f), type(f)))
	end

	return function (...)
		local params = {...}

		local results = cache_get(cache, params)
		if not results then
			results = { f(...) }
			cache_put(cache, params, results)
		end

		return unpack(results)
	end
end

setmetatable(memoize, { __call = function(_, ...) return memoize.memoize(...) end })

string.Trim = memoize(string.Trim)
string.find = memoize(string.find)
string.match = memoize(string.match)
string.gmatch = memoize(string.gmatch)
string.gsub = memoize(string.gsub)
string.byte = memoize(string.byte)

Color = memoize(Color)
Vector = memoize(Vector)
Angle = memoize(Angle)
if CLIENT then
	Material = memoize(Material)
	surface.CreateFont = memoize(surface.CreateFont)
	surface.GetTextureID = memoize(surface.GetTextureID)
end
