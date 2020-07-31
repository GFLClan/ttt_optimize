local _setmetatable = setmetatable
local _unpack = unpack
local _getmetatable = getmetatable
local _type = type
local _string_find = string.find
local _string_byte = string.byte
local _string_Trim = string.Trim
local _error = error
local _string_gmatch = string.gmatch
local _tostring = tostring
local _string_gsub = string.gsub
local _string_match = string.match
local _tobool = tobool
local _tonumber = tonumber
local _string_format = string.format
local _ScreenScale = (CLIENT and ScreenScale or nil)
local string = string
local type = _type
local getmetatable = _getmetatable

local unpack = _unpack or table.unpack

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
		_error(_string_format(
						"Only functions and callable tables are memoizable. Received %s (a %s)",
						 _tostring(f), type(f)))
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

_setmetatable(memoize, { __call = function(_, ...) return memoize.memoize(...) end })

_string_Trim = memoize(_string_Trim)
_string_find = memoize(_string_find)
_string_match = memoize(_string_match)
_string_gmatch = memoize(_string_gmatch)
_string_gsub = memoize(_string_gsub)
_string_byte = memoize(_string_byte)

game.GetMap = memoize(game.GetMap)

_tonumber = memoize(_tonumber)
_tostring = memoize(_tostring)
_tobool = memoize(_tobool)

if CLIENT then
	_ScreenScale = memoize(_ScreenScale)
end
