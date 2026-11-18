local _wx      = require("wx");
local _Object  = require("wxLuma.Core.ControlObject");
local _Skin    = require("wxLuma.Core.ControlSkin");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _Drawing = require("wxLuma.Core.ControlDrawing");
local _System  = require("wxLuma.Core.SystemArtwork");
local _Color   = require("wxLuma.Core.ControlColor");
local ControlTheme = {};
local _oDefault;
local _tThemes = setmetatable({}, {__mode = "k"});
local _tWindows = setmetatable({}, {__mode = "v"});
local _tBackgroundRoles = {};

--[[!
@fqxn wxLuma.UI.ControlTheme.cast
@desc Returns a native subclass when supported. wxLua raises on an unrelated
    class rather than returning nil, so probing must catch that result.
!]]
local function cast(oObject, sClass)
    local bOK, oResult = pcall(oObject.DynamicCast, oObject, sClass);
    return bOK and oResult or nil;
end

-- Semantic roles are shared by native surfaces and custom iris geometry.
local _tSystemColors = {
    Background = _wx.wxSYS_COLOUR_BTNFACE,
    Editor = _wx.wxSYS_COLOUR_WINDOW,
    Text = _wx.wxSYS_COLOUR_WINDOWTEXT,
    DisabledText = _wx.wxSYS_COLOUR_GRAYTEXT,
    Border = _wx.wxSYS_COLOUR_BTNSHADOW,
    Fill = _wx.wxSYS_COLOUR_HIGHLIGHT,
    Track = _wx.wxSYS_COLOUR_WINDOW,
    Blade = _wx.wxSYS_COLOUR_BTNFACE,
    ["Blade Alternate"] = _wx.wxSYS_COLOUR_3DLIGHT,
    Reserve = _wx.wxSYS_COLOUR_BTNSHADOW,
    Seam = _wx.wxSYS_COLOUR_BTNTEXT,
    Hover = _wx.wxSYS_COLOUR_3DLIGHT,
    Selection = _wx.wxSYS_COLOUR_HIGHLIGHT,
    SelectionText = _wx.wxSYS_COLOUR_HIGHLIGHTTEXT,
};

--[[!
@fqxn wxLuma.UI.ControlTheme.create
@desc Creates an application-owned appearance context shared by custom controls.
    System requires no artwork. Obsidian borrows the existing artwork package's
    visual design. Destroy the context after its controls; no native window is owned.
@param string|nil sInitial System (default) or Obsidian.
@param string|nil pArtwork Skin root with object subdirectories, required for Obsidian.
@ret table oTheme Shared context with live renderer switching.
!]]
function ControlTheme.create(sInitial, pArtwork)
    local oTheme = _Object.create({Revision = 0}, "wxLuma.UI.ControlTheme");
    local sName;
    local oSkin, oFont;
    local tColors, tArtwork = {}, {};
    local tBitmaps, tBitmapOrder = {}, {};
    local tSubscribers = setmetatable({}, {__mode = "k"});
    local tAttached = setmetatable({}, {__mode = "k"});
    local tIndicatorSizes = {};
    local bDisposed = false;
    _tThemes[oTheme] = true;

    --[[!
    @fqxn wxLuma.UI.ControlTheme.release
    @desc Releases context-owned resources after widget-owned caches are discarded.
    !]]
    local function fRelease()
        for _, tArt in pairs(tArtwork) do tArt.destroy(); end
        for _, oColor in pairs(tColors) do oColor:delete(); end
        for _, tEntry in pairs(tBitmaps) do tEntry.Bitmap:delete(); end
        if (oSkin) then oSkin.destroy(); end
        if (oFont) then oFont:delete(); end
        tColors, tArtwork, oSkin, oFont = {}, {}, nil, nil;
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.artworkFamily
    @desc Lazily resolves an Obsidian image palette; System never takes this path.
    !]]
    local function fArtwork(sPrefix)
        if (not tArtwork[sPrefix]) then tArtwork[sPrefix] = _Artwork.create(oSkin, sPrefix); end
        return tArtwork[sPrefix];
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.getName
    @desc Returns the selected rendering provider name.
    !]]
    function oTheme.getName() return sName; end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.setBackgroundRole
    @desc Assigns a semantic role to an owned native surface. Ancestor refreshes
        honor the assignment, so callback order cannot replace a content palette
        with the generic window background. Native destruction removes it.
    !]]
    function oTheme.setBackgroundRole(oWindow, sRole)
        assert(_tSystemColors[sRole], "Unknown background role.");
        local nID = oWindow:GetId();
        local tRole = _tBackgroundRoles[nID];
        if (not tRole) then
            oWindow:Connect(_wx.wxEVT_DESTROY, function(oEvent)
                if (oEvent:GetId() == nID) then _tBackgroundRoles[nID] = nil; end
                oEvent:Skip();
            end);
        end
        _tBackgroundRoles[nID] = {Theme = oTheme, Role = sRole};
        oWindow:SetBackgroundColour(oTheme.color(sRole));
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.indicatorSize
    @desc Measures an unlabeled native checkbox at the host's DPI. Only numeric
        dimensions are cached; the hidden measuring control is destroyed at once.
    @ret number nWidth Native indicator width, followed by height.
    !]]
    function oTheme.indicatorSize(oWindow)
        local nScale = oWindow:FromDIP(100);
        if (not tIndicatorSizes[nScale]) then
            local oProbe = _wx.wxCheckBox(oWindow, _wx.wxID_ANY, "");
            oProbe:Hide();
            local oSize = oProbe:GetBestSize();
            tIndicatorSizes[nScale] = {oSize:GetWidth(), oSize:GetHeight()};
            oSize:delete(); oProbe:Destroy();
        end
        return table.unpack(tIndicatorSizes[nScale]);
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.color
    @desc Returns a borrowed semantic color; callers must not delete it.
    !]]
    function oTheme.color(sRole, bEnabled)
        assert(not bDisposed and _tSystemColors[sRole], "Unknown theme color role.");
        local sKey = sRole..":"..tostring(bEnabled);
        if (not tColors[sKey]) then
            if (sName == "System") then
                local nIndex = (bEnabled == false and (sRole == "Text" or sRole == "Fill"))
                    and _wx.wxSYS_COLOUR_GRAYTEXT or _tSystemColors[sRole];
                tColors[sKey] = _wx.wxSystemSettings.GetColour(nIndex);
            else
                local tRGB = ({Background = {24, 29, 36}, Editor = {24, 29, 36},
                    Text = {208, 218, 230}, DisabledText = {114, 126, 139},
                    Border = {68, 78, 89}})[sRole] or {88, 120, 148};
                if (sRole == "Text" and bEnabled == false) then tRGB = {114, 126, 139}; end
                tColors[sKey] = _wx.wxColour(table.unpack(tRGB));
            end
        end
        return tColors[sKey];
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.fill
    @desc Fills explicit bounds with a semantic surface, preserving native DC ownership.
    !]]
    function oTheme.fill(oDC, sRole, nX, nY, nWidth, nHeight, bEnabled)
        local oBrush = _wx.wxBrush(oTheme.color(sRole, bEnabled));
        oDC:SetBrush(oBrush); oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        oDC:DrawRectangle(nX, nY, nWidth, nHeight); oBrush:delete();
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.text
    @desc Draws text with the provider's current font and enabled-state color.
    !]]
    function oTheme.text(oDC, sText, nX, nY, bEnabled, bSelected)
        oDC:SetFont(oTheme.Font); oDC:SetBackgroundMode(_wx.wxTRANSPARENT);
        oDC:SetTextForeground(oTheme.color(bSelected and "SelectionText" or "Text", bEnabled));
        oDC:DrawText(sText, math.floor(nX), math.floor(nY));
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.materialColor
    @desc Resolves decorative palette roles without sampling image pixels in System.
        Chart series hues derive from the system accent; explicit data colors stay
        under application control. Returned colors are borrowed until refresh.
    !]]
    function oTheme.materialColor(sMaterial)
        if (sName == "Obsidian") then
            local oImage = oSkin.getBitmap(sMaterial):ConvertToImage();
            local sKey = "material:"..sMaterial;
            if (not tColors[sKey]) then tColors[sKey] = _wx.wxColour(oImage:GetRed(0, 0), oImage:GetGreen(0, 0), oImage:GetBlue(0, 0)); end
            oImage:delete(); return tColors[sKey];
        end
        local bEnabled = not sMaterial:find("Disabled", 1, true);
        if (sMaterial:find("Text Selected", 1, true)) then return oTheme.color("SelectionText", bEnabled); end
        local nSeries = tonumber(sMaterial:match("Series (%d+)"));
        if (nSeries and bEnabled) then
            local sKey = "series:"..nSeries;
            if (not tColors[sKey]) then
                local oAccent = oTheme.color("Fill");
                local tHSV = _Color.hsv({R = oAccent:Red(), G = oAccent:Green(), B = oAccent:Blue(), A = 255});
                tHSV.H = (tHSV.H + (nSeries - 1) * 45) % 360;
                local tRGB = _Color.fromHSV(tHSV);
                tColors[sKey] = _wx.wxColour(tRGB.R, tRGB.G, tRGB.B);
            end
            return tColors[sKey];
        end
        return oTheme.color(_System.describe(sMaterial), bEnabled);
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.getBitmap
    @desc Returns a borrowed bounded-cache material. System generates vectors in
        memory; two background passes derive alpha without reserving a palette
        color as transparent. Obsidian delegates to its image cache.
    !]]
    function oTheme.getBitmap(sMaterial, nWidth, nHeight, bVertical)
        assert(not bDisposed, "Theme is disposed.");
        if (sName == "Obsidian") then return oSkin.getBitmap(sMaterial, nWidth, nHeight, bVertical); end
        local _, nNaturalW, nNaturalH = _System.describe(sMaterial);
        nWidth, nHeight = math.max(1, math.floor(nWidth or nNaturalW)), math.max(1, math.floor(nHeight or nNaturalH));
        local sKey = sMaterial..":"..tostring(bVertical);
        local tEntry = tBitmaps[sKey];
        if (tEntry and tEntry.Width == nWidth and tEntry.Height == nHeight) then return tEntry.Bitmap; end
        if (tEntry) then tEntry.Bitmap:delete(); end
        local nW, nH = bVertical and nHeight or nWidth, bVertical and nWidth or nHeight;
        local tData, oImage = {}, nil;
        for nPass, oBackground in ipairs({_wx.wxBLACK_BRUSH, _wx.wxWHITE_BRUSH}) do
            local oBitmap = _wx.wxBitmap(nW, nH);
            local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap); oDC:SetBackground(oBackground); oDC:Clear();
            _System.draw(oTheme, nil, oDC, sMaterial, 0, 0, nW, nH, true);
            oDC:SelectObject(_wx.wxNullBitmap); oDC:delete();
            local oPassImage = oBitmap:ConvertToImage(); oBitmap:delete();
            tData[nPass] = oPassImage:GetData();
            if (nPass == 1) then oImage = oPassImage; else oPassImage:delete(); end
        end
        local tAlpha = {};
        for nByte = 1, #tData[1], 3 do
            tAlpha[#tAlpha + 1] = tData[1]:sub(nByte, nByte + 2) == tData[2]:sub(nByte, nByte + 2) and "\255" or "\0";
        end
        oImage:InitAlpha(); oImage:SetAlpha(table.concat(tAlpha));
        if (bVertical) then local oRotated = oImage:Rotate90(true); oImage:delete(); oImage = oRotated; end
        tEntry = {Width = nWidth, Height = nHeight, Bitmap = _wx.wxBitmap(oImage)}; oImage:delete();
        if (not tBitmaps[sKey]) then tBitmapOrder[#tBitmapOrder + 1] = sKey; end
        tBitmaps[sKey] = tEntry;
        if (#tBitmapOrder > 96) then
            local sOld = table.remove(tBitmapOrder, 1); tBitmaps[sOld].Bitmap:delete(); tBitmaps[sOld] = nil;
        end
        return tEntry.Bitmap;
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.drawFor
    @desc Draws a semantic part for a native host; the native renderer can use
        that host's platform theme. Unhosted custom materials use system vectors.
    !]]
    function oTheme.drawFor(oWindow, oDC, sPart, nX, nY, nWidth, nHeight, bVertical)
        if ((nWidth and nWidth < 1) or (nHeight and nHeight < 1)) then return; end
        if (sName == "Obsidian") then return oSkin.draw(oDC, sPart, nX, nY, nWidth, nHeight, bVertical); end
        local _, nNaturalW, nNaturalH = _System.describe(sPart);
        if (bVertical) then oDC:DrawBitmap(oTheme.getBitmap(sPart, nWidth, nHeight, true), math.floor(nX), math.floor(nY), true);
        else _System.draw(oTheme, oWindow, oDC, sPart, math.floor(nX), math.floor(nY), nWidth or nNaturalW, nHeight or nNaturalH); end
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.draw
    @desc Draws an unhosted part; drawOpaque retains the same alpha-aware contract.
    !]]
    function oTheme.draw(oDC, ...) return oTheme.drawFor(nil, oDC, ...); end
    oTheme.drawOpaque = oTheme.draw;

    --[[!
    @fqxn wxLuma.UI.ControlTheme.arrowGlyph
    @desc Draws a native arrow in any direction. wxLua exposes a downward native
        glyph; rotating its alpha-covered bitmap supplies the other directions.
        A live native host is mandatory for platform rendering. Cache ownership
        and eviction are shared with the context's other generated materials.
    !]]
    function oTheme.arrowGlyph(oWindow, oDC, sDirection, nX, nY, nWidth, nHeight, sState)
        if (sName ~= "System") then return false; end
        if (nWidth < 1 or nHeight < 1) then return true; end
        if (not oWindow) then
            for oComponent in pairs(tSubscribers) do
                if (not oComponent.Disposed and not oComponent.Control:IsBeingDeleted()) then oWindow = oComponent.Control; break; end
            end
        end
        assert(oWindow, "Native arrow rendering requires a live control host.");
        local nSize = math.max(1, math.floor(math.min(nWidth, nHeight, oWindow:FromDIP(12))));
        local nFlags = sState == "Disabled" and _wx.wxCONTROL_DISABLED or 0;
        local sKey = "native-arrow:"..sDirection..":"..nSize..":"..nFlags..":"..oWindow:FromDIP(100);
        local tEntry = tBitmaps[sKey];
        if (not tEntry) then
            local oImage, tData = nil, {};
            for nPass, oBackground in ipairs({_wx.wxBLACK_BRUSH, _wx.wxWHITE_BRUSH}) do
                local oBitmap = _wx.wxBitmap(nSize, nSize);
                local oMemory = _wx.wxMemoryDC(); oMemory:SelectObject(oBitmap);
                oMemory:SetBackground(oBackground); oMemory:Clear();
                oMemory:SetTextForeground(oTheme.color("Text", sState ~= "Disabled"));
                local oRect = _wx.wxRect(0, 0, nSize, nSize);
                _wx.wxRendererNative.Get():DrawDropArrow(oWindow, oMemory, oRect, nFlags); oRect:delete();
                oMemory:SelectObject(_wx.wxNullBitmap); oMemory:delete();
                local oPass = oBitmap:ConvertToImage(); oBitmap:delete(); tData[nPass] = oPass:GetData();
                if (nPass == 1) then oImage = oPass; else oPass:delete(); end
            end
            local tAlpha = {};
            for nByte = 1, #tData[1], 3 do
                tAlpha[#tAlpha + 1] = tData[1]:sub(nByte, nByte + 2) == tData[2]:sub(nByte, nByte + 2) and "\255" or "\0";
            end
            if (not oImage:HasAlpha()) then oImage:InitAlpha(); end
            oImage:SetAlpha(table.concat(tAlpha));
            local nTurns = ({Down = 0, Left = 1, Up = 2, Right = 3})[sDirection];
            assert(nTurns, "Arrow direction must be Up, Down, Left or Right.");
            for nTurn = 1, nTurns do local oRotated = oImage:Rotate90(true); oImage:delete(); oImage = oRotated; end
            tEntry = {Bitmap = _wx.wxBitmap(oImage)}; oImage:delete();
            tBitmaps[sKey] = tEntry; tBitmapOrder[#tBitmapOrder + 1] = sKey;
            if (#tBitmapOrder > 96) then
                local sOld = table.remove(tBitmapOrder, 1); tBitmaps[sOld].Bitmap:delete(); tBitmaps[sOld] = nil;
            end
        end
        oDC:DrawBitmap(tEntry.Bitmap, math.floor(nX + (nWidth - nSize) / 2), math.floor(nY + (nHeight - nSize) / 2), true);
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.arrowButton
    @desc Paints an arrow button using native button feedback and the shared
        native arrow glyph. Image skins retain their authored parts.
    !]]
    function oTheme.arrowButton(oComponent, oDC, sDirection, nX, nY, nWidth, nHeight, sState)
        if (sName ~= "System") then return false; end
        if (nWidth < 1 or nHeight < 1) then return true; end
        local nFlags = sState == "Disabled" and _wx.wxCONTROL_DISABLED or sState == "Pressed" and _wx.wxCONTROL_PRESSED
            or sState == "Hover" and _wx.wxCONTROL_CURRENT or 0;
        local oRect = _wx.wxRect(math.floor(nX), math.floor(nY), math.floor(nWidth), math.floor(nHeight));
        _wx.wxRendererNative.Get():DrawPushButton(oComponent.Control, oDC, oRect, nFlags); oRect:delete();
        oTheme.arrowGlyph(oComponent.Control, oDC, sDirection, nX + 2, nY + 2, nWidth - 4, nHeight - 4, sState);
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.dropdownButton
    @desc Draws the platform dropdown button using its native renderer and OS
        scrollbar-width metric. Open popups use the pressed state. Returns false
        for image skins so their existing arrow artwork remains in control.
    @ret boolean bDrawn Whether System handled the button.
    !]]
    function oTheme.dropdownButton(oComponent, oDC, nWidth, nHeight, sState)
        if (sName ~= "System") then return false; end
        if (nWidth < 1 or nHeight < 1) then return true; end
        local oWindow = oComponent.Control;
        local nButtonWidth = _wx.wxSystemSettings.GetMetric(_wx.wxSYS_VSCROLL_X, oWindow);
        if (nButtonWidth <= 0) then nButtonWidth = oWindow:FromDIP(17); end
        nButtonWidth = math.min(nWidth, nButtonWidth);
        local nFlags = sState == "Disabled" and _wx.wxCONTROL_DISABLED or sState == "Pressed" and _wx.wxCONTROL_PRESSED
            or sState == "Hover" and _wx.wxCONTROL_CURRENT or 0;
        if (sState ~= "Disabled" and oComponent.isOpen and oComponent.isOpen()) then nFlags = _wx.wxCONTROL_PRESSED; end
        local oRect = _wx.wxRect(math.floor(nWidth - nButtonWidth), 0, math.floor(nButtonWidth), math.floor(nHeight));
        _wx.wxRendererNative.Get():DrawComboBoxDropButton(oWindow, oDC, oRect, nFlags);
        oRect:delete();
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.focus
    @desc Compatibility hook. Keyboard focus does not paint an outline.
    !]]
    function oTheme.focus(oDC, nWidth, nHeight)
        -- Compatibility hook: focus does not decorate control bounds.
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.button
    @desc Paints an existing wxLuma button through native rendering or Obsidian artwork.
    !]]
    function oTheme.button(oComponent, oDC, nWidth, nHeight, sState)
        oTheme.fill(oDC, "Background", 0, 0, nWidth, nHeight);
        local bSelected = false;
        if (sName == "System") then
            local bToggled = oComponent.Kind == "ToggleButton" and oComponent.Value;
            local bBorderless = (oComponent.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_NONE;
            if (bBorderless) then
                -- Flat buttons communicate hover/press/selection with their
                -- fill, without adding an outline around the control or text.
                local sRole = sState == "Disabled" and (bToggled and "Hover" or "Background")
                    or (bToggled or sState == "Pressed") and "Selection" or sState == "Hover" and "Hover" or "Background";
                oTheme.fill(oDC, sRole, 0, 0, nWidth, nHeight);
                bSelected = sRole == "Selection";
            else
                local nFlags = ({Disabled = _wx.wxCONTROL_DISABLED, Hover = _wx.wxCONTROL_CURRENT,
                    Pressed = _wx.wxCONTROL_PRESSED, Normal = 0})[sState];
                if (bToggled and sState ~= "Disabled") then nFlags = _wx.wxCONTROL_PRESSED; end
                _wx.wxRendererNative.Get():DrawPushButton(oComponent.Control, oDC,
                    _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)), nFlags);
            end
        else
            oSkin.draw(oDC, "Button Left "..sState, 0, (nHeight - 36) / 2);
            oSkin.draw(oDC, "Button Middle "..sState, 12, (nHeight - 36) / 2, math.max(1, nWidth - 24), 36);
            oSkin.draw(oDC, "Button Right "..sState, nWidth - 12, (nHeight - 36) / 2);
        end
        oDC:SetFont(oTheme.Font);
        local nTextW, nTextH = oDC:GetTextExtent(oComponent.Text);
        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(2, 2, math.max(1, nWidth - 4), math.max(1, nHeight - 4)));
        oTheme.text(oDC, oComponent.Text, (nWidth - nTextW) / 2,
            (nHeight - nTextH) / 2 + (sState == "Pressed" and 1 or 0), oComponent.isEnabled(), bSelected);
        oClip:delete();
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.editor
    @desc Paints the native editor's surrounding surface using semantic colors.
    !]]
    function oTheme.editor(oComponent, oDC, nWidth, nHeight)
        if (sName == "Obsidian") then
            _Drawing.frame(oDC, 0, 0, nWidth, nHeight, oComponent.isEnabled(),
                oComponent.TextControl:HasFocus() or oComponent.Control:HasFocus());
            return;
        end
        oTheme.fill(oDC, "Editor", 0, 0, nWidth, nHeight, oComponent.isEnabled());
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.artwork
    @desc Adapts iris decoration to semantic system roles or the named image family.
        Helpers retain no private resources and remain valid after provider changes.
    !]]
    function oTheme.artwork(sPrefix)
        return {
            color = function(sPart)
                if (sName == "Obsidian") then return fArtwork(sPrefix).color(sPart); end
                return oTheme.materialColor(sPrefix.." "..sPart);
            end,
            part = function(oDC, sPart, nX, nY, nWidth, nHeight)
                if (sName == "Obsidian") then fArtwork(sPrefix).part(oDC, sPart, nX, nY, nWidth, nHeight);
                else oTheme.draw(oDC, sPrefix.." "..sPart, nX, nY, nWidth, nHeight); end
            end,
            text = function(oDC, sText, nX, nY, bEnabled)
                if (sName == "Obsidian") then fArtwork(sPrefix).text(oDC, sText, nX, nY, bEnabled);
                else oTheme.text(oDC, sText, nX, nY, bEnabled); end
            end,
            destroy = function() end,
        };
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.irisBrush
    @desc Returns an owned brush for an iris part. Geometry and masks stay in the
        iris control. System reservation uses hatching in addition to color.
    !]]
    function oTheme.irisBrush(sPart, sState, nSize, sAppearance, tRGB, sArtwork, bCustomColour)
        if (sName == "Obsidian" and sAppearance == "skin") then
            return _wx.wxBrush(oSkin.getBitmap(sArtwork.." "..sPart.." "..sState,
                sPart ~= "Background" and nSize or nil, sPart ~= "Background" and nSize or nil));
        end
        if (sName == "System") then
            -- An explicit fill color is application data, rather than decoration.
            if (sPart == "Fill" and bCustomColour and sState ~= "Disabled") then
                local oColor = _wx.wxColour(tRGB.R, tRGB.G, tRGB.B);
                local oBrush = _wx.wxBrush(oColor); oColor:delete(); return oBrush;
            end
            local oColor = oTheme.color(sPart, sState ~= "Disabled");
            return _wx.wxBrush(oColor, sPart == "Reserve" and _wx.wxBRUSHSTYLE_BDIAGONAL_HATCH or _wx.wxBRUSHSTYLE_SOLID);
        end
        local tChannels = ({Background = {24, 29, 36}, Track = {33, 42, 54},
            Fill = {tRGB.R, tRGB.G, tRGB.B}, Blade = {75, 91, 109},
            ["Blade Alternate"] = {58, 73, 92}, Reserve = {142, 99, 164}})[sPart];
        local nShade = sState == "Disabled" and 0.5 or 1;
        return _wx.wxBrush(_wx.wxColour(math.floor(tChannels[1] * nShade),
            math.floor(tChannels[2] * nShade), math.floor(tChannels[3] * nShade)));
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.setName
    @desc Prepares a provider before replacing the current one, updates every live
        subscriber, then releases old resources after widget caches are invalidated.
        Refreshing System also rereads current system colors and the GUI font.
    !]]
    function oTheme.setName(sNext)
        assert(not bDisposed and (sNext == "System" or sNext == "Obsidian"), "Theme must be System or Obsidian.");
        assert(sNext ~= "Obsidian" or type(pArtwork) == "string", "Obsidian requires an artwork directory.");
        local oNextSkin = sNext == "Obsidian" and _Skin.load(pArtwork) or nil;
        local oNextFont = not oNextSkin and _wx.wxSystemSettings.GetFont(_wx.wxSYS_DEFAULT_GUI_FONT) or nil;
        -- Keep old native resources alive while subscribers discard their brushes.
        local oOldSkin, oOldFont, tOldColors, tOldArtwork = oSkin, oFont, tColors, tArtwork;
        local tOldBitmaps = tBitmaps;
        tBitmaps, tBitmapOrder = {}, {};
        oSkin, oFont, tColors, tArtwork = oNextSkin, oNextFont, {}, {};
        sName, oTheme.Font = sNext, oNextSkin and oNextSkin.Font or oNextFont;
        oTheme.Revision = oTheme.Revision + 1;
        for oComponent, fChanged in pairs(tSubscribers) do
            if (not oComponent.Disposed) then fChanged(); end
        end
        for _, tArt in pairs(tOldArtwork) do tArt.destroy(); end
        for _, oColor in pairs(tOldColors) do oColor:delete(); end
        for _, tEntry in pairs(tOldBitmaps) do tEntry.Bitmap:delete(); end
        if (oOldSkin) then oOldSkin.destroy(); end
        if (oOldFont) then oOldFont:delete(); end
        return oTheme;
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.attach
    @desc Registers a control's cache/layout update and releases the subscription on
        disposal. A system-color event refreshes this context's system resources.
    !]]
    function oTheme.attach(oComponent, fChanged)
        fChanged = fChanged or function() ControlTheme.sync(oComponent, oTheme); end;
        assert(not bDisposed and type(fChanged) == "function", "Invalid theme subscription.");
        tSubscribers[oComponent] = fChanged;
        oComponent.Theme = oTheme;
        local nID = oComponent.Control:GetId();
        _tWindows[nID] = oTheme;
        if (not tAttached[oComponent]) then
            tAttached[oComponent] = true;
            oComponent.on("destroyed", function()
                tSubscribers[oComponent] = nil;
                if (_tWindows[nID] == oTheme) then _tWindows[nID] = nil; end
            end);
            oComponent.Control:Connect(_wx.wxEVT_SYS_COLOUR_CHANGED, function(oEvent)
                if (not bDisposed and not oComponent.Disposed and sName == "System") then oTheme.setName("System"); end
                oEvent:Skip();
            end);
        end
        fChanged();
    end

    --[[!
    @fqxn wxLuma.UI.ControlTheme.destroy
    @desc Releases a context after its controls; rejects premature resource disposal.
    !]]
    function oTheme.destroy()
        if (bDisposed) then return; end
        for oComponent in pairs(tSubscribers) do assert(oComponent.Disposed, "Destroy themed controls before their theme."); end
        bDisposed = true; fRelease(); oTheme.Disposed = true;
    end

    oTheme.setName(sInitial == nil and "System" or sInitial);
    return oTheme;
end

--[[!
@fqxn wxLuma.UI.ControlTheme.options
@desc Copies constructor options for migrated controls. Explicit legacy Skin keeps
    its original contract; otherwise Theme or the shared System fallback is used.
@ret table tOptions Copied options followed by the resolved theme, if applicable.
!]]
function ControlTheme.options(tSource, oParent)
    tSource = tSource or {};
    if (tSource.Skin and not _tThemes[tSource.Skin] and not tSource.Theme) then return tSource, nil; end
    assert(not (tSource.Skin and tSource.Theme and tSource.Skin ~= tSource.Theme), "Specify Theme or legacy Skin, not both.");
    local oTheme = tSource.Theme or (_tThemes[tSource.Skin] and tSource.Skin);
    local oCurrent = type(oParent) == "table" and oParent.Control or oParent;
    while (not oTheme and oCurrent and oCurrent.GetId) do
        oTheme = _tWindows[oCurrent:GetId()];
        if (oCurrent:IsTopLevel()) then break; end
        oCurrent = oCurrent:GetParent();
    end
    if (not oTheme) then
        if (not _oDefault or _oDefault.Disposed) then _oDefault = ControlTheme.create(); end
        oTheme = _oDefault;
    end
    assert(type(oTheme) == "table" and not oTheme.Disposed and type(oTheme.attach) == "function", "Invalid Theme.");
    local tCopy = {};
    for sKey, vValue in pairs(tSource) do tCopy[sKey] = vValue; end
    tCopy.Skin = oTheme;
    tCopy.Theme = oTheme;
    return tCopy, oTheme;
end

--[[!
@fqxn wxLuma.UI.ControlTheme.sync
@desc Updates owned native descendants without changing values, enabled state or
    text selection. Different appearance contexts remain independent. The widget
    hook invalidates private rasters and measurements before repainting.
!]]
function ControlTheme.sync(oComponent, oTheme)
    if (oComponent.Disposed) then return; end
    local tPending = {oComponent.Control};
    local tSelections = {};
    local nNext = 1;
    while (nNext <= #tPending) do
        local oWindow = tPending[nNext]; nNext = nNext + 1;
        local oOwner = _tWindows[oWindow:GetId()];
        if (not oOwner or oOwner == oTheme) then
            local oText = cast(oWindow, "wxTextCtrl");
            local bEditor = oText or cast(oWindow, "wxTreeCtrl") or cast(oWindow, "wxListCtrl");
            local nStart, nEnd;
            if (oText) then
                nStart, nEnd = oText:GetSelection();
                tSelections[#tSelections + 1] = {Control = oText, Start = nStart, Finish = nEnd};
            end
            oWindow:SetFont(oTheme.Font);
            local tBackground = _tBackgroundRoles[oWindow:GetId()];
            local sBackground = tBackground and tBackground.Theme == oTheme and tBackground.Role
                or (bEditor and "Editor" or "Background");
            oWindow:SetBackgroundColour(oTheme.color(sBackground));
            oWindow:SetForegroundColour(oTheme.color("Text", oComponent.isEnabled()));
            local oNode = oWindow:GetChildren():GetFirst();
            while (oNode) do
                local oChild = oNode:GetData():DynamicCast("wxWindow");
                if (oChild) then tPending[#tPending + 1] = oChild; end
                oNode = oNode:GetNext();
            end
            oWindow:Refresh(false);
        end
    end
    if (oComponent.onThemeChanged) then oComponent.onThemeChanged();
    elseif (oComponent.onLayout) then oComponent.onLayout(oComponent.Control:GetClientSizeWH()); end
    for _, tSelection in ipairs(tSelections) do
        tSelection.Control:SetSelection(tSelection.Start, tSelection.Finish);
    end
    if (oComponent.refresh) then oComponent.refresh(); end
end

--[[!
@fqxn wxLuma.UI.ControlTheme.finish
@desc Attaches a completed factory to its context, preserving legacy Skin objects.
!]]
function ControlTheme.finish(oComponent, tOptions)
    local oTheme = tOptions and tOptions.Skin;
    if (_tThemes[oTheme]) then oTheme.attach(oComponent); end
    return oComponent;
end

--[[!
@fqxn wxLuma.UI.ControlTheme.colour
@desc Returns an owned system-role color or the original legacy RGB fallback.
!]]
function ControlTheme.colour(oSkin, sRole, ...)
    if (_tThemes[oSkin] and oSkin.getName() == "System") then return _wx.wxColour(oSkin.color(sRole)); end
    return _wx.wxColour(...);
end

--[[!
@fqxn wxLuma.UI.ControlTheme.isTheme
@desc Identifies managed contexts without mistaking application-supplied skins.
!]]
function ControlTheme.isTheme(oSkin) return _tThemes[oSkin] == true; end

return ControlTheme;
