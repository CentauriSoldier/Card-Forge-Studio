local _wx      = require("wx");
local _Theme   = require("wxLuma.Core.ControlTheme");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events  = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _State   = require("wxLuma.State");
local _copy    = _State.copy;
local ImageViewer = {};
local _tActions = {Pan = true, Select = true, ZoomIn = true, ZoomOut = true, Fit = true, ActualSize = true, Cancel = true};
local _tDefaultBindings = {
    Pan = {{Type = "drag", Button = "left", Tool = "pan"}, {Type = "drag", Button = "middle"}},
    Select = {{Type = "drag", Button = "left", Tool = "select"}, {Type = "drag", Button = "left", Shift = true}},
    ZoomIn = {{Type = "wheel", Direction = 1}, {Type = "key", Key = string.byte("=")},
        {Type = "key", Key = string.byte("+")}, {Type = "key", Key = string.byte("+"), Shift = true}},
    ZoomOut = {{Type = "wheel", Direction = -1}, {Type = "key", Key = string.byte("-")}},
    Fit = {{Type = "key", Key = string.byte("F")}},
    ActualSize = {{Type = "key", Key = string.byte("1")}},
    Cancel = {{Type = "key", Key = _wx.WXK_ESCAPE}},
};

--[[!
@fqxn wxLuma.UI.ImageViewer.number
@desc Rejects nonnumeric, infinite and NaN geometry before native operations.
!]]
local function number(nValue)
    assert(type(nValue) == "number" and nValue == nValue and math.abs(nValue) < math.huge,
        "ImageViewer coordinates must be finite numbers.");
    return nValue;
end

--[[!
@fqxn wxLuma.UI.ImageViewer.bindings
@desc Validates and copies a complete action-to-binding map before mutation.
    Missing actions are unbound. Modifiers are exact booleans, defaulting false;
    Tool restricts drag bindings only. Overlapping actions are rejected rather
    than depending on table iteration order.
!]]
local function bindings(tValue)
    assert(type(tValue) == "table", "Bindings must be an action map.");
    local tResult, tAll = {}, {};
    for sAction in pairs(tValue) do assert(_tActions[sAction], "Unknown image viewer action: "..tostring(sAction)); end
    for sAction in pairs(_tActions) do
        local tList = tValue[sAction];
        if (tList == nil) then tList = {}; end
        assert(type(tList) == "table", "Action bindings must be arrays.");
        tResult[sAction] = {};
        for vKey in pairs(tList) do
            assert(type(vKey) == "number" and vKey % 1 == 0 and vKey >= 1 and vKey <= #tList, "Bindings must be dense arrays.");
        end
        for nIndex = 1, #tList do assert(tList[nIndex] ~= nil, "Bindings must be dense arrays."); end
        for nIndex, tBinding in ipairs(tList) do
            assert(type(tBinding) == "table", "A binding must be a descriptor.");
            local sType = tBinding.Type;
            assert(sType == "key" or sType == "drag" or sType == "wheel", "Binding Type must be key, drag or wheel.");
            local bDragAction = sAction == "Pan" or sAction == "Select";
            assert(bDragAction and sType == "drag" or not bDragAction and sType ~= "drag", "Pan/Select require drag bindings; other actions cannot drag.");
            assert(sType ~= "wheel" or sAction == "ZoomIn" or sAction == "ZoomOut", "Wheel bindings require ZoomIn or ZoomOut.");
            local tFields = {Type = true, Shift = true, Command = true, Alt = true};
            if (sType == "key") then tFields.Key = true;
            elseif (sType == "drag") then tFields.Button, tFields.Tool = true, true;
            else tFields.Direction = true; end
            for sKey in pairs(tBinding) do assert(tFields[sKey], "Unknown binding field: "..tostring(sKey)); end
            local tNext = {Type = sType};
            for _, sKey in ipairs({"Shift", "Command", "Alt"}) do
                assert(tBinding[sKey] == nil or type(tBinding[sKey]) == "boolean", "Binding modifiers must be boolean.");
                tNext[sKey] = tBinding[sKey] == true;
            end
            if (sType == "key") then
                number(tBinding.Key);
                assert(tBinding.Key > 0 and tBinding.Key % 1 == 0 and tBinding.Key <= 2147483647, "Key must be a positive wx key code.");
                tNext.Key = tBinding.Key;
            elseif (sType == "drag") then
                assert(tBinding.Button == "left" or tBinding.Button == "middle" or tBinding.Button == "right", "Unknown drag button.");
                assert(tBinding.Tool == nil or tBinding.Tool == "pan" or tBinding.Tool == "select", "Unknown drag Tool.");
                tNext.Button, tNext.Tool = tBinding.Button, tBinding.Tool;
            else
                assert(tBinding.Direction == 1 or tBinding.Direction == -1, "Wheel Direction must be 1 or -1.");
                tNext.Direction = tBinding.Direction;
            end
            for _, tOther in ipairs(tAll) do
                assert(not (tNext.Type == tOther.Type and tNext.Key == tOther.Key and tNext.Button == tOther.Button
                    and tNext.Direction == tOther.Direction and tNext.Shift == tOther.Shift and tNext.Command == tOther.Command
                    and tNext.Alt == tOther.Alt and (not tNext.Tool or not tOther.Tool or tNext.Tool == tOther.Tool)),
                    "Overlapping image viewer bindings.");
            end
            tResult[sAction][nIndex] = tNext; tAll[#tAll + 1] = tNext;
        end
    end
    return tResult;
end

--[[!
@fqxn wxLuma.UI.ImageViewer.viewerState
@desc Copies and validates saved viewer policy and geometry before mutation.
    Source-dependent selection bounds are checked after preparing the image.
!]]
local function viewerState(tValue)
    assert(type(tValue) == "table", "Viewer state must be a record.");
    local tNext = _copy(tValue);
    local tFields = {Value = true, View = true, Selection = true, Tool = true, Bindings = true,
        PanEnabled = true, ZoomEnabled = true, SelectionEnabled = true, Enabled = true};
    for sKey in pairs(tNext) do assert(tFields[sKey], "Unknown viewer state property."); end
    assert(tNext.Value == nil or type(tNext.Value) == "string" and tNext.Value ~= ""
        and not tNext.Value:find("\0", 1, true), "Invalid viewer state image path.");
    assert(tNext.Tool == "pan" or tNext.Tool == "select", "Invalid viewer state Tool.");
    for _, sName in ipairs({"PanEnabled", "ZoomEnabled", "SelectionEnabled", "Enabled"}) do
        assert(type(tNext[sName]) == "boolean", "Viewer state flags must be boolean.");
    end
    local tView = tNext.View;
    assert(type(tView) == "table" and (tView.Mode == "fit" or tView.Mode == "manual"), "Invalid viewer state View.");
    for sKey in pairs(tView) do assert(sKey == "Mode" or sKey == "Zoom" or sKey == "PanX" or sKey == "PanY", "Unknown viewer state geometry."); end
    number(tView.Zoom); number(tView.PanX); number(tView.PanY);
    assert(tView.Zoom > 0 and tView.Zoom <= 64 and (tView.Mode == "fit" or tView.Zoom >= 0.000001), "Invalid viewer state zoom.");
    if (tNext.Selection ~= nil) then
        assert(type(tNext.Selection) == "table", "Invalid viewer state selection.");
        for sKey in pairs(tNext.Selection) do assert(sKey == "X" or sKey == "Y" or sKey == "Width" or sKey == "Height", "Unknown viewer state selection bound."); end
        for _, sKey in ipairs({"X", "Y", "Width", "Height"}) do
            number(tNext.Selection[sKey]); assert(tNext.Selection[sKey] % 1 == 0, "Saved selection bounds must be integers.");
        end
        assert(tNext.Selection.X >= 0 and tNext.Selection.Y >= 0 and tNext.Selection.Width > 0 and tNext.Selection.Height > 0,
            "Invalid viewer state selection bounds.");
    end
    tNext.Bindings = bindings(tNext.Bindings);
    return tNext;
end

--[[!
@fqxn wxLuma.UI.ImageViewer.create
@desc Creates an image inspection surface with fit, cursor-anchored zoom, pan,
    source-pixel inspection and rectangular selection. Source coordinates are
    zero-based; selection bounds include whole pixels. Owns its decoded image
    and one viewport-sized raster, never the caller's DC or shared skin.
@param table tOptions Value (image path or nil), Tool (pan/select), Artwork
    (Chart: reuses Plot Normal/Disabled and Axis Selected materials), Skin,
    Enabled, Border, OnChange, PanEnabled/ZoomEnabled/SelectionEnabled (true),
    Bindings (complete action map; omitted uses defaults). Left drag uses Tool; Shift-left selects and
    middle drag always pans. Wheel zooms; F fits, 1 centers at 1:1, Escape cancels
    a drag or clears selection. Setters are silent unless notify is true.
!]]
function ImageViewer.create(oParent, tOptions)
    tOptions = _Theme.options(tOptions, oParent);
    local sTool = tOptions.Tool or "pan";
    assert(sTool == "pan" or sTool == "select", "ImageViewer Tool must be pan or select.");
    assert(tOptions.Value == nil or type(tOptions.Value) == "string", "ImageViewer Value must be a path or nil.");
    local tInteraction = {};
    for _, sName in ipairs({"PanEnabled", "ZoomEnabled", "SelectionEnabled"}) do
        assert(tOptions[sName] == nil or type(tOptions[sName]) == "boolean", sName.." must be boolean.");
        tInteraction[sName] = tOptions[sName] ~= false;
    end
    local tBindings = bindings(tOptions.Bindings == nil and _tDefaultBindings or tOptions.Bindings);

    local oComponent = _Surface.create(oParent, tOptions, "ImageViewer");
    local tEvents = _Events.attach(oComponent, nil, {"viewChanged", "selectionChanged", "pixelHovered", "toolChanged", "interactionChanged", "bindingsChanged"});
    local tArt = _Artwork.create(oComponent.Skin, tOptions.Artwork or "Chart");
    local oImage, tRaster, tSelection, tDrag, tHovered;
    local sMode, nZoom, nPanX, nPanY = "fit", 1, 0, 0;
    local nViewWidth, nViewHeight = oComponent.Control:GetClientSizeWH();

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fAlive
    @desc Prevents access to source images or native windows after disposal.
    !]]
    local function fAlive()
        assert(not oComponent.Disposed, "ImageViewer is disposed.");
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fClearRaster
    @desc Releases the single owned display bitmap when its geometry changes.
    !]]
    local function fClearRaster()
        if (tRaster) then tRaster.Bitmap:delete(); tRaster = nil; end
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fCopySelection
    @desc Returns an independent source-pixel rectangle for callers and events.
    !]]
    local function fCopySelection(tValue)
        if (tValue) then
            return {X = tValue.X, Y = tValue.Y, Width = tValue.Width, Height = tValue.Height};
        end
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fGeometry
    @desc Resolves fit or constrained manual geometry. Explicit dimensions are
        a pure offscreen projection; omitted dimensions update the live view.
    @ret number nX Image origin, followed by Y and source-to-client zoom.
    !]]
    local function fGeometry(nWidth, nHeight)
        if (not oImage) then return 0, 0, nZoom; end
        local bLive = nWidth == nil;
        nWidth, nHeight = nWidth or nViewWidth, nHeight or nViewHeight;
        local nScale, nOffsetX, nOffsetY = nZoom, nPanX, nPanY;
        local nW, nH = oImage:GetWidth(), oImage:GetHeight();
        if (sMode == "fit") then
            nScale = math.min(64, math.max(1, nWidth) / nW, math.max(1, nHeight) / nH);
            nOffsetX, nOffsetY = 0, 0;
        else
            local nLimitX = math.max(0, (nW * nScale - nWidth) / 2);
            local nLimitY = math.max(0, (nH * nScale - nHeight) / 2);
            nOffsetX = math.max(-nLimitX, math.min(nLimitX, nOffsetX));
            nOffsetY = math.max(-nLimitY, math.min(nLimitY, nOffsetY));
        end
        if (bLive) then nZoom, nPanX, nPanY = nScale, nOffsetX, nOffsetY; end
        return (nWidth - nW * nScale) / 2 + nOffsetX,
            (nHeight - nH * nScale) / 2 + nOffsetY, nScale;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getImageSize
    @desc Returns decoded source width and height, or zeroes when empty/disposed.
    !]]
    function oComponent.getImageSize()
        if (oImage) then return oImage:GetWidth(), oImage:GetHeight(); end
        return 0, 0;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getView
    @desc Returns independent Mode, Zoom, PanX and PanY values for this viewport.
        Pan offsets are relative to the centered image, measured in client pixels.
    !]]
    function oComponent.getView()
        fAlive(); fGeometry();
        return {Mode = sMode, Zoom = nZoom, PanX = nPanX, PanY = nPanY};
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getZoom
    @desc Returns client pixels per source pixel, including the current fit scale.
    !]]
    function oComponent.getZoom()
        fAlive(); fGeometry(); return nZoom;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fViewChanged
    @desc Invalidates only changed view geometry and optionally emits snapshots.
    !]]
    local function fViewChanged(tOld, bNotify)
        local tView = oComponent.getView();
        if (tOld.Mode ~= tView.Mode or tOld.Zoom ~= tView.Zoom or tOld.PanX ~= tView.PanX or tOld.PanY ~= tView.PanY) then
            fClearRaster(); oComponent.refresh();
            if (bNotify) then tEvents.emit("viewChanged", {View = tView, OldView = tOld}); end
        end
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.clientToImage
    @desc Maps client coordinates to fractional source coordinates and reports
        whether they are inside the image. Returns nil when empty.
    !]]
    function oComponent.clientToImage(nX, nY)
        fAlive(); number(nX); number(nY);
        if (not oImage) then return nil; end
        local nOriginX, nOriginY, nScale = fGeometry();
        local nSourceX, nSourceY = (nX - nOriginX) / nScale, (nY - nOriginY) / nScale;
        return nSourceX, nSourceY, nSourceX >= 0 and nSourceY >= 0
            and nSourceX < oImage:GetWidth() and nSourceY < oImage:GetHeight();
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.imageToClient
    @desc Maps fractional source coordinates to client coordinates; nil if empty.
    !]]
    function oComponent.imageToClient(nX, nY)
        fAlive(); number(nX); number(nY);
        if (not oImage) then return nil; end
        local nOriginX, nOriginY, nScale = fGeometry();
        return nOriginX + nX * nScale, nOriginY + nY * nScale;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getPixel
    @desc Returns {X,Y,Red,Green,Blue,Alpha} for a zero-based integer source
        pixel, or nil outside the image. Values are original bytes, not scaled
        display colors. Mask-transparent pixels report Alpha 0.
    !]]
    function oComponent.getPixel(nX, nY)
        fAlive(); number(nX); number(nY);
        assert(nX % 1 == 0 and nY % 1 == 0, "Pixel coordinates must be integers.");
        if (not oImage or nX < 0 or nY < 0 or nX >= oImage:GetWidth() or nY >= oImage:GetHeight()) then return nil; end
        local nR, nG, nB = oImage:GetRed(nX, nY), oImage:GetGreen(nX, nY), oImage:GetBlue(nX, nY);
        local nAlpha = oImage:HasAlpha() and oImage:GetAlpha(nX, nY) or 255;
        if (oImage:HasMask() and nR == oImage:GetMaskRed() and nG == oImage:GetMaskGreen() and nB == oImage:GetMaskBlue()) then nAlpha = 0; end
        return {X = nX, Y = nY, Red = nR, Green = nG, Blue = nB, Alpha = nAlpha};
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.setZoom
    @desc Sets manual zoom between 0.000001 and 64. Optional client anchor
        defaults to the viewport center; its source position stays fixed unless
        pan limits require centering or keeping an image edge in the viewport.
    @param number nValue Client pixels per source pixel.
    @param boolean bNotify Whether to emit viewChanged.
    @param number nAnchorX Optional client anchor, followed by nAnchorY.
    !]]
    function oComponent.setZoom(nValue, bNotify, nAnchorX, nAnchorY)
        fAlive(); number(nValue);
        assert(nValue >= 0.000001 and nValue <= 64, "Zoom must be between 0.000001 and 64.");
        nAnchorX, nAnchorY = nAnchorX or nViewWidth / 2, nAnchorY or nViewHeight / 2;
        number(nAnchorX); number(nAnchorY);
        local tOld = oComponent.getView();
        local nSourceX, nSourceY = oComponent.clientToImage(nAnchorX, nAnchorY);
        sMode, nZoom = "manual", nValue;
        if (oImage) then
            nPanX = nAnchorX - nSourceX * nZoom - (nViewWidth - oImage:GetWidth() * nZoom) / 2;
            nPanY = nAnchorY - nSourceY * nZoom - (nViewHeight - oImage:GetHeight() * nZoom) / 2;
        end
        fViewChanged(tOld, bNotify); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.setPan
    @desc Sets manual client-pixel offsets relative to the centered image,
        constrained to image bounds. Preserves the current zoom, including fit.
    !]]
    function oComponent.setPan(nX, nY, bNotify)
        fAlive(); number(nX); number(nY);
        local tOld = oComponent.getView();
        sMode, nPanX, nPanY = "manual", nX, nY;
        fViewChanged(tOld, bNotify); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fit
    @desc Fits and centers the whole image; subsequent resizes continue fitting.
    !]]
    function oComponent.fit(bNotify)
        fAlive(); local tOld = oComponent.getView();
        sMode, nPanX, nPanY = "fit", 0, 0;
        fViewChanged(tOld, bNotify); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.actualSize
    @desc Centers the image at exactly one client pixel per source pixel.
    !]]
    function oComponent.actualSize(bNotify)
        fAlive(); local tOld = oComponent.getView();
        sMode, nZoom, nPanX, nPanY = "manual", 1, 0, 0;
        fViewChanged(tOld, bNotify); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getSelection
    @desc Returns an independent committed {X,Y,Width,Height} source rectangle,
        or nil. Drag previews do not change the committed selection.
    !]]
    function oComponent.getSelection()
        return fCopySelection(tSelection);
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.setSelection
    @desc Sets a whole-pixel rectangle entirely inside the image, or clears with
        nil. Invalid bounds leave the existing selection unchanged.
    !]]
    function oComponent.setSelection(tValue, bNotify)
        fAlive();
        if (tValue ~= nil) then
            assert(oImage and type(tValue) == "table", "Selection requires an image and rectangle.");
            for _, sKey in ipairs({"X", "Y", "Width", "Height"}) do
                number(tValue[sKey]); assert(tValue[sKey] % 1 == 0, "Selection bounds must be integers.");
            end
            assert(tValue.X >= 0 and tValue.Y >= 0 and tValue.Width > 0 and tValue.Height > 0
                and tValue.X + tValue.Width <= oImage:GetWidth() and tValue.Y + tValue.Height <= oImage:GetHeight(),
                "Selection must be inside the image.");
        end
        local tOld = fCopySelection(tSelection);
        if (not tOld and not tValue or tOld and tValue and tOld.X == tValue.X and tOld.Y == tValue.Y
            and tOld.Width == tValue.Width and tOld.Height == tValue.Height) then return oComponent; end
        tSelection = fCopySelection(tValue); oComponent.refresh();
        if (bNotify) then tEvents.emit("selectionChanged", {Selection = fCopySelection(tSelection), OldSelection = tOld}); end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getTool
    @desc Returns pan or select for the unmodified left mouse button.
    !]]
    function oComponent.getTool() return sTool; end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.interactionAccessors
    @desc Installs get/is/setPanEnabled, get/is/setZoomEnabled and
        get/is/setSelectionEnabled. Flags gate user actions only; application
        setters remain available. Disabling a drag's action releases capture and
        discards its preview while retaining the committed view and selection.
        Optional notification emits interactionChanged with Property/Value/OldValue.
    !]]
    for _, sName in ipairs({"PanEnabled", "ZoomEnabled", "SelectionEnabled"}) do
        local sProperty = sName;
        local function fGet()
            fAlive(); return tInteraction[sProperty];
        end
        oComponent["get"..sProperty], oComponent["is"..sProperty] = fGet, fGet;
        oComponent["set"..sProperty] = function(bValue, bNotify)
            fAlive(); assert(type(bValue) == "boolean", sProperty.." must be boolean.");
            local bOld = tInteraction[sProperty];
            if (bOld ~= bValue) then
                tInteraction[sProperty] = bValue;
                if (not bValue and tDrag and (sProperty == "PanEnabled" and tDrag.Tool == "pan"
                    or sProperty == "SelectionEnabled" and tDrag.Tool == "select")) then oComponent.cancel(); end
                if (bNotify) then tEvents.emit("interactionChanged", {Property = sProperty, Value = bValue, OldValue = bOld}); end
            end
            return oComponent;
        end;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getBindings
    @desc Returns an independent complete action map. Every action maps to a
        binding array; empty arrays mean unbound. Modifiers are explicit booleans.
    !]]
    function oComponent.getBindings()
        fAlive(); return _copy(tBindings);
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getBinding
    @desc Returns an independent binding array for one named action.
    !]]
    function oComponent.getBinding(sAction)
        fAlive(); assert(_tActions[sAction], "Unknown image viewer action.");
        return _copy(tBindings[sAction]);
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getDefaultBindings
    @desc Returns independent built-in bindings for display or restoration.
    !]]
    function oComponent.getDefaultBindings()
        fAlive(); return bindings(_tDefaultBindings);
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.setBindings
    @desc Replaces the complete map atomically. Missing actions become unbound;
        invalid/conflicting bindings leave the old map and active drag intact.
        Changed maps cancel a drag. Optional bindingsChanged contains independent
        Bindings/OldBindings snapshots. Unchanged maps do not notify or cancel.
    !]]
    function oComponent.setBindings(tValue, bNotify)
        fAlive(); local tNext = bindings(tValue);
        local bChanged = false;
        for sAction in pairs(_tActions) do
            local tOldList, tNewList = tBindings[sAction], tNext[sAction];
            if (#tOldList ~= #tNewList) then bChanged = true; break; end
            for nIndex, tNew in ipairs(tNewList) do
                for _, sKey in ipairs({"Type", "Key", "Button", "Direction", "Shift", "Command", "Alt", "Tool"}) do
                    if (tNew[sKey] ~= tOldList[nIndex][sKey]) then bChanged = true; break; end
                end
                if (bChanged) then break; end
            end
            if (bChanged) then break; end
        end
        if (bChanged) then
            local tOld = oComponent.getBindings();
            oComponent.cancel(); tBindings = tNext;
            if (bNotify) then tEvents.emit("bindingsChanged", {Bindings = oComponent.getBindings(), OldBindings = tOld}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.setBinding
    @desc Replaces one action's binding array, preserving the rest. An empty
        array unbinds the action. Validation and notifications match setBindings.
    !]]
    function oComponent.setBinding(sAction, tValue, bNotify)
        fAlive(); assert(_tActions[sAction], "Unknown image viewer action.");
        assert(type(tValue) == "table", "Bindings must be an array; use {} to unbind.");
        local tNext = oComponent.getBindings(); tNext[sAction] = tValue;
        return oComponent.setBindings(tNext, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.resetBindings
    @desc Restores the built-in mouse, wheel and keyboard map.
    !]]
    function oComponent.resetBindings(bNotify)
        return oComponent.setBindings(_tDefaultBindings, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fMatchBinding
    @desc Resolves an input against the validated nonoverlapping action map.
        Shift, Command (Ctrl/Meta) and Alt must match exactly. The shared surface
        supplies Shift/Command; physical Alt is sampled only when not supplied.
    !]]
    local function fMatchBinding(sType, vInput, tModifiers)
        tModifiers = tModifiers or {};
        local bAlt = tModifiers.Alt;
        if (bAlt == nil) then bAlt = _wx.wxGetKeyState(_wx.WXK_ALT); end
        for sAction, tList in pairs(tBindings) do
            for _, tBinding in ipairs(tList) do
                local vExpected = sType == "key" and tBinding.Key or sType == "drag" and tBinding.Button or tBinding.Direction;
                if (tBinding.Type == sType and vExpected == vInput and tBinding.Shift == (tModifiers.Shift == true)
                    and tBinding.Command == (tModifiers.Command == true) and tBinding.Alt == (bAlt == true)
                    and (not tBinding.Tool or tBinding.Tool == sTool)) then return sAction; end
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fActionEnabled
    @desc Applies interaction flags after binding resolution so remapping never
        bypasses a disabled action. Cancel always permits cancelling a drag.
    !]]
    local function fActionEnabled(sAction)
        if (sAction == "Pan") then return tInteraction.PanEnabled; end
        if (sAction == "Select") then return tInteraction.SelectionEnabled; end
        if (sAction == "ZoomIn" or sAction == "ZoomOut" or sAction == "Fit" or sAction == "ActualSize") then return tInteraction.ZoomEnabled; end
        return sAction == "Cancel";
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fModifiers
    @desc Reads all binding modifiers from a native event, including Alt which
        is not part of the shared surface's standard modifier payload.
    !]]
    local function fModifiers(oEvent)
        return {Shift = oEvent:ShiftDown(), Command = oEvent:CmdDown() or oEvent:ControlDown() or oEvent:MetaDown(), Alt = oEvent:AltDown()};
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.setTool
    @desc Cancels an active drag and chooses pan or select without clearing the
        committed selection. Optional notification emits toolChanged.
    !]]
    function oComponent.setTool(sValue, bNotify)
        fAlive(); assert(sValue == "pan" or sValue == "select", "Tool must be pan or select.");
        if (sValue ~= sTool) then
            oComponent.cancel(); local sOld = sTool; sTool = sValue;
            if (bNotify) then tEvents.emit("toolChanged", {Tool = sTool, OldTool = sOld}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.setValue
    @desc Loads a path atomically or clears with nil. Failed loads retain the
        current image, view and selection. Successful changes reset to fit and
        clear selection. Optional notifications follow the completed mutation.
    !]]
    function oComponent.setValue(pPath, bNotify)
        fAlive(); assert(pPath == nil or type(pPath) == "string" and pPath ~= "", "Value must be a nonempty path or nil.");
        if (pPath == oComponent.Value) then return oComponent; end
        local oReplacement;
        if (pPath) then
            local hFile = assert(io.open(pPath, "rb"), "Cannot open image: "..pPath); hFile:close();
            oReplacement = _wx.wxImage(pPath, _wx.wxBITMAP_TYPE_ANY);
            if (not oReplacement:IsOk()) then oReplacement:delete(); error("Cannot decode image: "..pPath); end
        end
        local pOld, tOldSelection, tOldView = oComponent.Value, fCopySelection(tSelection), oComponent.getView();
        oComponent.cancel(); fClearRaster();
        if (oImage) then oImage:delete(); end
        oImage, oComponent.Value, tSelection, tHovered = oReplacement, pPath, nil, nil;
        sMode, nZoom, nPanX, nPanY = "fit", 1, 0, 0;
        fViewChanged(tOldView, bNotify); oComponent.refresh();
        if (bNotify) then
            tEvents.emit("valueChanged", {Value = pPath, OldValue = pOld});
            if (tOldSelection) then tEvents.emit("selectionChanged", {OldSelection = tOldSelection}); end
            if (oImage) then tEvents.emit("imageLoaded", {Path = pPath, Width = oImage:GetWidth(), Height = oImage:GetHeight()}); end
            if (oComponent.OnChange) then oComponent.OnChange(pPath, oComponent); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.getViewerState
    @desc Captures detached source path, view, selection, tool, bindings and
        interaction/enabled flags. Decoded pixels and temporary drags are excluded.
    !]]
    function oComponent.getViewerState()
        fAlive();
        return _copy({Value = oComponent.Value, View = oComponent.getView(), Selection = tSelection,
            Tool = sTool, Bindings = tBindings, PanEnabled = tInteraction.PanEnabled,
            ZoomEnabled = tInteraction.ZoomEnabled, SelectionEnabled = tInteraction.SelectionEnabled,
            Enabled = oComponent.Control:IsThisEnabled()});
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.setViewerState
    @desc Silently restores one validated viewer record. A replacement source is
        prepared and selection bounds checked before the current image is released.
        Fit recomputes at the target viewport; manual pan obeys its bounds.
    !]]
    function oComponent.setViewerState(tValue)
        fAlive(); local tNext = viewerState(tValue);
        local bReplace = tNext.Value ~= oComponent.Value;
        local oReplacement;
        if (bReplace and tNext.Value) then
            local hFile = assert(io.open(tNext.Value, "rb"), "Cannot open saved image: "..tNext.Value); hFile:close();
            oReplacement = _wx.wxImage(tNext.Value, _wx.wxBITMAP_TYPE_ANY);
            if (not oReplacement:IsOk()) then oReplacement:delete(); error("Cannot decode saved image."); end
        end
        local oSource = bReplace and oReplacement or oImage;
        -- Clearing a source must not accidentally validate against the old image.
        if (bReplace and not tNext.Value) then oSource = nil; end
        local tRect = tNext.Selection;
        if (tRect and (not oSource or tRect.X + tRect.Width > oSource:GetWidth()
            or tRect.Y + tRect.Height > oSource:GetHeight())) then
            if (oReplacement) then oReplacement:delete(); end
            error("Saved selection must be inside the saved image.");
        end
        oComponent.cancel(); fClearRaster();
        if (bReplace) then
            if (oImage) then oImage:delete(); end
            oImage, oComponent.Value = oReplacement, tNext.Value;
        end
        sMode, nZoom, nPanX, nPanY = tNext.View.Mode, tNext.View.Zoom, tNext.View.PanX, tNext.View.PanY;
        tSelection, sTool, tBindings, tHovered = tNext.Selection, tNext.Tool, tNext.Bindings, nil;
        tInteraction.PanEnabled, tInteraction.ZoomEnabled, tInteraction.SelectionEnabled = tNext.PanEnabled, tNext.ZoomEnabled, tNext.SelectionEnabled;
        fGeometry(); oComponent.setEnabled(tNext.Enabled); oComponent.refresh();
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fHover
    @desc Inspects original source bytes once per entered pixel; nil indicates
        leaving the image or viewport. Hover never invalidates the display raster.
    !]]
    local function fHover(nX, nY)
        local nSourceX, nSourceY, bInside;
        if (nX and nX >= 0 and nY >= 0 and nX < nViewWidth and nY < nViewHeight) then
            nSourceX, nSourceY, bInside = oComponent.clientToImage(nX, nY);
        end
        local tPixel = bInside and oComponent.getPixel(math.floor(nSourceX), math.floor(nSourceY)) or nil;
        if (not tPixel and not tHovered or tPixel and tHovered and tPixel.X == tHovered.X and tPixel.Y == tHovered.Y) then return; end
        tHovered = tPixel; tEvents.emit("pixelHovered", {Pixel = tPixel});
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.fDrag
    @desc Starts or updates captured pan/selection gestures. Selection drag
        endpoints clamp to the source and include both endpoint pixels.
    !]]
    local function fDrag(sEvent, nX, nY, sOperation)
        if (not oImage) then return; end
        if (sEvent == "down") then
            local nSourceX, nSourceY, bInside = oComponent.clientToImage(nX, nY);
            if (sOperation == "select" and not bInside) then return; end
            local tView = oComponent.getView();
            tDrag = {Tool = sOperation, X = nX, Y = nY, PanX = tView.PanX, PanY = tView.PanY,
                SourceX = math.floor(nSourceX), SourceY = math.floor(nSourceY)};
        elseif (tDrag and (sEvent == "move" or sEvent == "up")) then
            if (tDrag.Tool == "pan") then
                oComponent.setPan(tDrag.PanX + nX - tDrag.X, tDrag.PanY + nY - tDrag.Y, true);
            else
                local nSourceX, nSourceY = oComponent.clientToImage(nX, nY);
                nSourceX = math.max(0, math.min(oImage:GetWidth() - 1, math.floor(nSourceX)));
                nSourceY = math.max(0, math.min(oImage:GetHeight() - 1, math.floor(nSourceY)));
                tDrag.Selection = {X = math.min(tDrag.SourceX, nSourceX), Y = math.min(tDrag.SourceY, nSourceY),
                    Width = math.abs(nSourceX - tDrag.SourceX) + 1, Height = math.abs(nSourceY - tDrag.SourceY) + 1};
                oComponent.refresh();
            end
        end
        if (sEvent == "up" and tDrag) then
            local tNext = tDrag.Selection; tDrag = nil;
            if (tNext) then oComponent.setSelection(tNext, true); end
        end
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.pointer
    @desc Routes shared captured left-button gestures and source-pixel hover.
    !]]
    oComponent.pointer = function(sEvent, nX, nY, tModifiers)
        if (sEvent == "down" and oComponent.Pressed) then
            local sAction = fMatchBinding("drag", "left", tModifiers);
            if (sAction and fActionEnabled(sAction)) then
                fDrag(sEvent, nX, nY, sAction == "Pan" and "pan" or "select");
                if (tDrag) then tDrag.Button = "left"; end
            else
                -- The surface captures before calling widget policy. A blocked
                -- or unbound left gesture must immediately release that capture.
                oComponent.cancel();
            end
        elseif (sEvent == "move" or sEvent == "up" and tDrag and tDrag.Button == "left") then
            fDrag(sEvent, nX, nY);
        end
        fHover(sEvent ~= "leave" and nX or nil, nY);
    end;

    --[[!
    @fqxn wxLuma.UI.ImageViewer.onCancel
    @desc Discards uncommitted selection previews on Escape, capture loss,
        disable, focus loss, image replacement or disposal. Committed pan stays.
    !]]
    oComponent.onCancel = function()
        if (tDrag) then tDrag = nil; oComponent.refresh(); end
    end;

    --[[!
    @fqxn wxLuma.UI.ImageViewer.handleWheel
    @desc Zooms around explicit client coordinates. Disabled/empty viewers ignore
        input. Rotation is measured in wheel notches, including fractional ones.
        Handled zoom takes keyboard focus so the next bound key targets this
        viewer even when the mouse wheel was used without a preceding click.
    !]]
    function oComponent.handleWheel(nRotation, nX, nY, tModifiers)
        if (not oComponent.isEnabled() or not oImage) then return false; end
        number(nRotation); number(nX); number(nY);
        if (nRotation == 0 or nX < 0 or nY < 0 or nX >= nViewWidth or nY >= nViewHeight) then return false; end
        local sAction = fMatchBinding("wheel", nRotation > 0 and 1 or -1, tModifiers);
        if (not sAction or not fActionEnabled(sAction)) then return false; end
        -- Hover-wheel input can arrive while a toolbar or binding picker owns
        -- focus. Keep the next keyboard action on the image being manipulated.
        oComponent.Control:SetFocus();
        oComponent.cancel();
        local nSteps = math.abs(nRotation) * (sAction == "ZoomIn" and 1 or -1);
        oComponent.setZoom(math.max(0.000001, math.min(64, oComponent.getZoom() * 1.25 ^ nSteps)), true, nX, nY);
        fHover(nX, nY); return true;
    end
    -- The surface's wheel hook has no coordinates. Observe the native event
    -- directly instead of reducing cursor-anchored zoom to center-only zoom.
    oComponent.Control:Connect(_wx.wxEVT_MOUSEWHEEL, function(oEvent)
        local nDelta = oEvent:GetWheelDelta();
        if (nDelta == 0 or not oComponent.handleWheel(oEvent:GetWheelRotation() / nDelta, oEvent:GetX(), oEvent:GetY(), fModifiers(oEvent))) then oEvent:Skip(); end
    end);

    --[[!
    @fqxn wxLuma.UI.ImageViewer.handleDragInput
    @desc Routes bound middle/right gestures with explicit capture. Motion is
        shared with the surface; only the owning button completes the gesture.
        Disabled or unbound actions do not acquire focus or capture.
    !]]
    function oComponent.handleDragInput(sButton, sEvent, nX, nY, tModifiers)
        if (not oComponent.isEnabled() or not oImage) then return; end
        number(nX); number(nY);
        if (sEvent == "down") then
            if (nX < 0 or nY < 0 or nX >= nViewWidth or nY >= nViewHeight) then return; end
            local sAction = fMatchBinding("drag", sButton, tModifiers);
            if (not sAction or not fActionEnabled(sAction)) then return; end
            oComponent.cancel(); oComponent.Control:SetFocus();
            if (not oComponent.Control:HasCapture()) then oComponent.Control:CaptureMouse(); end
            fDrag(sEvent, nX, nY, sAction == "Pan" and "pan" or "select");
            if (tDrag) then tDrag.Button = sButton; else oComponent.cancel(); end
        elseif (tDrag and tDrag.Button == sButton) then
            fDrag(sEvent, nX, nY);
            if (sEvent == "up") then oComponent.cancel(); end
        end
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.handlePan
    @desc Compatibility adapter for the middle button; follows its current
        binding and the relevant interaction flag, rather than forcing pan.
    !]]
    function oComponent.handlePan(sEvent, nX, nY, tModifiers)
        return oComponent.handleDragInput("middle", sEvent, nX, nY, tModifiers);
    end
    for _, tButton in ipairs({{"middle", _wx.wxEVT_MIDDLE_DOWN, _wx.wxEVT_MIDDLE_UP}, {"right", _wx.wxEVT_RIGHT_DOWN, _wx.wxEVT_RIGHT_UP}}) do
        local sButton = tButton[1];
        oComponent.Control:Connect(tButton[2], function(oEvent) oComponent.handleDragInput(sButton, "down", oEvent:GetX(), oEvent:GetY(), fModifiers(oEvent)); end);
        oComponent.Control:Connect(tButton[3], function(oEvent) oComponent.handleDragInput(sButton, "up", oEvent:GetX(), oEvent:GetY(), fModifiers(oEvent)); end);
    end

    --[[!
    @fqxn wxLuma.UI.ImageViewer.key
    @desc Provides fit, actual-size, centered zoom and selection cancellation
        without consuming unrelated keys or command shortcuts.
    !]]
    oComponent.key = function(nKey, tModifiers)
        local sAction = fMatchBinding("key", nKey, tModifiers);
        if (not sAction or not fActionEnabled(sAction)) then return false; end
        if (sAction == "Cancel") then
            if (tDrag) then oComponent.cancel();
            elseif (tInteraction.SelectionEnabled) then oComponent.setSelection(nil, true);
            else return false; end
        elseif (sAction == "Fit") then oComponent.fit(true);
        elseif (sAction == "ActualSize") then oComponent.actualSize(true);
        elseif (sAction == "ZoomIn") then
            oComponent.setZoom(math.min(64, oComponent.getZoom() * 1.25), true);
        elseif (sAction == "ZoomOut") then
            oComponent.setZoom(math.max(0.000001, oComponent.getZoom() / 1.25), true);
        else return false; end
        return true;
    end;

    --[[!
    @fqxn wxLuma.UI.ImageViewer.onLayout
    @desc Invalidates the viewport raster after resize and recalculates fit or
        pan bounds. Resizing preserves committed source selection.
    !]]
    oComponent.onLayout = function(nWidth, nHeight)
        if (nWidth == nViewWidth and nHeight == nViewHeight) then return; end
        oComponent.cancel(); nViewWidth, nViewHeight = nWidth, nHeight;
        fGeometry(); fClearRaster(); oComponent.refresh();
    end;

    --[[!
    @fqxn wxLuma.UI.ImageViewer.draw
    @desc Paints through the ordinary DC path. Crops before scaling so even at
        64x zoom the retained bitmap is bounded by the viewport plus sampling
        margins. Repeated paints reuse it; hover and selection do not rebuild it.
    !]]
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed or nWidth < 1 or nHeight < 1) then return; end
        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, nWidth, nHeight));
        local oBrush = _wx.wxBrush(tArt.color(oComponent.isEnabled() and "Plot Normal" or "Plot Disabled"));
        oDC:SetBrush(oBrush); oDC:SetPen(_wx.wxTRANSPARENT_PEN); oDC:DrawRectangle(0, 0, nWidth, nHeight); oBrush:delete();
        if (oImage) then
            local nX, nY, nScale = fGeometry(nWidth, nHeight);
            -- A cached offscreen projection must never become the live view or
            -- be reused at another destination size/geometry.
            if (tRaster and (tRaster.Width ~= nWidth or tRaster.Height ~= nHeight
                or tRaster.OriginX ~= nX or tRaster.OriginY ~= nY or tRaster.Scale ~= nScale)) then fClearRaster(); end
            if (not tRaster) then
                -- One extra source pixel on each side supplies filtering samples.
                local nLeft = math.max(0, math.floor(-nX / nScale) - 1);
                local nTop = math.max(0, math.floor(-nY / nScale) - 1);
                local nRight = math.min(oImage:GetWidth(), math.ceil((nWidth - nX) / nScale) + 1);
                local nBottom = math.min(oImage:GetHeight(), math.ceil((nHeight - nY) / nScale) + 1);
                local oRect = _wx.wxRect(nLeft, nTop, nRight - nLeft, nBottom - nTop);
                local oCrop = oImage:GetSubImage(oRect); oRect:delete();
                local nW = math.max(1, math.floor((nRight - nLeft) * nScale + 0.5));
                local nH = math.max(1, math.floor((nBottom - nTop) * nScale + 0.5));
                local oScaled = oCrop:Scale(nW, nH, nScale >= 1 and _wx.wxIMAGE_QUALITY_NEAREST or _wx.wxIMAGE_QUALITY_HIGH);
                tRaster = {Bitmap = _wx.wxBitmap(oScaled), X = math.floor(nX + nLeft * nScale + 0.5),
                    Y = math.floor(nY + nTop * nScale + 0.5), Width = nWidth, Height = nHeight,
                    OriginX = nX, OriginY = nY, Scale = nScale};
                oScaled:delete(); oCrop:delete();
            end
            oDC:DrawBitmap(tRaster.Bitmap, tRaster.X, tRaster.Y, true);
            local tRect = tDrag and tDrag.Selection or tSelection;
            if (tRect) then
                local oPen = _wx.wxPen(tArt.color("Axis Selected"), 1, _wx.wxPENSTYLE_SOLID);
                oDC:SetPen(oPen); oDC:SetBrush(_wx.wxTRANSPARENT_BRUSH);
                oDC:DrawRectangle(math.floor(nX + tRect.X * nScale), math.floor(nY + tRect.Y * nScale),
                    math.max(1, math.floor(tRect.Width * nScale)), math.max(1, math.floor(tRect.Height * nScale)));
                oPen:delete();
            end
        end
        oClip:delete();
    end;

    --[[!
    @fqxn wxLuma.UI.ImageViewer.onDestroy
    @desc Releases each private bitmap, decoded image and sampled skin resource
        exactly once. The shared surface owns cancellation and disposal guards.
    !]]
    oComponent.onDestroy = function()
        fClearRaster();
        if (oImage) then oImage:delete(); oImage = nil; end
        tSelection, tHovered = nil, nil; tArt.destroy();
    end;
    oComponent.setValue(tOptions.Value);
    _Theme.finish(oComponent, tOptions);
    return oComponent;
end

_State.register("wxLuma.UI.ImageViewer", {
    capture = function(oComponent) return oComponent.getViewerState(); end,
    validate = function(tValue) viewerState(tValue); end,
    restore = function(oComponent, tValue) oComponent.setViewerState(tValue); end,
});

return ImageViewer;
