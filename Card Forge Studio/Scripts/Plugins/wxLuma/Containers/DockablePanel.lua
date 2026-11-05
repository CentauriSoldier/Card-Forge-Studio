local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _finite = require("wxLuma.Core.ControlNumeric").finite;
local DockablePanel = {};
local _tSides = {left = true, right = true, top = true, bottom = true, fill = true};

--[[!
@fqxn wxLuma.UI.DockablePanel.create
@desc Creates a skinned title/content panel that can dock to owner edges or float.
    Dragging its header detaches; releasing within 28 screen pixels of an owner
    edge docks there. The title action toggles floating/last dock; Escape docks.
    Its one native floating host is allocated at creation and reused. Application
    children keep the same Content parent and native identity in every mode.
    Edge docking positions this panel; the application owns sibling layout policy.
@param wxWindow oParent Native docking host.
@param table tOptions Skin, optional Text, Side (fill), Extent (220), Artwork,
    Enabled and OnChange(dockState, component).
@ret table oComponent Content, FloatingWindow, dock/float/isFloating and get/setDockState.
!]]
function DockablePanel.create(oParent, tOptions)
    local sSide, nExtent = tOptions.Side or "fill", tOptions.Extent or 220;
    assert(_tSides[sSide] and _finite(nExtent) and nExtent >= 64 and nExtent <= 32767, "Invalid dock side/extent.");
    assert(tOptions.Text == nil or type(tOptions.Text) == "string", "Invalid panel title.");
    local oComponent = _Surface.create(oParent, tOptions, "DockablePanel");
    oComponent.Text = tOptions.Text or "Panel";
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Dockable Panel");
    local tEvents = _Events.attach(oComponent, nil, {"dockChanged"});
    local oContent = _wx.wxPanel(oComponent.Control, _wx.wxID_ANY, _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxTAB_TRAVERSAL + _wx.wxCLIP_CHILDREN);
    oContent:SetBackgroundColour(tArt.color("Content Normal"));
    local oFloat = _wx.wxFrame(oParent, _wx.wxID_ANY, "", _wx.wxDefaultPosition, _wx.wxSize(360, 240),
        _wx.wxFRAME_NO_TASKBAR + _wx.wxFRAME_FLOAT_ON_PARENT + _wx.wxBORDER_NONE);
    oComponent.Content, oComponent.FloatingWindow = oContent, oFloat;
    local bFloating, bChanging, bDestroying = false, false, false;
    local tDrag;

    --[[!
    @fqxn wxLuma.UI.DockablePanel.layoutDock
    @desc Fits the existing panel to its owner's configured edge without allocating layout children.
    !]]
    local function fLayoutDock()
        if (oComponent.Disposed or bFloating or bChanging) then return; end
        local nWidth, nHeight = oParent:GetClientSizeWH();
        local nX, nY, nW, nH = 0, 0, math.max(1, nWidth), math.max(1, nHeight);
        if (sSide == "left" or sSide == "right") then
            nW = math.max(1, math.min(nExtent, nWidth));
            if (sSide == "right") then nX = nWidth - nW; end
        elseif (sSide == "top" or sSide == "bottom") then
            nH = math.max(1, math.min(nExtent, nHeight));
            if (sSide == "bottom") then nY = nHeight - nH; end
        end
        oComponent.layout(nX, nY, nW, nH);
    end
    --[[!
    @fqxn wxLuma.UI.DockablePanel.isFloating
    @desc Reports whether the panel currently lives in its reusable floating host.
    !]]
    function oComponent.isFloating() return bFloating and not oComponent.Disposed; end
    --[[!
    @fqxn wxLuma.UI.DockablePanel.getDockState
    @desc Returns a detached placement snapshot; restoration never creates objects.
    !]]
    function oComponent.getDockState()
        local nX, nY = oFloat:GetPositionXY();
        local nW, nH = oFloat:GetClientSizeWH();
        return {Side = sSide, Extent = nExtent, Floating = bFloating, X = nX, Y = nY, Width = nW, Height = nH};
    end

    --[[!
    @fqxn wxLuma.UI.DockablePanel.changed
    @desc Emits one complete committed placement snapshot after an effective change.
    !]]
    local function fChanged(tOld, bNotify)
        local tNext = oComponent.getDockState();
        local bChanged = false;
        for sKey, vValue in pairs(tNext) do bChanged = bChanged or tOld[sKey] ~= vValue; end
        if (bChanged and bNotify) then
            tEvents.emit("dockChanged", {Value = tNext, OldValue = tOld});
            if (oComponent.OnChange) then oComponent.OnChange(oComponent.getDockState(), oComponent); end
        end
    end
    --[[!
    @fqxn wxLuma.UI.DockablePanel.setDockState
    @desc Validates and restores placement using only the existing Content, panel and floating host.
    !]]
    function oComponent.setDockState(tState, bNotify)
        assert(type(tState) == "table" and _tSides[tState.Side] and type(tState.Floating) == "boolean", "Invalid dock state.");
        for _, sKey in ipairs({"X", "Y", "Width", "Height", "Extent"}) do
            assert(_finite(tState[sKey]) and math.abs(tState[sKey]) <= 32767, "Invalid dock geometry.");
        end
        assert(tState.Width >= 64 and tState.Height >= 64 and tState.Extent >= 64, "Dock dimensions must be at least 64.");
        if (oComponent.Disposed) then return oComponent; end
        local tOld = oComponent.getDockState();
        bChanging = true; oComponent.cancel();
        sSide, nExtent = tState.Side, tState.Extent;
        oFloat:SetSize(math.floor(tState.X), math.floor(tState.Y), math.floor(tState.Width), math.floor(tState.Height));
        if (tState.Floating ~= bFloating) then
            oComponent.Control:Reparent(tState.Floating and oFloat or oParent);
            bFloating = tState.Floating;
        end
        oFloat:Show(bFloating);
        oComponent.Control:Show(true);
        bChanging = false;
        if (bFloating) then oComponent.layout(0, 0, oFloat:GetClientSizeWH()); else fLayoutDock(); end
        fChanged(tOld, bNotify);
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.DockablePanel.dock
    @desc Docks to a valid owner edge or the last side. Existing children remain intact.
    !]]
    function oComponent.dock(sNext, bNotify)
        local tState = oComponent.getDockState(); tState.Side, tState.Floating = sNext or sSide, false;
        return oComponent.setDockState(tState, bNotify);
    end
    --[[!
    @fqxn wxLuma.UI.DockablePanel.float
    @desc Detaches to an optional screen position, preserving current panel dimensions and child identities.
    !]]
    function oComponent.float(nX, nY, bNotify)
        local tState = oComponent.getDockState();
        if (not bFloating) then
            local oPoint = oComponent.Control:ClientToScreen(_wx.wxPoint(0, 0));
            local nW, nH = oComponent.Control:GetClientSizeWH();
            tState.X, tState.Y, tState.Width, tState.Height = oPoint:GetX(), oPoint:GetY(), math.max(180, nW), math.max(100, nH);
            oPoint:delete();
        end
        tState.X, tState.Y = nX or tState.X, nY or tState.Y;
        tState.Floating = true;
        return oComponent.setDockState(tState, bNotify);
    end
    oComponent.onLayout = function(nWidth, nHeight) oContent:SetSize(4, 36, math.max(1, nWidth - 8), math.max(1, nHeight - 40)); end;
    oComponent.onCancel = function() if (not bChanging) then tDrag = nil; end end;
    oComponent.pointer = function(sEvent, nX, nY)
        local nWidth = oComponent.Control:GetClientSizeWH();
        if (sEvent == "down" and nY < 34) then
            if (nX >= nWidth - 34) then tDrag = {Action = true}; return; end
            local oPoint = oComponent.Control:ClientToScreen(_wx.wxPoint(nX, nY));
            local tStart = {X = oPoint:GetX(), Y = oPoint:GetY(), OffsetX = nX, OffsetY = nY};
            oPoint:delete();
            if (not bFloating) then oComponent.float(tStart.X - nX, tStart.Y - nY, true); end
            tDrag = tStart;
            oComponent.Pressed = true;
            if (not oComponent.Control:HasCapture()) then oComponent.Control:CaptureMouse(); end
        elseif (sEvent == "move" and oComponent.Pressed and tDrag and not tDrag.Action) then
            local oPoint = oComponent.Control:ClientToScreen(_wx.wxPoint(nX, nY));
            oFloat:Move(oPoint:GetX() - tDrag.OffsetX, oPoint:GetY() - tDrag.OffsetY); oPoint:delete();
        elseif (sEvent == "up" and tDrag) then
            if (tDrag.Action and oComponent.Hover and nX >= nWidth - 34) then
                if (bFloating) then oComponent.dock(nil, true); else oComponent.float(nil, nil, true); end
            elseif (bFloating) then
                local oPoint = oComponent.Control:ClientToScreen(_wx.wxPoint(nX, nY));
                local oLocal = oParent:ScreenToClient(oPoint);
                local nW, nH = oParent:GetClientSizeWH();
                local nPX, nPY = oLocal:GetX(), oLocal:GetY();
                if (nPX >= -28 and nPX <= nW + 28 and nPY >= -28 and nPY <= nH + 28) then
                    local sEdge = nPX < 28 and "left" or nPX > nW - 28 and "right" or nPY < 28 and "top" or nPY > nH - 28 and "bottom";
                    if (sEdge) then oComponent.dock(sEdge, true); end
                end
                oLocal:delete(); oPoint:delete();
            end
            tDrag = nil;
        end
    end;
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_ESCAPE and bFloating) then oComponent.dock(nil, true); return true; end
        if (nKey == _wx.WXK_RETURN or nKey == _wx.WXK_SPACE) then
            if (bFloating) then oComponent.dock(nil, true); else oComponent.float(nil, nil, true); end
            return true;
        end
        return false;
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        local sState = oComponent.getState();
        tArt.part(oDC, "Surface "..sState, 0, 0, nWidth, nHeight);
        tArt.part(oDC, "Header "..sState, 2, 2, nWidth - 4, 32);
        tArt.part(oDC, "Grip "..sState, 8, 9, 16, 18);
        tArt.part(oDC, "Action "..sState, nWidth - 28, 9, 18, 18);
        oDC:SetClippingRegion(30, 4, math.max(1, nWidth - 68), 28);
        tArt.text(oDC, oComponent.Text, 32, 8, oComponent.isEnabled()); oDC:DestroyClippingRegion();
    end;
    oParent:Connect(_wx.wxEVT_SIZE, function(jEvent) if (not oComponent.Disposed) then fLayoutDock(); end; jEvent:Skip(); end);
    oFloat:Connect(_wx.wxEVT_SIZE, function(jEvent)
        if (not oComponent.Disposed and bFloating and not bChanging) then oComponent.layout(0, 0, oFloat:GetClientSizeWH()); end
        jEvent:Skip();
    end);
    oFloat:Connect(_wx.wxEVT_CLOSE_WINDOW, function(jEvent)
        if (not bDestroying and not oComponent.Disposed) then oComponent.dock(nil, true); jEvent:Veto(); else jEvent:Skip(); end
    end);
    oComponent.onDestroy = function()
        bDestroying = true;
        if (bFloating and not oParent:IsBeingDeleted()) then oComponent.Control:Reparent(oParent); end
        if (not oFloat:IsBeingDeleted()) then oFloat:Destroy(); end
        tArt.destroy();
    end;
    fLayoutDock();
    return oComponent;
end

return DockablePanel;
