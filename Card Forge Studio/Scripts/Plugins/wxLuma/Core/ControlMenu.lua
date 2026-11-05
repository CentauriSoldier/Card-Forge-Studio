local _wx          = require("wx");
local _Object      = require("wxLuma.Core.ControlObject");
local _Events      = require("wxLuma.Core.ControlEvents");
local _Containment = require("wxLuma.Core.ControlContainment");
local _Layout      = require("wxLuma.Core.MenuLayout");
local _Renderer    = require("wxLuma.Core.MenuRenderer");
local _finite      = require("wxLuma.Core.ControlNumeric").finite;
local ControlMenu  = {};

local function copyArray(tValues)
    local tCopy = {};

    for nIndex, vValue in ipairs(tValues) do
        tCopy[nIndex] = vValue;
    end

    return tCopy;
end

-- Copy structure while retaining application-owned Value identity. Cycles and
-- duplicate IDs are rejected by normalization before changing any live menu.
local function copyItems(tItems, tAncestors)
    assert(type(tItems) == "table", "Menu Items must be an array.");
    tAncestors = tAncestors or {};
    assert(not tAncestors[tItems], "Cyclic menu hierarchy.");
    tAncestors[tItems] = true;
    local tCopy = {};

    for vKey in pairs(tItems) do
        assert(type(vKey) == "number" and vKey % 1 == 0 and vKey >= 1 and vKey <= #tItems,
            "Menu Items must be a dense array.");
    end

    for nIndex = 1, #tItems do
        local tItem = tItems[nIndex];
        assert(type(tItem) == "table", "Menu items must be records.");
        local tNew = {};

        for _, sKey in ipairs({"Id", "Text", "Image", "Shape", "Width", "Height", "ImageWidth",
            "ImageHeight", "ClipImage", "Enabled", "Artwork", "Value"}) do
            tNew[sKey] = tItem[sKey];
        end

        if (tItem.Items ~= nil) then
            tNew.Items = copyItems(tItem.Items, tAncestors);
        end

        tCopy[nIndex] = tNew;
    end

    tAncestors[tItems] = nil;
    return tCopy;
end

--[[!
@fqxn wxLuma.UI.ControlMenu.create
@desc Composes a public popup menu object, shared native events, containment,
    measured pages, shaped item rendering and bounded caches. No nested event loop
    is used: completed selection is delivered through OnSelect/on/getSelection.
@param wxWindow|table oParent Lifetime/containment parent.
@param table tOptions Skin, Items, OnSelect and documented widget-specific options.
@param string sKind ContextMenu or RadialMenu.
@ret table oMenu Independent public actual/decoy/metatable object.
!]]
function ControlMenu.create(oParent, tOptions, sKind)
    assert(sKind == "ContextMenu" or sKind == "RadialMenu", "Invalid menu kind.");
    assert(type(tOptions) == "table" and tOptions.Skin, "Menus require Skin.");
    assert(tOptions.OnSelect == nil or type(tOptions.OnSelect) == "function", "OnSelect must be a function.");
    oParent = _Containment.native(oParent);
    local bRadial = sKind == "RadialMenu";
    local tConfig = {
        Direction  = tOptions.Direction or "CW",
        StartAngle = tOptions.StartAngle == nil and 0 or tOptions.StartAngle,
        Spacing    = tOptions.Spacing == nil and (bRadial and 12 or 2) or tOptions.Spacing,
        MinRadius  = tOptions.MinRadius == nil and 64 or tOptions.MinRadius,
        MaxRadius  = tOptions.MaxRadius == nil and 160 or tOptions.MaxRadius,
        Shape      = tOptions.Shape or "circle",
        ItemWidth  = tOptions.ItemWidth or (bRadial and 64 or 232),
        ItemHeight = tOptions.ItemHeight or (bRadial and 64 or 40),
        Width      = tOptions.Width or 240
    };
    local sArtwork = tOptions.Artwork or "Menu";
    assert(type(sArtwork) == "string" and sArtwork:find("%S"), "Invalid menu Artwork.");
    assert(tConfig.Direction == "CW" or tConfig.Direction == "CCW", "Direction must be CW or CCW.");
    assert(_finite(tConfig.StartAngle), "StartAngle must be finite.");
    tConfig.StartAngle = tConfig.StartAngle % 360;
    assert(_finite(tConfig.Spacing) and tConfig.Spacing >= 0, "Spacing must be nonnegative and finite.");
    assert(_finite(tConfig.MinRadius) and _finite(tConfig.MaxRadius) and tConfig.MinRadius >= 0
        and tConfig.MaxRadius >= tConfig.MinRadius, "Invalid menu radius range.");
    assert(tConfig.Shape == "circle" or tConfig.Shape == "diamond" or tConfig.Shape == "square", "Invalid menu shape.");

    for _, sKey in ipairs({"ItemWidth", "ItemHeight", "Width"}) do
        assert(_finite(tConfig[sKey]) and tConfig[sKey] >= 16 and tConfig[sKey] % 1 == 0,
            "Menu dimensions must be integer pixels, at least 16.");
    end

    assert(tOptions.Enabled == nil or type(tOptions.Enabled) == "boolean", "Enabled must be boolean.");
    assert(tOptions.Direction == nil or tOptions.Direction == "CW" or tOptions.Direction == "CCW", "Invalid Direction.");
    assert(tOptions.Shape == nil or tOptions.Shape == "circle" or tOptions.Shape == "diamond"
        or tOptions.Shape == "square", "Invalid Shape.");
    assert(tOptions.Artwork == nil or (type(tOptions.Artwork) == "string" and tOptions.Artwork:find("%S")), "Invalid Artwork.");

    for _, sKey in ipairs({"ItemWidth", "ItemHeight", "Width"}) do
        assert(tOptions[sKey] == nil or _finite(tOptions[sKey]), "Invalid menu dimension.");
    end

    local tRaw = copyItems(tOptions.Items or {});
    local function fNormalize(tSource, tSeen)
        tSeen = tSeen or {};
        local tItems = {};

        for nIndex, tItem in ipairs(tSource) do
            assert(type(tItem.Id) == "string" and tItem.Id ~= "" and tItem.Id:sub(1, 2) ~= "__"
                and not tSeen[tItem.Id], "Menu IDs must be unique nonempty strings without __ prefix.");
            tSeen[tItem.Id] = true;
            assert(tItem.Shape == nil or tItem.Shape == "circle" or tItem.Shape == "diamond"
                or tItem.Shape == "square", "Invalid item Shape.");

            for _, sKey in ipairs({"Width", "Height", "ImageWidth", "ImageHeight"}) do
                assert(tItem[sKey] == nil or _finite(tItem[sKey]), "Invalid item dimension.");
            end

            local tNew = {
                Id = tItem.Id, Text = tItem.Text == nil and (tItem.Image and "" or tItem.Id) or tItem.Text,
                Image = tItem.Image, Shape = tItem.Shape or tConfig.Shape,
                Width = tItem.Width or tConfig.ItemWidth, Height = tItem.Height or tConfig.ItemHeight,
                ClipImage = tItem.ClipImage ~= false, Enabled = tItem.Enabled ~= false,
                Artwork = tItem.Artwork, Value = tItem.Value
            };
            assert(type(tNew.Text) == "string" and (tNew.Image == nil or type(tNew.Image) == "string"), "Invalid menu text/image.");
            assert(tItem.ClipImage == nil or type(tItem.ClipImage) == "boolean", "ClipImage must be boolean.");
            assert(tItem.Enabled == nil or type(tItem.Enabled) == "boolean", "Enabled must be boolean.");
            assert(tNew.Shape == "circle" or tNew.Shape == "diamond" or tNew.Shape == "square", "Invalid item shape.");
            assert(tNew.Artwork == nil or (type(tNew.Artwork) == "string" and tNew.Artwork:find("%S")), "Invalid item Artwork.");
            tNew.ImageWidth = tItem.ImageWidth or (bRadial and tNew.Width or 24);
            tNew.ImageHeight = tItem.ImageHeight or (bRadial and tNew.Height or 24);

            for _, sKey in ipairs({"Width", "Height", "ImageWidth", "ImageHeight"}) do
                assert(_finite(tNew[sKey]) and tNew[sKey] >= 16 and tNew[sKey] % 1 == 0,
                    "Item dimensions must be integer pixels, at least 16.");
            end

            if (tItem.Items) then
                tNew.Items = fNormalize(tItem.Items, tSeen);
            end

            tItems[nIndex] = tNew;
        end

        return tItems;
    end
    local tRoot = fNormalize(tRaw);
    local nStyle = _wx.wxFRAME_NO_TASKBAR + _wx.wxFRAME_FLOAT_ON_PARENT + _wx.wxBORDER_NONE;

    if (bRadial and _wx.wxFRAME_SHAPED) then
        nStyle = nStyle + _wx.wxFRAME_SHAPED;
    end

    local oPopup = _wx.wxFrame(oParent, _wx.wxID_ANY, "", _wx.wxDefaultPosition, _wx.wxDefaultSize, nStyle);
    local oCanvas = _wx.wxPanel(oPopup, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxBORDER_NONE + _wx.wxWANTS_CHARS);
    oCanvas:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    oCanvas:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    local oMenu = _Object.create({Control = oCanvas, Popup = oPopup, Skin = tOptions.Skin,
        Kind = sKind, Disposed = false, Enabled = tOptions.Enabled ~= false, OnSelect = tOptions.OnSelect}, "wxLuma.UI."..sKind);
    local tEvents, tPolicy, tRenderer;
    local tPage, tPlan, tRootPlan, tSelection;
    local tHistory, tBindings = {}, {};
    local nHover, nFocus, nDown = 0, 0, 0;
    local nRequestedX, nRequestedY, nLocalX, nLocalY;
    local oOpenTarget;
    local nTargetX, nTargetY;
    local bOpen = false;
    local fReflow;

    --[[!
    @fqxn wxLuma.UI.ControlMenu.isEnabled
    @desc Reports availability including the native lifetime parent's enabled state.
    !]]
    function oMenu.isEnabled()
        return not oMenu.Disposed and oMenu.Enabled and not oParent:IsBeingDeleted() and oParent:IsEnabled() and oCanvas:IsEnabled();
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.refresh
    @desc Invalidates the live menu canvas without modifying menu state.
    !]]
    function oMenu.refresh()
        if (not oMenu.Disposed) then
            oCanvas:Refresh(false);
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.isOpen
    @desc Reports whether the popup is currently open.
    !]]
    function oMenu.isOpen()
        return not oMenu.Disposed and bOpen;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.cancel
    @desc Releases incomplete pointer capture without selecting an action.
    !]]
    function oMenu.cancel()
        nDown = 0;

        if (not oCanvas:IsBeingDeleted() and oCanvas:HasCapture()) then
            oCanvas:ReleaseMouse();
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.close
    @desc Dismisses the menu. Cancellation leaves getSelection nil for this opening;
        action activation sets its result before invoking callbacks.
    @param string|nil sReason Optional dismissal reason.
    @ret table oMenu This menu.
    !]]
    function oMenu.close(sReason)
        if (bOpen) then
            bOpen = false;
            oMenu.cancel();
            nHover, nFocus = 0, 0;
            oOpenTarget = nil;
            tHistory = {};
            tPage = {Source = tRoot, Start = 1, Path = {}};
            tPlan = tRootPlan;
            oPopup:Show(false);
            tEvents.emit("closed", {Reason = sReason or "cancelled"});
        end

        return oMenu;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.setEnabled
    @desc Changes availability, dismissing an open menu when disabled.
    !]]
    function oMenu.setEnabled(bEnabled)
        assert(type(bEnabled) == "boolean", "Enabled must be boolean.");

        if (not oMenu.Disposed) then
            oMenu.Enabled = bEnabled;
            oCanvas:Enable(bEnabled);

            if (not bEnabled) then
                oMenu.close("disabled");
            end
        end

        return oMenu;
    end

    local function fSystem(sRole)
        return {Id = "__"..sRole, Role = sRole, Text = sRole == "back" and "Back" or "More",
            Width = tConfig.ItemWidth, Height = tConfig.ItemHeight, ImageWidth = tConfig.ItemWidth,
            ImageHeight = tConfig.ItemHeight, ClipImage = true, Shape = tConfig.Shape, Enabled = true};
    end

    -- Reserve navigation before displaying anything. Overflow always advances by
    -- at least one real item, preventing endless Back/More-only pagination loops.
    local function fPrepare(tSource, nStart, bBack)
        local tBounds = oMenu.getContainmentBounds();

        if (not tBounds) then
            return nil, "containment is not visible";
        end

        local nAvailableWidth, nAvailableHeight = tBounds.Width, tBounds.Height;

        if (oMenu.getContainmentOverflow() == "allow") then
            local nMaxWidth, nMaxHeight, nRowHeight = tConfig.ItemWidth, tConfig.ItemHeight, 8;

            for _, tItem in ipairs(tSource) do
                local nWidth, nHeight = _Layout.footprint(tItem);
                nMaxWidth, nMaxHeight = math.max(nMaxWidth, nWidth), math.max(nMaxHeight, nHeight);
                nRowHeight = nRowHeight + nHeight + math.ceil(tConfig.Spacing);
            end

            nAvailableWidth = math.max(nAvailableWidth, nMaxWidth + 8,
                bRadial and 2 * tConfig.MaxRadius + nMaxWidth + 8 or tConfig.Width);
            nAvailableHeight = math.max(nAvailableHeight,
                bRadial and 2 * tConfig.MaxRadius + nMaxHeight + 8 or nRowHeight + 2 * tConfig.ItemHeight + 8);
        end

        local nRemaining = #tSource - nStart + 1;
        local nBound = _Layout.capacityBound(tSource, tConfig, bRadial, nAvailableHeight);
        local fLayout = bRadial and _Layout.radial or _Layout.context;
        local function fCandidate(nCount, bMore)
            local tItems = {};

            if (bBack) then
                tItems[#tItems + 1] = fSystem("back");
            end

            for nIndex = nStart, nStart + nCount - 1 do
                tItems[#tItems + 1] = tSource[nIndex];
            end

            if (bMore) then
                tItems[#tItems + 1] = fSystem("overflow");
            end

            local tLayout = fLayout(tItems, tConfig, nAvailableWidth, nAvailableHeight);

            if (tLayout) then
                tLayout.Count = nCount;
                return tLayout;
            end
        end

        if (nRemaining <= 0) then
            if (bBack) then
                return fCandidate(0, false), "items cannot fit";
            end

            return nil, "menu is empty";
        end

        if (nRemaining + (bBack and 1 or 0) <= nBound) then
            local tAll = fCandidate(nRemaining, false);

            if (tAll) then
                return tAll;
            end
        end

        for nCount = math.min(nRemaining - 1, nBound - (bBack and 1 or 0) - 1), 1, -1 do
            local tFit = fCandidate(nCount, true);

            if (tFit) then
                return tFit;
            end
        end

        return nil, "items cannot fit: increase radius/container space or reduce item size/spacing";
    end

    -- Check every overflow page before opening a branch. No More button may
    -- lead to a dead end that cannot reserve Back and at least one real choice.
    local function fPrepareReachable(tSource, nStart, bBack)
        local tFirst, sReason = fPrepare(tSource, nStart, bBack);

        if (not tFirst) then
            return nil, sReason;
        end

        local nNext = nStart + tFirst.Count;

        while (nNext <= #tSource) do
            local tNext;
            tNext, sReason = fPrepare(tSource, nNext, true);

            if (not tNext or tNext.Count < 1) then
                return nil, sReason or "overflow page cannot fit";
            end

            nNext = nNext + tNext.Count;
        end

        return tFirst;
    end

    local function fPlace()
        if (not tPlan) then
            return false;
        end

        return tPolicy.place(oPopup, {X = nRequestedX - tPlan.AnchorX, Y = nRequestedY - tPlan.AnchorY});
    end

    local function fApply(tNewPlan, tNewPage)
        oMenu.cancel();
        tPlan, tPage = tNewPlan, tNewPage;

        if (#tHistory == 0 and tPage.Source == tRoot and tPage.Start == 1) then
            tRootPlan = tPlan;
        end

        nHover, nFocus = 0, 0;
        oPopup:SetClientSize(tPlan.Width, tPlan.Height);
        oCanvas:SetSize(0, 0, tPlan.Width, tPlan.Height);

        for nIndex, tEntry in ipairs(tPlan.Entries) do
            if (tEntry.Item.Enabled and nFocus == 0) then
                nFocus = nIndex;
            end
        end

        if (bRadial and oPopup.SetShape and _wx.wxFRAME_SHAPED) then
            local oRegion = _wx.wxRegion();

            for _, tEntry in ipairs(tPlan.Entries) do
                local tItem = tEntry.Item;
                local nX = tEntry.X + math.floor((tEntry.Width - tItem.Width) / 2);
                local nY = tEntry.Y + math.floor((tEntry.Height - tItem.Height) / 2);
                local oItemRegion = _Renderer.region(tItem.Shape, nX - 1, nY - 1, tItem.Width + 2, tItem.Height + 2);
                oRegion:Union(oItemRegion);
                oItemRegion:delete();

                if (tItem.Image and not tItem.ClipImage) then
                    oRegion:Union(tEntry.X, tEntry.Y, tEntry.Width, tEntry.Height);
                end
            end

            oPopup:SetShape(oRegion);
            oRegion:delete();
        end

        fPlace();
        oMenu.refresh();
    end

    fReflow = function()
        if (bOpen) then
            local tNew, sReason = fPrepareReachable(tPage.Source, tPage.Start, #tHistory > 0);

            if (not tNew) then
                oMenu.close("layout failed");
                tEvents.emit("layoutFailed", {Reason = sReason});
            else
                fApply(tNew, tPage);
            end
        end
    end;

    --[[!
    @fqxn wxLuma.UI.ControlMenu.showAt
    @desc Opens at screen coordinates. Context menus start at that point; radial
        menus center their virtual ring there. Containment minimally shifts it.
    @param number nX Screen X.
    @param number nY Screen Y.
    @ret boolean bOpened Whether the menu opened.
    @ret string|nil sReason Failure explanation; no item is shrunk or dropped.
    !]]
    function oMenu.showAt(nX, nY)
        assert(_finite(nX) and _finite(nY), "Menu anchor must be finite screen coordinates.");

        if (not oMenu.isEnabled() or not oParent:IsShownOnScreen()) then
            return false, "menu or parent is unavailable";
        end

        local tNew, sReason = fPrepareReachable(tRoot, 1, false);

        if (not tNew) then
            tEvents.emit("layoutFailed", {Reason = sReason});
            return false, sReason;
        end

        nRequestedX, nRequestedY = nX, nY;
        local oOrigin = oParent:ClientToScreen(_wx.wxPoint(0, 0));
        nLocalX, nLocalY = nX - oOrigin:GetX(), nY - oOrigin:GetY();
        tHistory, tSelection = {}, nil;
        oMenu.Value = nil;
        oOpenTarget = nil;
        fApply(tNew, {Source = tRoot, Start = 1, Path = {}});

        if (not fPlace()) then
            return false, "popup cannot be placed inside containment";
        end

        bOpen = true;
        oPopup:Show(true);
        oPopup:Raise();
        oCanvas:SetFocus();
        tEvents.emit("opened", {Anchor = oMenu.getAnchor()});
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.showAtObject
    @desc Opens at a native/visual object's screen-space center.
    !]]
    function oMenu.showAtObject(vTarget)
        local oTarget = _Containment.native(vTarget);
        local nWidth, nHeight = oTarget:GetClientSizeWH();
        local oPoint = oTarget:ClientToScreen(_wx.wxPoint(math.floor(nWidth / 2), math.floor(nHeight / 2)));
        local bOpened, sReason = oMenu.showAt(oPoint:GetX(), oPoint:GetY());

        if (bOpened) then
            oOpenTarget = oTarget;
            nTargetX, nTargetY = math.floor(nWidth / 2), math.floor(nHeight / 2);
        end

        return bOpened, sReason;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.setAnchor
    @desc Moves the requested screen anchor without resetting submenu/overflow
        history. Containment adjusts the resulting popup position minimally.
    !]]
    function oMenu.setAnchor(nX, nY)
        assert(_finite(nX) and _finite(nY), "Menu anchor must be finite screen coordinates.");

        if (not oMenu.Disposed) then
            nRequestedX, nRequestedY = nX, nY;
            local oOrigin = oParent:ClientToScreen(_wx.wxPoint(0, 0));
            nLocalX, nLocalY = nX - oOrigin:GetX(), nY - oOrigin:GetY();

            if (bOpen and not fPlace()) then
                oMenu.close("anchor unavailable");
            end
        end

        return oMenu;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.getAnchor
    @desc Returns the effective screen anchor after minimal containment movement.
    !]]
    function oMenu.getAnchor()
        if (not tPlan or oMenu.Disposed) then
            return nil;
        end

        local nX, nY = oPopup:GetPositionXY();
        return {X = nX + tPlan.AnchorX, Y = nY + tPlan.AnchorY};
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.getSelection
    @desc Returns the completed action snapshot, or nil after opening/cancellation.
        Value retains application identity; Path contains only real menu item IDs.
    !]]
    function oMenu.getSelection()
        return tSelection and {Id = tSelection.Id, Value = tSelection.Value, Text = tSelection.Text,
            Path = copyArray(tSelection.Path)} or nil;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.getValue
    @desc Returns the completed action ID, or nil when no action was chosen.
    !]]
    function oMenu.getValue()
        return oMenu.Value;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.getFocusedItem
    @desc Returns the current enabled keyboard target's ID, or nil when closed.
    !]]
    function oMenu.getFocusedItem()
        local tEntry = bOpen and tPlan and tPlan.Entries[nFocus];
        return tEntry and tEntry.Item.Id or nil;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.getLayout
    @desc Returns an independent geometry snapshot for inspection/tooling.
    !]]
    function oMenu.getLayout()
        if (not tPlan) then
            return nil;
        end

        local tCopy = {Width = tPlan.Width, Height = tPlan.Height, AnchorX = tPlan.AnchorX,
            AnchorY = tPlan.AnchorY, Radius = tPlan.Radius, Depth = #tHistory, Entries = {}};

        for nIndex, tEntry in ipairs(tPlan.Entries) do
            tCopy.Entries[nIndex] = {Id = tEntry.Item.Id, Role = tEntry.Item.Role,
                X = tEntry.X, Y = tEntry.Y, Width = tEntry.Width, Height = tEntry.Height,
                Shape = bRadial and tEntry.Item.Shape or "rectangle", Enabled = tEntry.Item.Enabled};
        end

        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.back
    @desc Restores the immediately preceding submenu/overflow page without selecting.
    @ret boolean bReturned Whether a prior page was restored.
    !]]
    function oMenu.back()
        if (not bOpen or #tHistory == 0) then
            return false;
        end

        local tPrevious = tHistory[#tHistory];
        local tNew, sReason = fPrepareReachable(tPrevious.Source, tPrevious.Start, #tHistory > 1);

        if (not tNew) then
            return false, sReason;
        end

        table.remove(tHistory);
        fApply(tNew, tPrevious);
        tEvents.emit("pageChanged", {Reason = "back", Depth = #tHistory});
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.activateItem
    @desc Activates an enabled visible item. Submenu/More replaces the current page;
        Back restores it. An action closes the popup before notifying selection.
    @param string sId Visible item ID, including __back/__overflow from layout.
    @ret boolean bActivated Whether the action/navigation succeeded.
    @ret table|string|nil vResult Action snapshot or a navigation failure reason.
    !]]
    function oMenu.activateItem(sId)
        if (not bOpen or not oMenu.isEnabled()) then
            return false;
        end

        local tItem;

        for _, tEntry in ipairs(tPlan.Entries) do
            if (tEntry.Item.Id == sId) then
                tItem = tEntry.Item;
                break;
            end
        end

        if (not tItem or not tItem.Enabled) then
            return false;
        end

        if (tItem.Role == "back") then
            return oMenu.back();
        elseif (tItem.Items or tItem.Role == "overflow") then
            local tNext;

            if (tItem.Role == "overflow") then
                tNext = {Source = tPage.Source, Start = tPage.Start + tPlan.Count, Path = copyArray(tPage.Path)};
            else
                local tPath = copyArray(tPage.Path);
                tPath[#tPath + 1] = tItem.Id;
                tNext = {Source = tItem.Items, Start = 1, Path = tPath};
            end

            local tNew, sReason = fPrepareReachable(tNext.Source, tNext.Start, true);

            if (not tNew) then
                tEvents.emit("layoutFailed", {Reason = sReason, Id = sId});
                return false, sReason;
            end

            tHistory[#tHistory + 1] = tPage;
            fApply(tNew, tNext);
            tEvents.emit("pageChanged", {Reason = tItem.Role or "submenu", Id = sId, Depth = #tHistory});
            return true;
        end

        local tPath = copyArray(tPage.Path);
        tPath[#tPath + 1] = tItem.Id;
        tSelection = {Id = tItem.Id, Value = tItem.Value, Text = tItem.Text, Path = tPath};
        oMenu.Value = tItem.Id;
        local tResult = oMenu.getSelection();
        oMenu.close("selected");
        -- Callback-local snapshots survive listeners reopening or destroying this
        -- menu. Never reread mutable current selection after notifying a listener.
        tEvents.emit("selected", {Id = tResult.Id, Selection = {
            Id = tResult.Id, Value = tResult.Value, Text = tResult.Text, Path = copyArray(tResult.Path)
        }});
        tEvents.emit("valueChanged", {Value = tResult.Id});

        if (oMenu.OnSelect) then
            oMenu.OnSelect({Id = tResult.Id, Value = tResult.Value, Text = tResult.Text,
                Path = copyArray(tResult.Path)}, oMenu);
        end

        return true, tResult;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.getItems
    @desc Returns independent descriptor structure; application Value is not cloned.
    !]]
    function oMenu.getItems()
        return copyItems(tRaw);
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.setItems
    @desc Atomically validates/replaces the hierarchy, then dismisses existing pages.
    !]]
    function oMenu.setItems(tItems, bNotify)
        assert(not oMenu.Disposed, "Cannot change a disposed menu.");
        local tCopy = copyItems(tItems);
        local tNewRoot = fNormalize(tCopy);
        oMenu.close("items changed");
        tRaw, tRoot = tCopy, tNewRoot;
        tPage, tPlan, tRootPlan, tHistory = nil, nil, nil, {};
        tRenderer.clear();

        if (bNotify) then
            tEvents.emit("itemsChanged", {Count = #tRoot});
        end

        return oMenu;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.setItem
    @desc Applies a descriptor patch by stable ID, validating the complete replacement
        before mutation. SetItems can remove optional fields or replace whole trees.
    !]]
    function oMenu.setItem(sId, tPatch, bNotify)
        assert(type(tPatch) == "table", "Item patch must be a table.");
        local tCopy = copyItems(tRaw);
        local function fPatch(tItems)
            for _, tItem in ipairs(tItems) do
                if (tItem.Id == sId) then
                    for sKey, vValue in pairs(tPatch) do
                        tItem[sKey] = vValue;
                    end

                    return true;
                elseif (tItem.Items and fPatch(tItem.Items)) then
                    return true;
                end
            end
        end

        assert(fPatch(tCopy), "Unknown menu item.");
        return oMenu.setItems(tCopy, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.detach
    @desc Removes one/all right-click attachments. Shared native handlers retain
        weak menu references so detached/destroyed menus are collectible.
    !]]
    function oMenu.detach(vTarget)
        local nId = vTarget and _Containment.native(vTarget):GetId() or nil;

        for nTargetId, tBinding in pairs(tBindings) do
            if (not nId or nTargetId == nId) then
                tBinding.Active = false;
            end
        end

        return oMenu;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.attach
    @desc Attaches native right-click/keyboard context-menu opening to a target.
        Programmatic showAt/showAtObject remains available independently.
    !]]
    function oMenu.attach(vTarget)
        assert(not oMenu.Disposed, "Cannot attach a disposed menu.");
        local oTarget = _Containment.native(vTarget);
        local nId = oTarget:GetId();
        local oCurrent = oTarget;

        while (oCurrent and oCurrent:GetId() ~= oParent:GetId()) do
            oCurrent = oCurrent:GetParent();
        end

        assert(oCurrent, "Menu attachment must belong to its lifetime parent.");

        if (tBindings[nId]) then
            tBindings[nId].Active = true;
            return oMenu;
        end

        local tWeak = setmetatable({oMenu}, {__mode = "v"});
        local tBinding = {Active = true};
        tBindings[nId] = tBinding;
        for _, nType in ipairs({_wx.wxEVT_MOVE, _wx.wxEVT_SIZE}) do
            oTarget:Connect(nType, function(jEvent)
                local oLive = tWeak[1];

                if (oLive and tBinding.Active and not oLive.Disposed and oOpenTarget
                    and oOpenTarget:GetId() == nId and jEvent:GetId() == nId) then
                    local oPoint = oTarget:ClientToScreen(_wx.wxPoint(nTargetX, nTargetY));
                    oLive.setAnchor(oPoint:GetX(), oPoint:GetY());
                end

                jEvent:Skip();
            end);
        end
        oTarget:Connect(_wx.wxEVT_DESTROY, function(jEvent)
            if (jEvent:GetId() == nId) then
                tBinding.Active = false;
                tBindings[nId] = nil;
                local oLive = tWeak[1];

                if (oLive and not oLive.Disposed and oOpenTarget and oOpenTarget:GetId() == nId) then
                    oOpenTarget = nil;
                    oLive.close("target destroyed");
                end
            end

            jEvent:Skip();
        end);
        oTarget:Connect(_wx.wxEVT_CONTEXT_MENU, function(jEvent)
            local oLive = tWeak[1];

            if (oLive and tBinding.Active and not oLive.Disposed and jEvent:GetId() == nId
                and oTarget:IsEnabled() and oTarget:IsShownOnScreen()) then
                local oPoint = jEvent:GetPosition();
                local bOpened;

                if (oPoint:GetX() < 0 or oPoint:GetY() < 0) then
                    bOpened = oLive.showAtObject(oTarget);
                else
                    bOpened = oLive.showAt(oPoint:GetX(), oPoint:GetY());
                end

                if (bOpened) then
                    oOpenTarget = oTarget;
                    local oLocal = oTarget:ScreenToClient(oPoint);

                    if (oPoint:GetX() >= 0 and oPoint:GetY() >= 0) then
                        nTargetX, nTargetY = oLocal:GetX(), oLocal:GetY();
                    end

                    return;
                end
            end

            jEvent:Skip();
        end);
        return oMenu;
    end

    local function fHover(nIndex)
        if (nIndex ~= nHover) then
            local tOld = tPlan and tPlan.Entries[nHover];
            nHover = nIndex;

            if (tOld) then
                tEvents.emit("itemLeft", {Id = tOld.Item.Id});
            end

            local tNew = tPlan and tPlan.Entries[nHover];

            if (tNew) then
                tEvents.emit("itemHovered", {Id = tNew.Item.Id});
            end

            oMenu.refresh();
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.handlePointer
    @desc Routes shape-aware pointer input. Images outside hosts are decorative;
        only enabled host buttons can activate an item.
    !]]
    function oMenu.handlePointer(sEvent, nX, nY)
        if (not bOpen or not oMenu.isEnabled()) then
            return;
        end

        local nIndex = 0;

        if (sEvent ~= "leave" and sEvent ~= "cancel") then
            for nEntry, tEntry in ipairs(tPlan.Entries) do
                if (_Renderer.hit(tEntry, nX, nY, bRadial)) then
                    nIndex = nEntry;
                    break;
                end
            end
        end

        fHover(nIndex);

        if (sEvent == "down" and nIndex == 0) then
            oMenu.close("outside click");
            return;
        end

        if (sEvent == "down" and nIndex > 0 and tPlan.Entries[nIndex].Item.Enabled) then
            nDown, nFocus = nIndex, nIndex;
            oCanvas:SetFocus();

            if (not oCanvas:HasCapture()) then
                oCanvas:CaptureMouse();
            end

            oMenu.refresh();
        elseif (sEvent == "up") then
            local nPressed = nDown;
            oMenu.cancel();

            if (nIndex > 0 and nIndex == nPressed) then
                oMenu.activateItem(tPlan.Entries[nIndex].Item.Id);
            end
        elseif (sEvent == "cancel") then
            oMenu.cancel();
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.handleKey
    @desc Arrows/Tab traverse enabled items; Enter/Space activates. Escape goes
        back through submenu/overflow pages, then dismisses the root menu.
    !]]
    function oMenu.handleKey(sEvent, nKey, tModifiers)
        if (not bOpen or not oMenu.isEnabled() or sEvent ~= "down") then
            return false;
        end

        if (nKey == _wx.WXK_ESCAPE or nKey == _wx.WXK_BACK) then
            if (not oMenu.back()) then
                oMenu.close("cancelled");
            end

            return true;
        elseif (nKey == _wx.WXK_RETURN or nKey == _wx.WXK_NUMPAD_ENTER or nKey == _wx.WXK_SPACE) then
            local tEntry = tPlan.Entries[nFocus];

            if (tEntry) then
                oMenu.activateItem(tEntry.Item.Id);
            end

            return true;
        end

        if (not bRadial and nKey == _wx.WXK_RIGHT) then
            local tEntry = tPlan.Entries[nFocus];

            if (tEntry and (tEntry.Item.Items or tEntry.Item.Role == "overflow")) then
                oMenu.activateItem(tEntry.Item.Id);
            end

            return true;
        elseif (not bRadial and nKey == _wx.WXK_LEFT) then
            oMenu.back();
            return true;
        end

        local nStep;

        if (nKey == _wx.WXK_DOWN or nKey == _wx.WXK_RIGHT or nKey == _wx.WXK_TAB) then
            nStep = tModifiers and tModifiers.Shift and -1 or 1;
        elseif (nKey == _wx.WXK_UP or nKey == _wx.WXK_LEFT) then
            nStep = -1;
        elseif (nKey == _wx.WXK_HOME or nKey == _wx.WXK_END) then
            nFocus = nKey == _wx.WXK_HOME and #tPlan.Entries or 1;
            nStep = nKey == _wx.WXK_HOME and 1 or -1;
        else
            return false;
        end

        for nPass = 1, #tPlan.Entries do
            nFocus = (nFocus - 1 + nStep) % #tPlan.Entries + 1;

            if (tPlan.Entries[nFocus].Item.Enabled) then
                oMenu.refresh();
                tEvents.emit("itemFocused", {Id = tPlan.Entries[nFocus].Item.Id});
                break;
            end
        end

        return true;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.draw
    @desc Draws current page using borrowed skin materials and cached item bitmaps.
    !]]
    function oMenu.draw(oDC, nWidth, nHeight)
        if (oMenu.Disposed) then
            return;
        end

        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)));
        local oBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
        oDC:SetBackground(oBrush);
        oDC:Clear();
        oBrush:delete();

        if (tPlan) then
            for nIndex, tEntry in ipairs(tPlan.Entries) do
                local sState = (not oMenu.isEnabled() or not tEntry.Item.Enabled) and "Disabled"
                    or (nDown == nIndex and "Pressed" or (nHover == nIndex or nFocus == nIndex) and "Hover" or "Normal");


                tRenderer.draw(oDC, tEntry, sState);
            end
        end

        oClip:delete();
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.destroy
    @desc Dismisses, detaches and disposes owned popup/render resources once.
    !]]
    function oMenu.destroy()
        if (not oMenu.Disposed) then
            oMenu.close("destroyed");
            oMenu.detach();
            oMenu.Disposed = true;
            tRenderer.destroy();
            tHistory, tPage, tPlan, tRootPlan = {}, nil, nil, nil;

            if (not oPopup:IsBeingDeleted()) then
                oPopup:Destroy();
            end
        end
    end

    tPolicy = _Containment.attach(oMenu, oParent, tOptions);
    tRenderer = _Renderer.create(oMenu.Skin, sArtwork, bRadial, function(pPath)
        tEvents.emit("imageError", {Path = pPath});
    end);

    -- Policy accessors are declared below; all mutate before recomputing a page.

    --[[!
    @fqxn wxLuma.UI.ControlMenu.getDirection
    @desc Returns the current Direction policy.
    !]]
    function oMenu.getDirection()
        return tConfig.Direction;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.setDirection
    @desc Changes Direction at runtime and recomputes the visible page without resizing
        item hosts. Valid configurations that cannot fit dismiss with layoutFailed.
    @param any vValue New Direction policy.
    @param boolean|nil bNotify Emit directionChanged on an effective change.
    @ret table oMenu This menu.
    !]]
    function oMenu.setDirection(vValue, bNotify)
        assert(vValue == "CW" or vValue == "CCW", "Direction must be CW or CCW.");

        if (not oMenu.Disposed and vValue ~= tConfig.Direction) then
            local vOld = tConfig.Direction;
            tConfig.Direction = vValue;
            fReflow();

            if (bNotify) then
                tEvents.emit("directionChanged", {Direction = vValue, OldDirection = vOld});
            end
        end

        return oMenu;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.getStartAngle
    @desc Returns the current StartAngle policy.
    !]]
    function oMenu.getStartAngle()
        return tConfig.StartAngle;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.setStartAngle
    @desc Changes StartAngle at runtime and recomputes the visible page without resizing
        item hosts. Valid configurations that cannot fit dismiss with layoutFailed.
    @param any vValue New StartAngle policy.
    @param boolean|nil bNotify Emit startAngleChanged on an effective change.
    @ret table oMenu This menu.
    !]]
    function oMenu.setStartAngle(vValue, bNotify)
        assert(_finite(vValue), "StartAngle must be finite.");
        vValue = vValue % 360;

        if (not oMenu.Disposed and vValue ~= tConfig.StartAngle) then
            local vOld = tConfig.StartAngle;
            tConfig.StartAngle = vValue;
            fReflow();

            if (bNotify) then
                tEvents.emit("startAngleChanged", {StartAngle = vValue, OldStartAngle = vOld});
            end
        end

        return oMenu;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.getSpacing
    @desc Returns the current Spacing policy.
    !]]
    function oMenu.getSpacing()
        return tConfig.Spacing;
    end

    --[[!
    @fqxn wxLuma.UI.ControlMenu.setSpacing
    @desc Changes Spacing at runtime and recomputes the visible page without resizing
        item hosts. Valid configurations that cannot fit dismiss with layoutFailed.
    @param any vValue New Spacing policy.
    @param boolean|nil bNotify Emit spacingChanged on an effective change.
    @ret table oMenu This menu.
    !]]
    function oMenu.setSpacing(vValue, bNotify)
        assert(_finite(vValue) and vValue >= 0, "Spacing must be nonnegative and finite.");

        if (not oMenu.Disposed and vValue ~= tConfig.Spacing) then
            local vOld = tConfig.Spacing;
            tConfig.Spacing = vValue;
            fReflow();

            if (bNotify) then
                tEvents.emit("spacingChanged", {Spacing = vValue, OldSpacing = vOld});
            end
        end

        return oMenu;
    end

    --[[!
    @fqxn wxLuma.UI.RadialMenu.getRadiusRange
    @desc Returns minimum and maximum permitted item-center radius.
    !]]
    function oMenu.getRadiusRange()
        return tConfig.MinRadius, tConfig.MaxRadius;
    end

    --[[!
    @fqxn wxLuma.UI.RadialMenu.setRadiusRange
    @desc Changes both radius bounds atomically. Items overflow rather than shrink.
    !]]
    function oMenu.setRadiusRange(nMinimum, nMaximum, bNotify)
        assert(_finite(nMinimum) and _finite(nMaximum) and nMinimum >= 0 and nMaximum >= nMinimum,
            "Invalid menu radius range.");

        if (not oMenu.Disposed and (nMinimum ~= tConfig.MinRadius or nMaximum ~= tConfig.MaxRadius)) then
            local nOldMin, nOldMax = tConfig.MinRadius, tConfig.MaxRadius;
            tConfig.MinRadius, tConfig.MaxRadius = nMinimum, nMaximum;
            fReflow();

            if (bNotify) then
                tEvents.emit("radiusChanged", {MinRadius = nMinimum, MaxRadius = nMaximum,
                    OldMinRadius = nOldMin, OldMaxRadius = nOldMax});
            end
        end

        return oMenu;
    end

    --[[!
    @fqxn wxLuma.UI.RadialMenu.getShape
    @desc Returns the default host shape for items without an explicit Shape.
    !]]
    function oMenu.getShape()
        return tConfig.Shape;
    end

    --[[!
    @fqxn wxLuma.UI.RadialMenu.setShape
    @desc Changes inherited host shapes; explicit per-item shapes remain unchanged.
        Rebuilds pages from the root so stored submenu descriptors cannot go stale.
    !]]
    function oMenu.setShape(sShape, bNotify)
        assert(sShape == "circle" or sShape == "diamond" or sShape == "square", "Invalid menu shape.");

        if (not oMenu.Disposed and sShape ~= tConfig.Shape) then
            local bWasOpen = bOpen;
            local sOld = tConfig.Shape;
            tConfig.Shape = sShape;
            tRoot = fNormalize(tRaw);
            tRenderer.clear();

            if (bWasOpen) then
                oMenu.close("shape changed");
                oMenu.showAt(nRequestedX, nRequestedY);
            end

            if (bNotify) then
                tEvents.emit("shapeChanged", {Shape = sShape, OldShape = sOld});
            end
        end

        return oMenu;
    end

    -- Native mouse input remains observable through shared on/off subscriptions.
    for _, tBinding in ipairs({
        {_wx.wxEVT_LEFT_DOWN, "down"}, {_wx.wxEVT_LEFT_UP, "up"},
        {_wx.wxEVT_MOTION, "move"}, {_wx.wxEVT_LEAVE_WINDOW, "leave"}
    }) do
        local sEvent = tBinding[2];
        oCanvas:Connect(tBinding[1], function(jEvent)
            oMenu.handlePointer(sEvent, jEvent:GetX(), jEvent:GetY());
        end);
    end

    oCanvas:Connect(_wx.wxEVT_MOUSE_CAPTURE_LOST, function()
        oMenu.cancel();
        oMenu.refresh();
    end);
    oPopup:Connect(_wx.wxEVT_CHAR_HOOK, function(jEvent)
        if (jEvent:GetKeyCode() ~= _wx.WXK_ESCAPE or not oMenu.handleKey("down", _wx.WXK_ESCAPE)) then
            jEvent:Skip();
        end
    end);
    oCanvas:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        if (not oMenu.handleKey("down", jEvent:GetKeyCode(), {Shift = jEvent:ShiftDown()})) then
            jEvent:Skip();
        end
    end);
    oCanvas:Connect(_wx.wxEVT_PAINT, function()
        local oDC = _wx.wxAutoBufferedPaintDC(oCanvas);
        oMenu.draw(oDC, oCanvas:GetClientSizeWH());
        oDC:delete();
    end);
    oPopup:Connect(_wx.wxEVT_SHOW, function(jEvent)
        if (not jEvent:IsShown()) then
            oMenu.close("hidden");
        end

        jEvent:Skip();
    end);
    oPopup:Connect(_wx.wxEVT_ACTIVATE, function(jEvent)
        if (not jEvent:GetActive()) then
            oMenu.close("deactivated");
        end

        jEvent:Skip();
    end);
    oCanvas:Connect(_wx.wxEVT_IDLE, function(jEvent)
        if (bOpen and oOpenTarget and (oOpenTarget:IsBeingDeleted()
            or not oOpenTarget:IsShownOnScreen() or not oOpenTarget:IsEnabled())) then
            oMenu.close("target unavailable");
        end

        jEvent:Skip();
    end);
    local nCanvasId = oCanvas:GetId();
    oCanvas:Connect(_wx.wxEVT_DESTROY, function(jEvent)
        if (jEvent:GetId() == nCanvasId) then
            oMenu.destroy();
        end

        jEvent:Skip();
    end);
    tPolicy.watch(function(sReason)
        if (bOpen) then
            if (sReason == "destroy" or not oParent:IsShownOnScreen() or not oMenu.isEnabled()) then
                oMenu.close("parent destroyed");
            else
                if (oOpenTarget and not oOpenTarget:IsBeingDeleted()) then
                    local oPoint = oOpenTarget:ClientToScreen(_wx.wxPoint(nTargetX, nTargetY));
                    nRequestedX, nRequestedY = oPoint:GetX(), oPoint:GetY();
                else
                    local oOrigin = oParent:ClientToScreen(_wx.wxPoint(0, 0));
                    nRequestedX, nRequestedY = oOrigin:GetX() + nLocalX, oOrigin:GetY() + nLocalY;
                end

                fReflow();
            end
        end
    end);
    -- Install observers after input handlers, as on the shared control surface.
    -- Their Skip calls preserve both generic notifications and menu activation.
    tEvents = _Events.attach(oMenu, nil, {"opened", "closed", "selected", "pageChanged", "itemsChanged",
        "itemHovered", "itemLeft", "itemFocused", "layoutFailed", "imageError", "directionChanged",
        "startAngleChanged", "spacingChanged", "radiusChanged", "shapeChanged"});
    oCanvas:Enable(oMenu.Enabled);
    return oMenu;
end

return ControlMenu;
