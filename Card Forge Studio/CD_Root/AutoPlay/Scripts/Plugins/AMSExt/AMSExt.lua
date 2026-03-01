if not (LUAEX_INIT) then
    error("Could not load AMSExt plugin. Requires LuaEx (best with AMS LuaExLoader plugin).");
end

local class         = class;
local math          = math;
    local clamp     = math.clamp;
local rawtype       = rawtype;
local string        = string;
local toboolean     = toboolean;
local tonumber      = tonumber;
local tostring      = tostring;
local type          = type;
    local clamp         = math.clamp;
    local floor         = math.floor;
    local isnumber      = type.isnumber;
    local isstring      = type.istring;
    local istable       = type.istable;

--TODO localization and comments for sections (and sort sections)

function p(...)
	local sArg		= "";
	local tArgs 	= {...} or arg;
	local nArgs 	= #tArgs;
	local sArgs 	= "";
	local sSuffix 	= "\r\n";

	for nIndex, vArg in pairs(tArgs) do

		local sType 		= type(vArg);
		local bIsTable 		= sType == "table";
		local bSerialize	= false;
		local fSerialize 	= nil;

		if (rawtype(vArg) == "table") then
			local fFunc = rawget(vArg, "Serialize");
			local fSerialize = type(fFunc) == "function" and fFunc or nil;

			if not (fSerialize) then
				local fFunc = rawget(vArg, "Serialize");
				fSerialize = type(fFunc) == "function" and fFunc or nil;
			end

		end

		local bSerialize 	= type(fSerialize) == "function";
		local bIncludeSelf 	= (bSerialize and not bIsTable) and vArg or nil;

		if type(nIndex) == "number" then

			if (bSerialize) then
				sArg = fSerialize(bIncludeSelf);

			else

				if (bIsTable) then
					sArg = serialize(vArg);

				else
					sArg = tostring(vArg);
				end

			end

			sArgs = sArgs..nIndex..": "..sArg..((nIndex < nArgs) and "\r\n\r\n" or "");
		end

	end

	Dialog.Message("Debug", sArgs);
end

Windows = require("Plugins.AMSExt.Windows");

require("Plugins.AMSExt.KEY_CODES");
require("Plugins.AMSExt.Application");
require("Plugins.AMSExt.Color");
require("Plugins.AMSExt.DialogEx");
require("Plugins.AMSExt.Grid");
require("Plugins.AMSExt.INIFile");

LiveFile = require("Plugins.AMSExt.LiveFile");
Menu = require("Plugins.AMSExt.Menu");
WinSys = require("Plugins.AMSExt.WinSys");
WinAMS = require("Plugins.AMSExt.WinSys.WinAMS");
