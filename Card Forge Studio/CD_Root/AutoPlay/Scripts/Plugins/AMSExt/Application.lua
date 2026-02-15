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

function Application.IsCompiled()
    local sParent = String.Mid(_ExeFolder, String.ReverseFind(_ExeFolder, "\\") + 1, -1);
    local bRet = true;

    if String.Lower(sParent) == "cd_root" then
	    bRet = false;
    end

    return bRet;
end
