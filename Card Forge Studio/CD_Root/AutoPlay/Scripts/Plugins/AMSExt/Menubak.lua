--local ID = MenuItem.PathToID;
local SID = string.tosid;
--TODO add sorter for path level







local function NewItem()
    return {
    --    ID          = -1,
        Text        = "",
        IconID      = -1,
        IsEnabled   = true,
        IsChecked   = false,
        IsCheckable = false,
        Path        = "",
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
    };
end
















--[[
local function BuildItem(nID, sText, nIconID, bEnabled, bChecked, tSubTable)
    return {
        ID      = nID,
        Text    = sText,
        IconID  = nIconID1,
        Enabled = bEnabled,
        Checked = bChecked,
        SubMenu = tSubTable,
    };
end
]]
local function FindNodeBySID(tList, sSID)
    local tRet;

    for x = 1, #tList do

        if (tList[x].SID == sSID) then
            tRet = tList[x];
            break;
        end

    end

    return tRet;
end


local function EnsureNode(tList, sFullPath, sText)
    local sSID  = SID(sFullPath);
    local tNode = FindNodeBySID(tList, sSID);

    if not (tNode) then
        tNode = {
            ID      = -1,
            SID     = sSID,
            Text    = sText,
            IconID  = -1,
            Enabled = true,
            Checked = false,
            SubMenu = {},
        };
        tList[#tList + 1] = tNode;
    end

    tNode.SubMenu = (type(tNode.SubMenu) == "table") and tNode.SubMenu or {};

    return tNode;
end


local function ApplyItem(tNode, oItem)
    -- do NOT touch tNode.ID
    tNode.Text    = oItem.GetText();
    tNode.IconID  = oItem.GetIconID();
    tNode.Enabled = oItem.IsEnabled();
    tNode.Checked = oItem.IsChecked();
end


local eMenuEvent = enum("Menu.EVENT", { "OnEnabled",        "OnDisabled",
                                        "OnChecked",        "OnUnchecked",
                                        "OnSetCheckable",   "OnSetUncheckable",
                                        "OnSelected",       "OnIconIDChanged",  "OnTextChanged"}, nil, true);

return class("Menu",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Menu = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        EVENT = eMenuEvent,
        DELIMITER = ":>",
    },
    {--PRIVATE
        AutoUpdate__AUTO__  = true,
        AMSMenu             = {}, --the menu given to AMS
        Items               = {}, --indexed by number, item value
        ItemsByPath         = {}, --indexed by path, item value
        ItemsByID           = {}, --indexed by path, item value
        --ItemsByItem = {}, --indexed by item, boolean value
        --Callbacks --TODO consider adding some...liek OnAdd, etc. Not sure if they are needed
    },
    {--PROTECTED

    },
    {--PUBLIC
        Menu = function(this, cdat)

        end,
        Add = function(this, cdat, vPath, vIconID, vEnabled, vChecked, vCheckable, vCallbacks)

            if not (type(oMenuItem) == "MenuItem") then
                error("Error adding MenuItem to Menu. Expected type, MenuItem. Got type, "..type(oMenuItem)..'.', 2);
            end

            local pri = cdat.pri;
            pri.Items[#pri.Items + 1] = oMenuItem;
            pri.ItemsByPath[oMenuItem.GetPath()] = oMenuItem;

            if (pri.AutoUpdate) then
                this.Refresh();
            end

            return this;
        end,
        Get = function(this, cdat, sPath)
            return cdat.pri.ItemsByPath[sPath];
        end,
        GetMenu = function(this, cdat)
            return clone(cdat.pri.AMSMenu);
        end,
        OnMenu = function(this, cdat, nID, tItemInfo)
            local pri   = cdat.pri
            local oItem = pri.ItemsByID and pri.ItemsByID[nID] or nil
            if not oItem then return end

            if (oItem.IsEnabled()) then
                oItem.Select(oItem);

                if (oItem.IsCheckable()) then
                    -- TODO
                end

            end

        end,
        RefreshOLD = function(this, cdat, bSkipMenuUpdate)
            local pri           = cdat.pri;
            --reset the menu table
            pri.AMSMenu         = {};
            local sDelimiter    = Menu.DELIMITER;



            --iterate over all the menu items
            for nIndex, oItem in ipairs(pri.Items) do
                local sPath     = oItem.GetPath();
                local tSegments = sPath:totable(sDelimiter);
                local nSegments = #tSegments;
                local tList     = pri.AMSMenu;
                local sFull     = "";

                --once the path of the item us split, iterate over it, creating nodes
                for nSegmentID, sSegment in ipairs(tSegments) do
                    sFull = (sFull == "") and sSegment or (sFull .. sDelimiter .. sSegment);

                    --ensure the node exists
                    local tNode = EnsureNode(tList, sFull, sSegment);
                    --local tNode = EnsureNode(tList, sFull, sSegment);

                    if (nSegmentID == nSegments) then
                        ApplyItem(tNode, oItem);
                    end

                    tList = tNode.SubMenu;
                end

            end

            if not (bSkipMenuUpdate) then
                Application.SetMenu(pri.AMSMenu);
            end
--TextFile.WriteFromString(_Docs.."\\Menu.lua", serialize(pri.AMSMenu), false);
            return clone(pri.AMSMenu);
        end,
        --accepts a path or MenuItem
        --accepts a path or MenuItem TODO move vItem function uptop and let most methods use it for vItem lookup
        RemoveItem = function(this, cdat, vItem, bSkipRefresh) --TODO rewrite since changes to system
            local pri     = cdat.pri;
            local bRet = false;

            local oItem;
            local sPath;
            local zItem = type(vItem);

            -- normalize input
            if (zItem == "string") then
                sPath = vItem;
                oItem = pri.ItemsByPath[sPath];
            elseif (zItem == "MenuItem") then
                oItem = vItem;
                sPath = oItem.GetPath();
            end

            if (oItem ~= nil and type(sPath) == "string" and sPath ~= "") then
                -- find item index
                local nIndex;
                for i = 1, #pri.Items do
                    if (pri.Items[i] == oItem) then
                        nIndex = i;
                        break;
                    end
                end

                if (nIndex ~= nil) then
                    table.remove(pri.Items, nIndex);
                    pri.ItemsByPath[sPath] = nil;

                    if not (bSkipRefresh) then
                        this.Refresh();
                    end

                    bRet = true;
                else
                    -- keep maps consistent if partially present
                    pri.ItemsByPath[sPath] = nil;
                end
            end

            return bRet;
        end,
        Refresh = function(this, cdat)
            local pri        = cdat.pri;
            pri.AMSMenu      = {};
            local sDelimiter = Menu.DELIMITER;

            -- AMS-safe command ID band (you already found MAX issues)
            local nNextID    = 1000;
            local nMaxID     = 31000;

            -- optional: fast dispatch map (ID -> MenuItem)
            pri.ItemsByID = {};

            for _, oItem in ipairs(pri.Items) do
                local sPath     = oItem.GetPath();
                local tSegments = sPath:totable(sDelimiter);
                local nSegments = #tSegments;
                local tList     = pri.AMSMenu;
                local sFull     = "";

                for nSegmentID, sSegment in ipairs(tSegments) do
                    sFull = (sFull == "") and sSegment or (sFull .. sDelimiter .. sSegment);

                    local tNode = EnsureNode(tList, sFull, sSegment);

                    if (nSegmentID == nSegments) then
                        -- assign AMS command ID HERE (leaf only)
                        if (nNextID >= nMaxID) then
                            error("Menu.Refresh: Out of AMS-safe menu IDs (>= "..tostring(nMaxID)..")", 2);
                        end

                        tNode.ID = nNextID;

                        -- keep the MenuItem in sync (needs MenuItem.SetID / or direct field)
                        if (oItem.SetID) then
                            oItem.SetID(nNextID);
                        end

                        -- your existing fields
                        ApplyItem(tNode, oItem);

                        -- dispatch map
                        pri.ItemsByID[nNextID] = oItem;

                        nNextID = nNextID + 1;
                    end

                    tList = tNode.SubMenu;
                end
            end

            if (pri.AutoUpdate) then
                Application.SetMenu(pri.AMSMenu)
            end

            return clone(pri.AMSMenu)
        end

    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
