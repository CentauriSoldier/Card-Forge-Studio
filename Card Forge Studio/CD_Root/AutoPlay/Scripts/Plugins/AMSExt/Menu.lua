--local ID = MenuItem.PathToID;
local SID = string.tosid;
--TODO add sorter for path level


local eMenuEvent = enum("Menu.EVENT", { "OnEnabled",        "OnDisabled",
                                        "OnChecked",        "OnUnchecked",
                                        "OnSetCheckable",   "OnSetUncheckable",
                                        "OnSelected",       "OnIconIDChanged",  "OnTextChanged"}, nil, true);


local function sink() end

local function NewItem()
    return {
        Callbacks           = {
            [eMenuEvent.OnChecked]           = sink,
            [eMenuEvent.OnUnchecked]         = sink,
            [eMenuEvent.OnEnabled]           = sink,
            [eMenuEvent.OnDisabled]          = sink,
            [eMenuEvent.OnSetCheckable]      = sink,
            [eMenuEvent.OnSetUncheckable]    = sink,
            [eMenuEvent.OnIconIDChanged]     = sink,
            [eMenuEvent.OnSelected]          = sink,
            [eMenuEvent.OnTextChanged]       = sink,
        },
        IconID      = -1,
        IsEnabled   = true,
        IsChecked   = false,
        IsCheckable = false,
        Path        = "",
        Text        = "",
    };
end


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
            local pri = cdat.pri;

            local tItem = NewItem();
            --set the path and text
            local sPath     = rawtype(vPath)        == "string"     and vPath           or "";

            if (sPath:isempty()) then
                error("Menu.Add: path cannot be empty.", 2);
            end

            tItem.Path      = sPath;
            local tText     = sPath:totable(Menu.DELIMITER) or {};
            local sText     = tText[#tText] or "";
            tItem.Text      = sText;
            tItem.IconID    = rawtype(vIconID)      == "number"     and math.floor(vIconID)  or -1;

            if (rawtype(vEnabled) == "boolean") then
                tItem.IsEnabled = vEnabled;
            else
                tItem.IsEnabled = true;
            end
            tItem.IsChecked      = rawtype(vChecked)     == "boolean"    and vChecked        or false;
            tItem.IsCheckable    = rawtype(vCheckable)   == "boolean"    and vCheckable      or false;

            if (type(vCallbacks) == "table") then

                for eMenuEvent, fCallback in pairs(vCallbacks) do

                    if not (type(eMenuEvent) == "Menu.EVENT") then
                        error("Error importing callback in Menu. Expected type Menu.EVENT. Got "..type(eMenuEvent)..'.', 3);
                    end

                    if not (type(fCallback) == "function") then
                        error("Error importing callback in Menu. Expected type function. Got "..type(fCallback)..'.', 3);
                    end

                    tItem.Callbacks[eMenuEvent] = fCallback;
                end

            end

            pri.Items[#pri.Items + 1] = tItem;
            pri.ItemsByPath[tItem.Path] = tItem;

            if (pri.AutoUpdate) then
                this.Refresh();
            end

            return this;
        end,

        ClearChildren = function(this, cdat, sPath)
            local pri = cdat.pri;

            if not (rawtype(sPath) == "string" and not sPath:isempty()) then
                error("Menu.ClearChildren: path must be a non-empty string. Got "..tostring(sPath)..'('..type(sPath)..')', 2);
            end

            local tRoot = pri.ItemsByPath[sPath];
            if not tRoot then
                return 0; --nothing to clear
            end

            local sDelim   = Menu.DELIMITER;
            local sPrefix  = sPath..sDelim;
            local nPrefixL = #sPrefix;

            local tNewItems = {};
            local nRemoved  = 0;

            for i = 1, #pri.Items do
                local tItem = pri.Items[i];
                local p     = tItem.Path;

                if (p == sPath) then
                    -- keep the node itself
                    tNewItems[#tNewItems + 1] = tItem;

                elseif (rawtype(p) == "string" and p:sub(1, nPrefixL) == sPrefix) then
                    -- remove descendants
                    pri.ItemsByPath[p] = nil;
                    nRemoved = nRemoved + 1;

                else
                    -- keep unrelated items
                    tNewItems[#tNewItems + 1] = tItem;
                end
            end

            pri.Items = tNewItems;

            if (pri.AutoUpdate) then
                this.Refresh();
            end

            return nRemoved;
        end,


        GetItem = function(this, cdat, sPath)
            return clone(cdat.pri.ItemsByPath[sPath]);
        end,

        GetMenu = function(this, cdat)
            return clone(cdat.pri.AMSMenu);
        end,

        IsEnabled = function(this, cdat, vPath)
            local tItem = cdat.pri.ItemsByPath[vPath]
            if not tItem then
                error("Menu.IsEnabled: No menu item at path: "..tostring(vPath), 2)
            end
            return tItem.IsEnabled
        end,

        IsChecked = function(this, cdat, vPath)
            local tItem = cdat.pri.ItemsByPath[vPath]
            if not tItem then
                error("Menu.IsChecked: No menu item at path: "..tostring(vPath), 2)
            end
            return tItem.IsCheckable and tItem.IsChecked or false
        end,

        IsCheckable = function(this, cdat, vPath)
            local tItem = cdat.pri.ItemsByPath[vPath]
            if not tItem then
                error("Menu.IsCheckable: No menu item at path: "..tostring(vPath), 2)
            end
            return tItem.IsCheckable
        end,

        OnMenu = function(this, cdat, nID, tItemInfo)
            local pri   = cdat.pri;
            local tItem = pri.ItemsByID[nID] or nil;
            if not tItem then return end

            if (tItem.IsEnabled) then
                tItem.Callbacks[eMenuEvent.OnSelected](clone(tItem));

                if (tItem.IsCheckable) then
                    local bChecked  = tItem.IsChecked;
                    local eEvent    = bChecked and eMenuEvent.OnUnchecked or eMenuEvent.OnChecked;
                    tItem.IsChecked = not bChecked;
                    this.Refresh();
                    tItem.Callbacks[eEvent](clone(tItem));
                end

            end

        end,
        --accepts a path or MenuItem
        --accepts a path or MenuItem TODO move vItem function uptop and let most methods use it for vItem lookup
        RemoveOLD = function(this, cdat, vItem, bSkipRefresh) --TODO rewrite since changes to system
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
            local nNextID    = 1;
            local nMaxID     = 31000;

            -- optional: fast dispatch map (ID -> MenuItem)
            pri.ItemsByID = {};

            for _, tItem in ipairs(pri.Items) do
                local sPath     = tItem.Path;
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

                        tNode.ID      = nNextID;
                        tNode.Text    = tItem.Text;
                        tNode.IconID  = tItem.IconID;
                        tNode.Enabled = tItem.IsEnabled;
                        tNode.Checked = tItem.IsCheckable and tItem.IsChecked;

                        pri.ItemsByID[nNextID] = tItem;

                        nNextID = nNextID + 1;
                    end

                    tList = tNode.SubMenu;
                end
            end

            if (pri.AutoUpdate) then
                Application.SetMenu(pri.AMSMenu)
            end

            return clone(pri.AMSMenu)
        end,
        Remove = function(this, cdat, sPath)
            local pri = cdat.pri

            if not (rawtype(sPath) == "string" and not sPath:isempty()) then
                error("Menu.Remove: path must be a non-empty string. Got "..tostring(sPath)..'('..type(sPath)..')', 2);
            end

            local tItem = pri.ItemsByPath[sPath]
            if not tItem then
                return false
            end

            -- remove from list
            for i = 1, #pri.Items do
                if (pri.Items[i] == tItem) then
                    table.remove(pri.Items, i)
                    break
                end
            end

            -- remove from map
            pri.ItemsByPath[sPath] = nil

            if (pri.AutoUpdate) then
                this.Refresh()
            end

            return true
        end,
        SetCallback = function(this, cdat, sPath, eMenuEvent, fCallback)
            local pri = cdat.pri;

            if not (rawtype(sPath) == "string" and not sPath:isempty()) then
                error("Menu.SetCallback: path must be a non-empty string. Got "..tostring(sPath)..'('..type(sPath)..')', 2);
            end

            local tItem = pri.ItemsByPath[sPath];
            if not tItem then
                error("Menu.SetCallback: No menu item exists at path: "..sPath, 2);
            end

            if not (type(eMenuEvent) == "Menu.EVENT") then
                error("Menu.SetCallback: Expected type Menu.EVENT. Got "..type(eMenuEvent)..'.', 2);
            end

            if not (type(fCallback) == "function") then
                error("Menu.SetCallback: Expected type function. Got "..type(fCallback)..'.', 2);
            end

            tItem.Callbacks[eMenuEvent] = fCallback;

            if (pri.AutoUpdate) then
                this.Refresh();
            end

            return this;
        end,
        SetEnabled = function(this, cdat, vPath, bFlag, bSkipCallback)
            local pri   = cdat.pri;
            local tItem = pri.ItemsByPath[vPath];

            if not tItem then
                error("Menu.SetEnabled: No menu item at path: "..tostring(vPath), 2);
            end

            local bNew = rawtype(bFlag) == "boolean" and bFlag or false;
            if (tItem.IsEnabled ~= bNew) then
                tItem.IsEnabled = bNew;
                if (pri.AutoUpdate) then this.Refresh() end

                if not (bSkipCallback) then
                    tItem.Callbacks[bNew and eMenuEvent.OnEnabled or eMenuEvent.OnDisabled](clone(tItem));
                end

            end

            return this;
        end,

        SetChecked = function(this, cdat, vPath, bFlag, bSkipCallback)
            local pri   = cdat.pri;
            local tItem = pri.ItemsByPath[vPath];

            if not tItem then
                error("Menu.SetChecked: No menu item at path: "..tostring(vPath), 2);
            end

            if not tItem.IsCheckable then return this end

            local bNew = rawtype(bFlag) == "boolean" and bFlag or false;
            if (tItem.IsChecked ~= bNew) then
                tItem.IsChecked = bNew;
                if (pri.AutoUpdate) then this.Refresh() end

                if not (bSkipCallback) then
                    tItem.Callbacks[bNew and eMenuEvent.OnChecked or eMenuEvent.OnUnchecked](clone(tItem));
                end

            end

            return this;
        end,

        SetCheckable = function(this, cdat, vPath, bFlag, bSkipCallback)
            local pri   = cdat.pri;
            local tItem = pri.ItemsByPath[vPath];

            if not tItem then
                error("Menu.SetCheckable: No menu item at path: "..tostring(vPath), 2);
            end

            local bNew = rawtype(bFlag) == "boolean" and bFlag or false;
            if (tItem.IsCheckable ~= bNew) then
                tItem.IsCheckable = bNew;

                if not bNew then
                    tItem.IsChecked = false;
                end

                if (pri.AutoUpdate) then this.Refresh() end

                if not (bSkipCallback) then
                    tItem.Callbacks[bNew and eMenuEvent.OnSetCheckable or eMenuEvent.OnSetUncheckable](clone(tItem));
                end

            end

            return this;
        end,

    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
