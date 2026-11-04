--TODO localization including Menu.EVENT
--TODO perhaps allow bypass of events when manually setting?
--[[
local function TextToUID(sNameRaw)
    -- canonicalize
    local sName = tostring(sNameRaw)
        :lower()
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")

    -- AMS-safe range (adjust to 65535 if AMS tolerates it)
    --local MAX = 32767
    local MAX = 31000

    -- start value (non-zero)
    local nID = 1

    for x = 1, #sName do
        local nChar      = sName:byte(x)
        local nOperation = ((x - 1) % 3) + 1

        if (nOperation == 1) then
            -- add + mix
            nID = (nID + nChar + (nID * 3)) % MAX

        elseif (nOperation == 2) then
            -- subtract + mix (keep integer)
            nID = (nID - nChar - (nID * 2)) % MAX

        else -- nOperation == 3
            -- multiply + add
            nID = (nID * 5 + nChar + x) % MAX
        end

        -- keep positive 1..MAX
        if (nID < 0) then
            nID = nID + MAX
        end
        if (nID == 0) then
            nID = 1
        end
    end

    return nID
end
]]


return class("MenuItem",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --MenuItem = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        --TextToUID = TextToUID,
    },
    {--PRIVATE
        ID__AUTO__          = -1,
        Text__AUTOA_        = "",
        IconID__AUTOA_      = -1,
        Enabled__AUTOA_Is   = true,
        Checked__AUTOA_Is   = false,
        Checkable__AUTOA_Is = false,
        Path__AUTOA_        = "",
        --Items            = {},
        Callbacks           = {
            OnChecked           = nil,
            OnUnchecked         = nil,
            OnEnabled           = nil,
            OnDisabled          = nil,
            OnSetCheckable      = nil,
            OnSetUncheckable    = nil,
            OnIconIDChanged     = nil,
            OnSelected          = nil,
            OnTextChanged       = nil,
        },

        --Parent              = null, TODO fresh on add.remove child
    },
    {--PROTECTED

    },
    {--PUBLIC
        MenuItem = function(this, cdat, vPath, vIconID, vEnabled, vChecked, vCheckable, vCallbacks)
            local pri = cdat.pri;

            --set the path and text
            local sPath      = rawtype(vPath)        == "string"     and vPath           or "";
            pri.Path         = sPath;
            local tText      = sPath:totable(Menu.DELIMITER) or {};
            local sText      = tText[#tText] or "";
            pri.Text         = sText;

            --pri.ID           = -1;--PathToID(pri.Path);
            pri.IconID       = rawtype(vIconID)      == "number"     and math.floor(vIconID)  or -1;
            if (rawtype(vEnabled) == "boolean") then
                pri.Enabled = vEnabled;
            else
                pri.Enabled = true;
            end
            pri.Checked      = rawtype(vChecked)     == "boolean"    and vChecked        or false;
            pri.Checkable    = rawtype(vCheckable)   == "boolean"    and vCheckable      or false;

            if (type(vCallbacks) == "table") then

                for eMenuEvent, fCallback in pairs(vCallbacks) do

                    if not (type(eMenuEvent) == "Menu.EVENT") then
                        error("Error importing callback in MenuItem. Expected type Menu.EVENT. Got "..type(eMenuEvent)..'.', 3);
                    end

                    if not (type(fCallback) == "function") then
                        error("Error importing callback in MenuItem. Expected type function. Got "..type(fCallback)..'.', 3);
                    end

                    pri.Callbacks[tostring(eMenuEvent)] = fCallback;
                end

            end

        end,--TODO more functions for children...need RemoveChild , also do sorter as menu will have
        --[[AddItem = function(this, cdat, oMenuItem)
            --TODO assertions
            local tKids = cdat.pri.Items;
            tKids[#tKids + 1] = oMenuItem;
        end,]]
        GetCallback = function(this, cdat, eMenuEvent)

            if not (type(eMenuEvent) == "Menu.EVENT") then
                error("Error gettings callback in MenuItem. Expected type Menu.EVENT. Got "..type(eMenuEvent)..'.', 3);
            end

            return cdat.pri.Callbacks[tostring(eMenuEvent)];
        end,
        --[[GetItems = function(this, cdat, nIndex)
            --TODO assertions
            return cdat.pri.Items[nIndex] or nil;
        end,
        GetItems = function(this, cdat)
            local tRet;
            local tItems    = cdat.pri.Items;

            if (#tItems > 0) then
                tRet = {};

                for _, oChild in ipairs(tItems) do
                    tRet[#tRet + 1] = oChild;
                end

            end

            return tRet;
        end,]]
        --[[GetTable = function(this, cdat)
            local tSubMenu;
            local pri       = cdat.pri;
            local tItems    = pri.Items;

            if (#tItems > 0) then
                tSubMenu = {};

                for _, oChild in ipairs(tItems) do
                    tSubMenu[#tSubMenu + 1] = oChild.GetItems();
                end

            end

            return {
                ID      = pri.ID,
                Text    = pri.Text,
                IconID  = pri.IconID,
                Enabled = pri.Enabled,
                Checked = pri.Checked,
                SubMenu = tSubMenu,
            };
        end,]]
        Select = function(this, cdat)
            local pri = cdat.pri;
            local sEvent = tostring(Menu.EVENT.OnSelected);
            local fCallback = pri.Callbacks[sEvent];

            if (fCallback) then
                return fCallback(this);
            end

        end,
        SetCallback = function(this, cdat, eMenuEvent, fCallback)
            if not (type(eMenuEvent) == "Menu.EVENT") then
                error("Error setting callback in MenuItem. Expected type Menu.EVENT. Got "..type(eMenuEvent)..'.', 3);
            end

            cdat.pri.Callbacks[tostring(eMenuEvent)] = fCallback and fCallback or nil;

            return this;
        end,
        SetCheckable = function(this, cdat, bFlag)
            local vRet;

            --set the item checked/unchecked
            local pri           = cdat.pri;
            local bCheckable    = rawtype(bFlag) == "boolean" and bFlag or false;
            local bWasCheckable = pri.Checkable;
            pri.Checkable       = bCheckable;

            --if something changed, fire the callback (if present)
            if (bWasCheckable ~= bCheckable) then
                local sEvent = tostring(bCheckable and Menu.EVENT.OnSetCheckable or Menu.EVENT.OnSetUncheckable);

                local fCallback = pri.Callbacks[sEvent];
                if (fCallback) then
                    vRet = fCallback(this);
                end

            end

            return vRet;
        end,
        SetChecked = function(this, cdat, bFlag)
            local vRet;

            --set the item checked/unchecked
            local pri           = cdat.pri;
            local bChecked      = rawtype(bFlag) == "boolean" and bFlag or false;
            local bWasChecked   = pri.Checked;
            pri.Checked         = bChecked;

            --if something changed, fire the callback (if present)
            if (bWasChecked ~= bChecked) then
                local sEvent = tostring(bChecked and Menu.EVENT.OnChecked or Menu.EVENT.OnUnchecked);
--TODO BUG FIX make the menu show this change
                local fCallback = pri.Callbacks[sEvent];
                if (fCallback) then
                    vRet = fCallback(this);
                end

            end

            return vRet;
        end,
        SetEnabled = function(this, cdat, bFlag)
            local vRet;

            --set the item enabled/disabled
            local pri           = cdat.pri;
            local bEnabled      = rawtype(bFlag) == "boolean" and bFlag or false;
            local bWasEnabled   = pri.Enabled;
            pri.Enabled         = bEnabled;

            --if something changed, fire the callback (if present)
            if (bWasEnabled ~= bEnabled) then
                local sEvent = tostring(bEnabled and Menu.EVENT.OnEnabled or Menu.EVENT.OnDisabled);
--TODO BUG FIX make the menu show this change
                local fCallback = pri.Callbacks[sEvent];
                if (fCallback) then
                    vRet = fCallback(this);
                end

            end

            return vRet;
        end,
        SetIconID = function(this, cdat, vID)
            local vRet;

            local pri       = cdat.pri;
            local nID       = rawtype(vID) == "number" and floor(vID) or -1;
            local nOldID    = pri.IconID;

            -- update the icon ID
            pri.IconID  = nID;

            --if something changed, fire the callback (if present)
            if (nID ~= nOldID) then

                local fCallback = pri.Callbacks[tostring(Menu.EVENT.OnIconIDChanged)];

                if (fCallback) then
                    vRet = fCallback(this);
                end
            end

            return vRet;
        end,
    --[[    --TODO set path
        SetText = function(this, cdat, vText)--TODO modify path properly after text is set
            local vRet;

            local pri = cdat.pri;
            local sNewText = rawtype(vText) == "string" and vText or "";
            local sOldText = pri.Text;
            pri.Text       = sNewText; --set the new text (before checking because the ID might not change but the case of the text may)

            --if something actually changed, update the ID and fire the callback (if present)
            if (sNewText:lower() ~= sOldText:lower()) then
                pri.ID = PathToID(sNewText); --BORKEN,....should not set iD with ONLY text...changfe the last item int eh path, then set ID with that

                local fCallback = pri.Callbacks[tostring(Menu.EVENT.OnTextChanged)];
                if (fCallback) then
                    vRet = fCallback(this);
                end

            end

            return vRet;
        end,]]
        --TODO toggles
    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
