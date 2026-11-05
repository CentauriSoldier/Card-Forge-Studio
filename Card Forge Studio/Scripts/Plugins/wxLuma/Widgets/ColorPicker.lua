local _wx          = require("wx");
local _Surface     = require("wxLuma.Core.ControlSurface");
local _Events      = require("wxLuma.Core.ControlEvents");
local _Artwork     = require("wxLuma.Core.ControlArtwork");
local _Containment = require("wxLuma.Core.ControlContainment");
local _Color       = require("wxLuma.Core.ControlColor");
local ColorPicker  = {};
local _tChannels   = {"R", "G", "B", "H", "S", "V", "A"};
local _tMax        = {255, 255, 255, 360, 100, 100, 255};

--[[!
@fqxn wxLuma.UI.ColorPicker.create
@desc Creates a color button with a contained, fully drawn RGB/HSV/alpha editor.
    Pointer sliders and keyboard arrows edit a preview; Apply/Enter commits while
    Escape, outside activation or hiding cancels. No native editor colors are used.
@param wxWindow oParent Native owner.
@param table tOptions Skin; optional Value ({R,G,B,A}, default opaque white),
    Swatches (up to ten RGBA tables), Artwork (Color Picker), Enabled, OnChange.
@ret table oComponent Standard surface/events with get/setValue, get/setHSV,
    get/setSwatches, open/close/isOpen and getPreview.
!]]
function ColorPicker.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "ColorPicker requires Skin.");
    local tValue = _Color.rgba(tOptions.Value or {R = 255, G = 255, B = 255});
    local tSwatches = {};
    local tEvents;
    local bOpen = false;
    local nRow = 1;
    local nDrag;
    local sPressed, sActionHover;
    local tPreview = _Color.rgba(tValue);
    local tHSV = _Color.hsv(tPreview);

    --[[!
    @fqxn wxLuma.UI.ColorPicker.fSwatches
    @desc Copies and validates a dense array of up to ten application color swatches.
    !]]
    local function fSwatches(tSource)
        assert(type(tSource) == "table" and #tSource <= 10, "Use up to ten swatches.");
        local tCopy = {};
        local nCount = 0;
        for nKey in pairs(tSource) do
            nCount = nCount + 1;
            assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tSource,
                "Swatches must be a dense array.");
        end
        assert(nCount == #tSource, "Swatches must be a dense array.");
        for nIndex, tColor in ipairs(tSource) do
            tCopy[nIndex] = _Color.rgba(tColor);
        end
        return tCopy;
    end
    tSwatches = fSwatches(tOptions.Swatches or {
        {R = 255, G = 255, B = 255}, {R = 0, G = 0, B = 0},
        {R = 220, G = 60, B = 60}, {R = 60, G = 190, B = 90},
        {R = 60, G = 120, B = 230}, {R = 240, G = 200, B = 60},
        {R = 160, G = 80, B = 220}, {R = 0, G = 0, B = 0, A = 0}
    });
    local oComponent = _Surface.create(oParent, tOptions, "ColorPicker");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Color Picker");
    local tPolicy = _Containment.getPolicy(oComponent);
    local oPopup = _wx.wxFrame(oComponent.Control, _wx.wxID_ANY, "", _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxFRAME_NO_TASKBAR + _wx.wxFRAME_FLOAT_ON_PARENT + _wx.wxBORDER_NONE);
    local oEditor = _Surface.create(oPopup, {Skin = tOptions.Skin}, "ColorPickerEditor");
    oComponent.Popup, oComponent.Editor = oPopup, oEditor;
    local nPopupWidth, nPopupHeight = 360, 360;

    --[[!
    @fqxn wxLuma.UI.ColorPicker.fEqual
    @desc Compares complete RGBA values without comparing caller table identities.
    !]]
    local function fEqual(tLeft, tRight)
        return tLeft.R == tRight.R and tLeft.G == tRight.G and tLeft.B == tRight.B and tLeft.A == tRight.A;
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.fPreview
    @desc Updates private preview channels, preserving an explicit HSV hue even
        for gray/black colors whose RGB representation cannot retain that hue.
    !]]
    local function fPreview(tColor, tSourceHSV)
        local bChanged = not fEqual(tPreview, tColor);
        tPreview = _Color.rgba(tColor);
        tHSV = tSourceHSV or _Color.hsv(tPreview);
        oEditor.refresh();
        if (bChanged) then
            tEvents.emit("previewChanged", {Value = _Color.rgba(tPreview)});
        end
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.getValue
    @desc Returns an independent committed RGBA color, including alpha.
    @ret table tColor R/G/B/A bytes.
    !]]
    function oComponent.getValue()
        return _Color.rgba(tValue);
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.setValue
    @desc Atomically sets committed RGBA. A binding update also replaces an open
        preview. Identical values do not repaint or notify.
    @param table tColor R/G/B and optional A (255).
    @param boolean|nil bNotify Emit valueChanged and OnChange after a change.
    @ret table oComponent This object.
    !]]
    function oComponent.setValue(tColor, bNotify)
        assert(not oComponent.Disposed, "ColorPicker is disposed.");
        local tNext = _Color.rgba(tColor);
        local tOld = tValue;
        local bChanged = not fEqual(tOld, tNext);
        tValue = tNext;
        if (bOpen) then
            fPreview(tNext);
        end
        if (bChanged) then
            oComponent.refresh();
            if (bNotify) then
                tEvents.emit("valueChanged", {Value = _Color.rgba(tNext), OldValue = _Color.rgba(tOld)});
                if (oComponent.OnChange) then
                    oComponent.OnChange(_Color.rgba(tNext), oComponent);
                end
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.getHSV
    @desc Returns committed H degrees, S/V percentages, and alpha byte.
    @ret table tHSV Independent converted color.
    !]]
    function oComponent.getHSV()
        return _Color.hsv(tValue);
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.setHSV
    @desc Sets committed color from HSV, preserving current alpha when omitted.
    @param table tColor H (degrees), S/V (0-100), optional A byte.
    @param boolean|nil bNotify Notify an effective RGBA change.
    @ret table oComponent This object.
    !]]
    function oComponent.setHSV(tColor, bNotify)
        assert(type(tColor) == "table", "HSV must be a table.");
        return oComponent.setValue(_Color.fromHSV({H = tColor.H, S = tColor.S, V = tColor.V,
            A = tColor.A == nil and tValue.A or tColor.A}), bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.getPreview
    @desc Returns an independent preview while open, otherwise the committed color.
    @ret table tColor RGBA bytes.
    !]]
    function oComponent.getPreview()
        return _Color.rgba(bOpen and tPreview or tValue);
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.getSwatches
    @desc Returns independent swatch color copies.
    @ret table tSwatches Ordered RGBA colors.
    !]]
    function oComponent.getSwatches()
        return fSwatches(tSwatches);
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.setSwatches
    @desc Atomically replaces the palette without modifying committed/preview color.
    @param table tSource Up to ten RGBA tables.
    @param boolean|nil bNotify Emit swatchesChanged.
    @ret table oComponent This object.
    !]]
    function oComponent.setSwatches(tSource, bNotify)
        local tNext = fSwatches(tSource);
        tSwatches = tNext;
        oEditor.refresh();
        if (bNotify) then
            tEvents.emit("swatchesChanged", {Swatches = oComponent.getSwatches()});
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.isOpen
    @desc Reports whether the live preview editor is open.
    @ret boolean bOpen Popup state.
    !]]
    function oComponent.isOpen()
        return not oComponent.Disposed and bOpen;
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.close
    @desc Hides and resets the editor before callbacks. Commit publishes preview;
        all other dismissal paths preserve the committed color.
    @param boolean|nil bCommit Whether to apply the preview.
    @param boolean|nil bFocus Restore focus unless false.
    @ret table oComponent This object.
    !]]
    function oComponent.close(bCommit, bFocus)
        if (not bOpen) then
            return oComponent;
        end
        local tResult = _Color.rgba(tPreview);
        bOpen = false;
        nDrag, sPressed, sActionHover, nRow = nil, nil, nil, 1;
        oEditor.cancel();
        oPopup:Hide();
        if (bFocus ~= false and oComponent.isEnabled()) then
            oComponent.Control:SetFocus();
        end
        if (bCommit) then
            oComponent.setValue(tResult, true);
        end
        tPreview = _Color.rgba(tValue);
        tHSV = _Color.hsv(tPreview);
        tEvents.emit(bCommit and "committed" or "cancelled", {Value = _Color.rgba(bCommit and tResult or tValue)});
        tEvents.emit("closed", {Committed = bCommit == true});
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.open
    @desc Opens at its natural size, shifting only overflowing position axes.
        Oversized popup handling follows the shared containment overflow policy.
    @ret boolean bOpened Whether containment and enabled/visibility policy permit opening.
    !]]
    function oComponent.open()
        if (bOpen or not oComponent.isEnabled() or not oComponent.Control:IsShownOnScreen()) then
            return false;
        end
        oPopup:SetClientSize(nPopupWidth, nPopupHeight);
        oEditor.layout(0, 0, nPopupWidth, nPopupHeight);
        if (not tPolicy.place(oPopup)) then
            return false;
        end
        tPreview, tHSV = _Color.rgba(tValue), _Color.hsv(tValue);
        nRow, bOpen = 1, true;
        oPopup:Show(true);
        oPopup:Raise();
        oEditor.Control:SetFocus();
        oEditor.refresh();
        tEvents.emit("opened");
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.fChannel
    @desc Applies one slider channel to preview, linking RGB and HSV immediately.
    !]]
    local function fChannel(nIndex, nValue)
        nValue = math.max(0, math.min(_tMax[nIndex], nValue));
        local sChannel = _tChannels[nIndex];
        if (nIndex >= 4 and nIndex <= 6) then
            local tNext = {H = tHSV.H, S = tHSV.S, V = tHSV.V, A = tPreview.A};
            tNext[sChannel] = nValue;
            fPreview(_Color.fromHSV(tNext), tNext);
        else
            local tNext = _Color.rgba(tPreview);
            tNext[sChannel] = math.floor(nValue + 0.5);
            fPreview(tNext);
        end
    end

    --[[!
    @fqxn wxLuma.UI.ColorPicker.fSwatch
    @desc Draws the represented color over skin-defined checker colors. The
        RGBA blend is value data; checker and frame decoration remain skinnable.
    !]]
    local function fSwatch(oDC, tColor, nX, nY, nWidth, nHeight)
        local oLight, oDark = tArt.color("Check Light"), tArt.color("Check Dark");
        for nOffsetY = 0, nHeight - 1, 6 do
            for nOffsetX = 0, nWidth - 1, 6 do
                local oBase = ((math.floor(nOffsetX / 6) + math.floor(nOffsetY / 6)) % 2 == 0) and oLight or oDark;
                local nAlpha = tColor.A / 255;
                local oColor = _wx.wxColour(math.floor(tColor.R * nAlpha + oBase:Red() * (1 - nAlpha) + 0.5),
                    math.floor(tColor.G * nAlpha + oBase:Green() * (1 - nAlpha) + 0.5),
                    math.floor(tColor.B * nAlpha + oBase:Blue() * (1 - nAlpha) + 0.5));
                local oBrush = _wx.wxBrush(oColor);
                oDC:SetBrush(oBrush);
                oDC:SetPen(_wx.wxTRANSPARENT_PEN);
                oDC:DrawRectangle(nX + nOffsetX, nY + nOffsetY,
                    math.min(6, nWidth - nOffsetX), math.min(6, nHeight - nOffsetY));
                oBrush:delete();
                oColor:delete();
            end
        end
    end
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end
        local sState = oComponent.getState();
        tArt.part(oDC, "Surface "..sState, 0, 0, nWidth, nHeight);
        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(4, 4, math.max(1, nWidth - 8), math.max(1, nHeight - 8)));
        fSwatch(oDC, tValue, 8, 8, math.max(1, math.min(48, nWidth - 16)), math.max(1, nHeight - 16));
        tArt.text(oDC, string.format("#%02X%02X%02X%02X", tValue.R, tValue.G, tValue.B, tValue.A),
            68, (nHeight - 18) / 2, oComponent.isEnabled());
        oClip:delete();
    end;
    oComponent.pointer = function(sEvent)
        if (sEvent == "up" and oComponent.Pressed and oComponent.Hover) then
            oComponent.open();
        end
    end;
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_SPACE or nKey == _wx.WXK_RETURN or nKey == _wx.WXK_DOWN) then
            return oComponent.open();
        end
        return false;
    end;
    oEditor.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end
        tArt.part(oDC, "Popup", 0, 0, nWidth, nHeight);
        fSwatch(oDC, tPreview, 12, 12, 48, 28);
        tArt.text(oDC, string.format("#%02X%02X%02X%02X", tPreview.R, tPreview.G, tPreview.B, tPreview.A), 72, 16, true);
        for nIndex, sChannel in ipairs(_tChannels) do
            local nY = 54 + (nIndex - 1) * 32;
            local nValue = nIndex >= 4 and nIndex <= 6 and tHSV[sChannel] or tPreview[sChannel];
            tArt.text(oDC, sChannel.." "..math.floor(nValue + 0.5), 12, nY + 4, true);
            tArt.part(oDC, "Track", 92, nY + 7, 244, 12);
            local nFill = math.floor(nValue / _tMax[nIndex] * 244);
            tArt.part(oDC, "Fill", 92, nY + 7, nFill, 12);
            tArt.part(oDC, "Thumb", 88 + nFill, nY + 3, 8, 20);
            if (nIndex == nRow) then
                tArt.part(oDC, "Focus", 8, nY + 26, 336, 2);
            end
        end
        for nIndex, tColor in ipairs(tSwatches) do
            local nX = 12 + (nIndex - 1) * 33;
            tArt.part(oDC, "Swatch", nX, 284, 28, 26);
            fSwatch(oDC, tColor, nX + 2, 286, 24, 22);
        end
        tArt.part(oDC, "Action "..(sPressed == "apply" and "Pressed" or sActionHover == "apply" and "Hover" or "Normal"),
            144, 320, 96, 28);
        tArt.part(oDC, "Action "..(sPressed == "cancel" and "Pressed" or sActionHover == "cancel" and "Hover" or "Normal"),
            248, 320, 96, 28);
        tArt.text(oDC, "Apply", 168, 324, true);
        tArt.text(oDC, "Cancel", 266, 324, true);
    end;
    oEditor.onCancel = function()
        nDrag, sPressed = nil, nil;
    end;
    oEditor.pointer = function(sEvent, nX, nY)
        local sHit;
        if (nY >= 320 and nY < 348) then
            if (nX >= 144 and nX < 240) then
                sHit = "apply";
            elseif (nX >= 248 and nX < 344) then
                sHit = "cancel";
            end
        end
        if (sEvent == "leave") then
            sHit = nil;
        end
        if (sActionHover ~= sHit) then
            sActionHover = sHit;
            oEditor.refresh();
        end
        if (sEvent == "down") then
            sPressed = sHit;
            oEditor.refresh();
            if (nY >= 54 and nY < 278 and nX >= 88 and nX <= 340) then
                nDrag = math.floor((nY - 54) / 32) + 1;
                nRow = nDrag;
                fChannel(nDrag, (nX - 92) / 244 * _tMax[nDrag]);
            elseif (nY >= 284 and nY < 310 and nX >= 12) then
                local nIndex = math.floor((nX - 12) / 33) + 1;
                if (tSwatches[nIndex] and (nX - 12) % 33 < 28) then
                    fPreview(tSwatches[nIndex]);
                end
            end
        elseif (sEvent == "move" and nDrag and oEditor.Pressed) then
            fChannel(nDrag, (nX - 92) / 244 * _tMax[nDrag]);
        elseif (sEvent == "up" and sHit and sPressed == sHit) then
            oComponent.close(sHit == "apply");
        end
    end;
    oEditor.key = function(nKey, tModifiers)
        if (nKey == _wx.WXK_ESCAPE) then
            oComponent.close(false);
        elseif (nKey == _wx.WXK_RETURN or nKey == _wx.WXK_NUMPAD_ENTER) then
            oComponent.close(true);
        elseif (nKey == _wx.WXK_UP or nKey == _wx.WXK_DOWN or nKey == _wx.WXK_TAB) then
            local nDelta = (nKey == _wx.WXK_UP or (nKey == _wx.WXK_TAB and tModifiers and tModifiers.Shift)) and -1 or 1;
            if (nKey == _wx.WXK_UP) then
                nDelta = -1;
            end
            nRow = (nRow - 1 + nDelta) % 7 + 1;
            oEditor.refresh();
        elseif (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_RIGHT or nKey == _wx.WXK_PAGEUP
            or nKey == _wx.WXK_PAGEDOWN or nKey == _wx.WXK_HOME or nKey == _wx.WXK_END) then
            local sChannel = _tChannels[nRow];
            local nValue = nRow >= 4 and nRow <= 6 and tHSV[sChannel] or tPreview[sChannel];
            local nDelta = (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_PAGEDOWN) and -1 or 1;
            if (nKey == _wx.WXK_PAGEUP or nKey == _wx.WXK_PAGEDOWN) then
                nDelta = nDelta * 10;
            end
            fChannel(nRow, nKey == _wx.WXK_HOME and 0 or nKey == _wx.WXK_END and _tMax[nRow] or nValue + nDelta);
        else
            return false;
        end
        return true;
    end;
    oPopup:Connect(_wx.wxEVT_ACTIVATE, function(jEvent)
        if (not jEvent:GetActive()) then
            oComponent.close(false, false);
        end
        jEvent:Skip();
    end);
    oPopup:Connect(_wx.wxEVT_SHOW, function(jEvent)
        if (not jEvent:IsShown() and bOpen) then
            oComponent.close(false, false);
        end
        jEvent:Skip();
    end);
    oPopup:Connect(_wx.wxEVT_CHAR_HOOK, function(jEvent)
        if (jEvent:GetKeyCode() == _wx.WXK_ESCAPE or jEvent:GetKeyCode() == _wx.WXK_RETURN
            or jEvent:GetKeyCode() == _wx.WXK_NUMPAD_ENTER) then
            oEditor.handleKey("down", jEvent:GetKeyCode());
        else
            jEvent:Skip();
        end
    end);
    oComponent.onEnable = function(bEnabled)
        if (not bEnabled) then
            oComponent.close(false, false);
        end
    end;
    oComponent.onDestroy = function()
        bOpen = false;
        oEditor.destroy();
        oPopup:Destroy();
        tArt.destroy();
    end;
    tPolicy.watch(function(sReason)
        if (bOpen and (sReason == "destroy" or not tPolicy.place(oPopup))) then
            oComponent.close(false, false);
        end
    end);
    tEvents = _Events.attach(oComponent, {oEditor.Control}, {"opened", "closed", "previewChanged",
        "committed", "cancelled", "swatchesChanged"});
    return oComponent;
end

return ColorPicker;
