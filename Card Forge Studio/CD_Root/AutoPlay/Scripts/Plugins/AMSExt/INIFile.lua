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

--TODO add options for inhereitence in these two below
function INIFile.GetValueBoolean(pFile, sSection, sValue)
    local bRet = false;

    local bFileIsString     = type(pFile) =="string";
    local bSectionIsString  = type(sSection) == "string";
    local bValueIsString    = type(sValue) == "string";

    if (bFileIsString and bSectionIsString and bValueIsString) then
        local sValue = INIFile.GetValue(pFile, sSection, sValue);
        bRet = sValue:lower() == "true" and true or false;
    end

    return bRet;
end

function INIFile.GetValueNumber(pFile, sSection, sValue)
	local nRet = 0;

    local bRet = false;

    local bFileIsString     = type(pFile) =="string";
    local bSectionIsString  = type(sSection) == "string";
    local bValueIsString    = type(sValue) == "string";

	if (bFileIsString and bSectionIsString and bValueIsString) then
        local nValue    = tonumber(INIFile.GetValue(pFile, sSection, sValue));
        local nRet      = nValue and nValue or nRet;
	end

	return nRet;
end



local _fINIFileGetValue = INIFile.GetValue;
--TODO BUG if luaex is not present, trim and isempty won't work
function INIFile.GetValueOLD(pINI, sSectionName, sValName, tVisited)
   local sRet = "";

   tVisited = istable(tVisited) and tVisited or {};

   local sVisitKey = tostring(sSectionName)..":"..tostring(sValName);

    if (tVisited[sVisitKey]) then
        -- cycle detected -> treat as empty
        sRet = "";
    else
        tVisited[sVisitKey] = true;

        local sRaw = _fINIFileGetValue(pINI, sSectionName, sValName);

        if not type.isstring(sRaw) then
            sRaw = "";
        end

        local sTrimmed = sRaw:trim();

        local bIsRef = (not sTrimmed:isempty())
                   and (sTrimmed:sub(1, 1) == "<")
                   and (sTrimmed:sub(-1) == ">");

        if (bIsRef) then
            local sRefSection = sTrimmed:sub(2, -2):trim();

            if not(sRefSection:isempty()) then
                -- IMPORTANT RULE:
                -- Reference to an empty key should leave the referencing key empty.
                -- So if the referenced key resolves to "", we return "".
                local sResolved = INIFile.GetValue(pINI, sRefSection, sValName, tVisited);
                sRet = type.isstring(sResolved) and sResolved or "";
                --p(sSectionName.." is referencing "..sRefSection.." regarding "..sValName.." and getting back "..sRet)
            else
                -- "<>" is treated as empty
                sRet = "";
            end
        else
            sRet = sRaw;
        end

        tVisited[sVisitKey] = nil;
    end

    return sRet;
end



function INIFile.GetValueNEWER(pINI, sSectionName, sValName, tVisited, tChain)
    local sRet;

    tVisited = istable(tVisited) and tVisited or {};

    local sVisitKey = tostring(sSectionName)..":"..tostring(sValName);

    if (tVisited[sVisitKey]) then
        -- cycle detected -> treat as empty
        return "", (istable(tChain) and tChain or nil);
    end

    tVisited[sVisitKey] = true;

    local sRaw = _fINIFileGetValue(pINI, sSectionName, sValName);
    if not type.isstring(sRaw) then
        sRaw = "";
    end

    local sTrimmed = sRaw:trim();

    local bIsRef = (not sTrimmed:isempty())
               and (sTrimmed:sub(1, 1) == "<")
               and (sTrimmed:sub(-1) == ">");

    if (bIsRef) then
        local sRefSection = sTrimmed:sub(2, -2):trim();

        if not sRefSection:isempty() then
            -- Chain is 1..n where [1] is first inheritance hop, [n] is last hop.
            local tChainNext = tChain;
            if not istable(tChainNext) then
                tChainNext = {};
            end
            tChainNext[#tChainNext + 1] = sRefSection;

            local sResolved, tOutChain = INIFile.GetValue(pINI, sRefSection, sValName, tVisited, tChainNext);
            sRet = type.isstring(sResolved) and sResolved or "";

            tVisited[sVisitKey] = nil;
            return sRet, (istable(tOutChain) and tOutChain or tChainNext);
        else
            -- "<>" treated as empty
            sRet = "";
        end
    else
        sRet = sRaw;
    end

    tVisited[sVisitKey] = nil;

    -- Only return a chain if inheritance was actually used.
    return sRet, (istable(tChain) and tChain or nil);
end


local _fINIFileSetValue = INIFile.SetValue;
--local _fINIFileGetValue = _fINIFileGetValue or INIFile.GetValue; -- if you've already saved it earlier, keep that

local function ResolveINIWriteSection(pINI, sSectionName, sValName, tVisited)
    tVisited = istable(tVisited) and tVisited or {};

    local sCurSection = tostring(sSectionName or "");
    local sKeyName    = tostring(sValName or "");

    while (sCurSection ~= "" and sKeyName ~= "") do
        local sVisitKey = sCurSection..":"..sKeyName;

        if (tVisited[sVisitKey]) then
            -- cycle -> stop and write to the current section
            return sCurSection;
        end

        tVisited[sVisitKey] = true;

        local sRaw = _fINIFileGetValue(pINI, sCurSection, sKeyName);
        if not type.isstring(sRaw) then
            sRaw = "";
        end

        local sTrimmed = sRaw:trim();

        local bIsRef = (not sTrimmed:isempty())
                   and (sTrimmed:sub(1, 1) == "<")
                   and (sTrimmed:sub(-1) == ">");

        if not bIsRef then
            -- no inheritance here -> this is the final write target
            return sCurSection;
        end

        local sRefSection = sTrimmed:sub(2, -2):trim();
        if (sRefSection:isempty()) then
            -- "<>" treated as empty -> stop and write to current section
            return sCurSection;
        end

        -- follow the chain
        sCurSection = sRefSection;
    end

    return tostring(sSectionName or "");
end

function INIFile.SetValue(pFile, sSection, sValue, sData, bRespectChain)
    if not bRespectChain then
        return _fINIFileSetValue(pFile, sSection, sValue, sData);
    end

    local sTargetSection = ResolveINIWriteSection(pFile, sSection, sValue, {});
    return _fINIFileSetValue(pFile, sTargetSection, sValue, sData);
end

function INIFile.GetValue(pINI, sSectionName, sValName, bInherit, tVisited, tChain)
    local sRet;

    -- Inheritance is OFF by default
    if (bInherit ~= true) then
        local sRaw = _fINIFileGetValue(pINI, sSectionName, sValName);
        return type.isstring(sRaw) and sRaw or "", nil;
    end

    tVisited = istable(tVisited) and tVisited or {};

    local sVisitKey = tostring(sSectionName)..":"..tostring(sValName);

    if (tVisited[sVisitKey]) then
        -- cycle detected -> treat as empty
        return "", (istable(tChain) and tChain or nil);
    end

    tVisited[sVisitKey] = true;

    local sRaw = _fINIFileGetValue(pINI, sSectionName, sValName);
    if not type.isstring(sRaw) then
        sRaw = "";
    end

    local sTrimmed = sRaw:trim();

    local bIsRef = (not sTrimmed:isempty())
               and (sTrimmed:sub(1, 1) == "<")
               and (sTrimmed:sub(-1) == ">");

    if (bIsRef) then
        local sRefSection = sTrimmed:sub(2, -2):trim();

        if not sRefSection:isempty() then
            local tChainNext = tChain;
            if not istable(tChainNext) then
                tChainNext = {};
            end
            tChainNext[#tChainNext + 1] = sRefSection;

            local sResolved, tOutChain =
                INIFile.GetValue(pINI, sRefSection, sValName, true, tVisited, tChainNext);

            sRet = type.isstring(sResolved) and sResolved or "";

            tVisited[sVisitKey] = nil;
            return sRet, (istable(tOutChain) and tOutChain or tChainNext);
        else
            -- "<>" treated as empty
            sRet = "";
        end
    else
        sRet = sRaw;
    end

    tVisited[sVisitKey] = nil;

    return sRet, (istable(tChain) and tChain or nil);
end
