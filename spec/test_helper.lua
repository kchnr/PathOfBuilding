-- Test helper for layer-specific tests.
-- Configures package.path and loads the utilities + class system
-- so tests can use require() for project modules without HeadlessWrapper.

-- Determine src/ directory: try CWD-relative, then script-relative
local function findSrcDir()
	local f = io.open("src/Modules/Common.lua", "r")
	if f then f:close(); return "src" end
	f = io.open("../src/Modules/Common.lua", "r")
	if f then f:close(); return "../src" end
	return "src"
end

local function findRuntimeDir()
	local f = io.open("runtime/lua/xml.lua", "r")
	if f then f:close(); return "runtime/lua" end
	f = io.open("../runtime/lua/xml.lua", "r")
	if f then f:close(); return "../runtime/lua" end
	return "runtime/lua"
end

local srcDir = findSrcDir()
local runtimeDir = findRuntimeDir()

-- Add project src and runtime directories to package.path
package.path = package.path .. ";" .. srcDir .. "/?.lua;" .. srcDir .. "/?/init.lua"
package.path = package.path .. ";" .. runtimeDir .. "/?.lua;" .. runtimeDir .. "/?/init.lua"

-- Stub out modules that need C libs or game engine
local l_require = require
_G.require = function(name)
	if name == "lcurl.safe" or name == "sha1" or name == "base64" then
		return nil
	end
	return l_require(name)
end

-- Minimal stubs needed by Common.lua before it defines globals
ConPrintf = ConPrintf or function() end
launch = launch or { devMode = false }
APP_NAME = APP_NAME or "PathOfBuilding"

-- Load Common.lua to define copyTable, common table, and class system
dofile(srcDir .. "/Modules/Common.lua")
