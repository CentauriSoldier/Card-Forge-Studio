local _wx      = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events  = require("wxLuma.Core.ControlEvents");
local _Color   = require("wxLuma.Core.ControlColor");
local LED = {};

--[[!
@fqxn wxLuma.UI.LED.create
@desc Creates a display indicator with independently skinnable Bezel, Lens,
    Glow and Glass layers. Value defaults false, Glow true, Glass false,
    Brightness 1, Size 48 pixels, Color {R=80,G=220,B=140}. Brightness scales
    emitted light; off retains a dim lens. Disabled dims the complete light.
    Pointer events remain available for audio; clicking never changes Value.
    GlowRadius is an optional pixel radius from the center; nil automatically
    uses 0.75 of the rendered Size. Zero suppresses the halo without toggling Glow.
!]]
function LED.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "LED requires Skin.");
    local tValues = {Value = false, Glow = true, Glass = false, Brightness = 1, Size = 48,
        Color = {R = 80, G = 220, B = 140, A = 255}};
    local sArtwork = tOptions.Artwork or "LED";
    local tCache = {};
    local tSources = {};

    --[[!
    @fqxn wxLuma.UI.LED.create.validate
    @desc Validates each setting before construction or mutation; color is copied.
    !]]
    local function fValidate(sName, vValue)
        if (sName == "Color") then return _Color.rgba(vValue); end
        if (sName == "GlowRadius" and vValue == nil) then return nil; end
        if (sName == "Brightness" or sName == "Size" or sName == "GlowRadius") then
            assert(type(vValue) == "number" and vValue == vValue and vValue < math.huge,
                sName.." must be finite.");
            assert(sName == "Brightness" and vValue >= 0 and vValue <= 1
                or sName == "Size" and vValue >= 1 and vValue <= 512 and vValue % 1 == 0
                or sName == "GlowRadius" and vValue >= 0 and vValue <= 512,
                "Invalid LED "..sName..".");
        else
            assert(type(vValue) == "boolean", sName.." must be boolean.");
        end
        return vValue;
    end
    for sName in pairs(tValues) do
        if (tOptions[sName] ~= nil) then tValues[sName] = fValidate(sName, tOptions[sName]); end
    end
    local nGlowRadius = fValidate("GlowRadius", tOptions.GlowRadius);
    local oComponent = _Surface.create(oParent, tOptions, "LED");
    local tEvents = _Events.attach(oComponent, nil, {"settingChanged"});

    --[[!
    @fqxn wxLuma.UI.LED.create.clear
    @desc Releases owned tinted bitmaps, optionally for just one layer. Shared
        skin images and prepared neutral masks remain available for reuse.
    !]]
    local function fClear(sPart)
        for sKey, oBitmap in pairs(tCache) do
            if (not sPart or sKey:sub(1, #sPart + 1) == sPart..":") then
                oBitmap:delete();
                tCache[sKey] = nil;
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.LED.getGlowRadius
    @desc Returns the explicit pixel radius from the LED center, or nil for
        automatic radius (0.75 of the rendered bezel/lens artwork diameter).
    !]]
    function oComponent.getGlowRadius() return nGlowRadius; end

    --[[!
    @fqxn wxLuma.UI.LED.setGlowRadius
    @desc Sets a finite radius from 0 through 512 pixels, including fractions.
        Nil restores automatic sizing. The halo fits within control bounds;
        radius changes never shrink the lens and invalidate only glow bitmaps.
        Optional notification emits settingChanged after an effective change.
    !]]
    function oComponent.setGlowRadius(nRadius, bNotify)
        assert(not oComponent.Disposed, "LED is disposed.");
        nRadius = fValidate("GlowRadius", nRadius);
        if (nGlowRadius ~= nRadius) then
            local nOld = nGlowRadius;
            nGlowRadius = nRadius;
            fClear("Glow");
            oComponent.refresh();
            if (bNotify) then
                tEvents.emit("settingChanged", {Property = "GlowRadius", Value = nRadius, OldValue = nOld});
            end
        end
        return oComponent;
    end

    -- The same validation, cache ownership and notification policy applies to
    -- every public setting. Returned colors never expose the stored table.
    for _, sProperty in ipairs({"Value", "Glow", "Glass", "Brightness", "Size", "Color"}) do
        local sName = sProperty;
        --[[!
        @fqxn wxLuma.UI.LED.getSetting
        @desc getValue/getGlow/getGlass/getBrightness/getSize/getColor return the
            current setting. getColor returns an independent RGBA table.
        !]]
        oComponent["get"..sName] = function()
            return sName == "Color" and _Color.rgba(tValues.Color) or tValues[sName];
        end;
        --[[!
        @fqxn wxLuma.UI.LED.setSetting
        @desc Matching setters validate first and invalidate cached light only
            after a change. Optional notify emits settingChanged; Value also
            calls OnChange. All setters return this component.
        !]]
        oComponent["set"..sName] = function(vValue, bNotify)
            assert(not oComponent.Disposed, "LED is disposed.");
            vValue = fValidate(sName, vValue);
            local vOld = tValues[sName];
            local bChanged = vValue ~= vOld;
            if (sName == "Color") then
                bChanged = vValue.R ~= vOld.R or vValue.G ~= vOld.G
                    or vValue.B ~= vOld.B or vValue.A ~= vOld.A;
            end
            if (bChanged) then
                tValues[sName] = vValue;
                -- Cover/halo visibility only changes composition. Size changes
                -- replace scaled masks on demand; neither needs source retinting.
                if (sName ~= "Glass" and sName ~= "Glow") then fClear(); end
                oComponent.refresh();
                if (bNotify) then
                    tEvents.emit(sName == "Value" and "valueChanged" or "settingChanged",
                        {Property = sName, Value = oComponent["get"..sName](), OldValue = vOld});
                    if (sName == "Value" and oComponent.OnChange) then
                        oComponent.OnChange(vValue, oComponent);
                    end
                end
            end
            return oComponent;
        end;
    end

    --[[!
    @fqxn wxLuma.UI.LED.create.light
    @desc Filters each neutral skin to its rendered diameter once, retaining its
        shade/alpha byte strings. Native bulk setters and byte lookup tables tint
        whole images without per-pixel binding calls. Brightness/color changes
        reuse filtered masks; ordinary paints reuse the finished native bitmap.
    !]]
    local function fLight(oDC, sPart, nX, nY, nSize, bEnabled)
        local sKey = sPart..":"..nSize..":"..tostring(bEnabled);
        if (not tCache[sKey]) then
            local tSource = tSources[sPart];
            if (not tSource) then
                tSource = {Image = oComponent.Skin.getBitmap(sArtwork.." "..sPart):ConvertToImage()};
                tSources[sPart] = tSource;
            end
            if (tSource.Size ~= nSize) then
                if (tSource.Scaled) then tSource.Scaled:delete(); end
                tSource.Scaled = tSource.Image:Scale(nSize, nSize, _wx.wxIMAGE_QUALITY_HIGH);
                tSource.Size = nSize;
                -- Neutral skin shading is defined by its red channel, as before.
                -- String substitution runs in Lua's native string implementation.
                tSource.Shades = tSource.Scaled:GetData():gsub("(.)..", "%1");
                tSource.Alpha = tSource.Scaled:HasAlpha() and tSource.Scaled:GetAlpha()
                    or string.rep(string.char(255), nSize * nSize);
            end
            local oImage = tSource.Scaled:Copy();
            local tColor = tValues.Color;
            local nLight = tValues.Value and tValues.Brightness or 0.08;
            if (not bEnabled) then nLight = nLight * 0.35; end
            local tRGB, tAlpha = {}, {};
            local nOpacity = tColor.A / 255 * (sPart == "Glow" and nLight or 1);
            for nByte = 0, 255 do
                local sByte = string.char(nByte);
                local nShade = nByte / 255 * nLight;
                tRGB[sByte] = string.char(math.floor(tColor.R * nShade),
                    math.floor(tColor.G * nShade), math.floor(tColor.B * nShade));
                tAlpha[sByte] = string.char(math.floor(nByte * nOpacity));
            end
            local sRGB = tSource.Shades:gsub(".", tRGB);
            local sAlpha = tSource.Alpha:gsub(".", tAlpha);
            oImage:SetData(sRGB);
            if (not oImage:HasAlpha()) then oImage:InitAlpha(); end
            oImage:SetAlpha(sAlpha);
            tCache[sKey] = _wx.wxBitmap(oImage);
            oImage:delete();
        end
        oDC:DrawBitmap(tCache[sKey], nX, nY, true);
    end

    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        -- Glow occupies an outer margin; Size describes the lens and bezel.
        local nSize = math.max(1, math.min(tValues.Size, math.floor(math.min(nWidth, nHeight) / 1.5)));
        local nOuter = nGlowRadius == nil and math.floor(nSize * 1.5)
            or math.min(math.min(nWidth, nHeight), math.floor(nGlowRadius * 2));
        local nX, nY = math.floor((nWidth - nSize) / 2), math.floor((nHeight - nSize) / 2);
        local bEnabled = oComponent.isEnabled();
        if (tOptions.Background) then
            tOptions.Background(oDC, oComponent);
        else
            oComponent.Skin.drawOpaque(oDC, sArtwork..(bEnabled and " Surface Normal" or " Surface Disabled"),
                0, 0, nWidth, nHeight);
        end
        -- Keep just one diameter's images so resize does not grow the cache.
        if (oComponent.RenderedSize ~= nSize) then fClear(); oComponent.RenderedSize = nSize; end
        if (tValues.Value and tValues.Glow and tValues.Brightness > 0 and nOuter > 0) then
            fLight(oDC, "Glow", math.floor((nWidth - nOuter) / 2), math.floor((nHeight - nOuter) / 2), nOuter, bEnabled);
        end
        oComponent.Skin.draw(oDC, sArtwork.." Bezel", nX, nY, nSize, nSize);
        fLight(oDC, "Lens", nX, nY, nSize, bEnabled);
        if (tValues.Glass) then oComponent.Skin.draw(oDC, sArtwork.." Glass", nX, nY, nSize, nSize); end
    end;
    oComponent.onDestroy = function()
        fClear();
        for _, tSource in pairs(tSources) do
            if (tSource.Scaled) then tSource.Scaled:delete(); end
            tSource.Image:delete();
        end
        tSources = {};
    end;
    return oComponent;
end

return LED;
