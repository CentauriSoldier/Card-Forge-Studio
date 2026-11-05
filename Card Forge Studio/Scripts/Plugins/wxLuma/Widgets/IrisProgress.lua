local _wx       = require("wx");
local _Surface  = require("wxLuma.Core.ControlSurface");
local _Events   = require("wxLuma.Core.ControlEvents");
local _Reserve  = require("wxLuma.Core.ControlProgressReserve");
local _Artwork  = require("wxLuma.Core.ControlArtwork");
local _finite   = require("wxLuma.Core.ControlNumeric").finite;
local IrisProgress = {};

--[[!
@fqxn wxLuma.UI.IrisProgress.loadImage
@desc Decodes an owned replacement before any live state changes. Nil clears it.
@param string|nil pPath Image path supported by the installed wx image handlers.
@ret wxImage|nil oImage Owned decoded image.
!]]
local function loadImage(pPath)
    assert(pPath == nil or type(pPath) == "string", "BackgroundImage must be a path or nil.");

    if (pPath == nil) then
        return nil;
    end

    local hFile = io.open(pPath, "rb");
    assert(hFile, "Cannot open iris background image: "..pPath);
    hFile:close();
    local oImage = _wx.wxImage(pPath, _wx.wxBITMAP_TYPE_ANY);

    if (not oImage:IsOk()) then
        oImage:delete();
        error("Cannot decode iris background image: "..pPath);
    end

    return oImage;
end

--[[!
@fqxn wxLuma.UI.IrisProgress.create
@desc Creates a camera-iris progress globe with layered blades and a polygonal
    opening. Opening grows with value by default; closing grows blade coverage.
    Maximum opening uncovers the entire disc. All boundaries are antialiased.
@param wxWindow oParent Native parent, which owns the control.
@param table tOptions Skin, Min, Max, Value; optional BladeCount (3..32, default 6),
    Rotation (clock-face degrees, default 0), Direction (opening/closing), Text,
    Appearance (skin/colour), Colour ({R,G,B}), Artwork (Iris Progress), Reserved,
    ReserveDirection (inward/outward), BackgroundImage (optional path),
    BackgroundImageFit (cover/contain/stretch, default cover), Supersampling (2/4,
    default 4), Enabled, OnChange
    and standard containment. Background image is always clipped by globe/blades.
@ret table oComponent Independent IrisProgress proxy with standard progress events.
!]]
function IrisProgress.create(oParent, tOptions)
    assert(type(tOptions) == "table" and _finite(tOptions.Min) and _finite(tOptions.Max)
        and tOptions.Max > tOptions.Min and _finite(tOptions.Max - tOptions.Min), "Invalid iris range.");
    assert(_finite(tOptions.Value), "Iris value must be finite.");
    _Reserve.validate(tOptions, "IrisProgress");
    local tSettings = {
        BladeCount = tOptions.BladeCount or 6,
        Rotation = tOptions.Rotation or 0,
        Direction = tOptions.Direction or "opening",
        Appearance = tOptions.Appearance or (tOptions.Colour and "colour" or "skin"),
        BackgroundImageFit = tOptions.BackgroundImageFit or "cover",
        Supersampling = tOptions.Supersampling or 4
    };
    local tValidators = {
        BladeCount = function(nValue)
            return _finite(nValue) and nValue % 1 == 0 and nValue >= 3 and nValue <= 32;
        end,
        Rotation = _finite,
        Supersampling = function(nValue)
            return nValue == 2 or nValue == 4;
        end,
        Direction = function(sValue)
            return sValue == "opening" or sValue == "closing";
        end,
        Appearance = function(sValue)
            return sValue == "skin" or sValue == "colour";
        end,
        BackgroundImageFit = function(sValue)
            return sValue == "cover" or sValue == "contain" or sValue == "stretch";
        end
    };

    for sName, fValidate in pairs(tValidators) do
        assert(fValidate(tSettings[sName]), "Invalid iris "..sName..".");
    end

    tSettings.Rotation = tSettings.Rotation % 360;
    local sText = tOptions.Text or "%v / %m";
    local sArtwork = tOptions.Artwork or "Iris Progress";
    local tColour = tOptions.Colour or {R = 80, G = 145, B = 190};
    assert(type(sText) == "string" and type(sArtwork) == "string" and sArtwork:find("%S"), "Invalid iris text/artwork.");
    local tRGB = {};

    for _, sChannel in ipairs({"R", "G", "B"}) do
        assert(type(tColour) == "table" and _finite(tColour[sChannel])
            and tColour[sChannel] >= 0 and tColour[sChannel] <= 255, "Invalid iris colour.");
        tRGB[sChannel] = tColour[sChannel];
    end

    assert(tOptions.Skin, "IrisProgress requires a Skin.");
    local oImage = loadImage(tOptions.BackgroundImage);
    local pImage = tOptions.BackgroundImage;
    local oComponent = _Surface.create(oParent, tOptions, "IrisProgress");
    local tExtraEvents = {"bladeCountChanged", "rotationChanged", "directionChanged", "appearanceChanged",
        "backgroundImageChanged", "backgroundImageFitChanged", "supersamplingChanged"};

    for _, sName in ipairs(_Reserve.Events) do
        tExtraEvents[#tExtraEvents + 1] = sName;
    end

    local tEvents = _Events.attach(oComponent, nil, tExtraEvents);
    oComponent.Min   = tOptions.Min;
    oComponent.Max   = tOptions.Max;
    oComponent.Value = math.max(tOptions.Min, math.min(tOptions.Max, tOptions.Value));
    local tReserve = _Reserve.attach(oComponent, tOptions, tEvents, "IrisProgress");
    local tArt = _Artwork.create(oComponent.Skin, sArtwork);
    local tMaterials = {};
    local sMaterialKey;

    --[[!
    @fqxn wxLuma.UI.IrisProgress.clearMaterials
    @desc Releases owned brushes and pens on appearance/size changes and disposal.
        Value updates reuse brushes. Borrowed skin bitmaps remain skin-owned.
    !]]
    local function fClearMaterials()
        for _, oBrush in pairs(tMaterials) do
            oBrush:delete();
        end

        tMaterials = {};
        sMaterialKey = nil;
    end

    local tBuffers = {};
    local nBufferSize;

    --[[!
    @fqxn wxLuma.UI.IrisProgress.clearBuffers
    @desc Releases reusable, deselected work bitmaps on size changes and disposal.
        Each role owns one bitmap, so dragging never grows the buffer collection.
    !]]
    local function fClearBuffers()
        for _, oBitmap in pairs(tBuffers) do
            oBitmap:delete();
        end

        tBuffers = {};
        nBufferSize = nil;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.buffer
    @desc Returns an owned work bitmap for a raster role. Callers deselect it
        from their temporary DC before another operation or eventual disposal.
    !]]
    local function fBuffer(sRole, nSize, nDepth)
        if (nBufferSize ~= nSize) then
            fClearBuffers();
            nBufferSize = nSize;
        end

        if (not tBuffers[sRole]) then
            tBuffers[sRole] = _wx.wxBitmap(nSize, nSize, nDepth or -1);
        end

        return tBuffers[sRole];
    end

    local oRaster;
    local sRasterKey;
    local oPictureBitmap;
    local sPictureKey;

    --[[!
    @fqxn wxLuma.UI.IrisProgress.clearPicture
    @desc Drops the owned fitted image when its source changes or on disposal.
        Value, blade and reserve changes reuse it unchanged.
    !]]
    local function fClearPicture()
        if (oPictureBitmap) then
            oPictureBitmap:delete();
            oPictureBitmap = nil;
        end

        sPictureKey = nil;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.geometryAccessors
    @desc Installs get/setBladeCount, Rotation, Direction, Appearance and
        BackgroundImageFit and Supersampling (2 or 4). Setters validate before mutation, are silent by
        default, and notify only effective changes with old/new property values.
        Angles normalize modulo 360. Settings preserve value and native layout.
    !]]
    local function fAccessors(sName, fValidate)
        local sEvent = sName:sub(1, 1):lower()..sName:sub(2).."Changed";
        oComponent["get"..sName] = function()
            return tSettings[sName];
        end;
        oComponent["set"..sName] = function(vValue, bNotify)
            assert(fValidate(vValue), "Invalid iris "..sName..".");

            if (sName == "Rotation") then
                vValue = vValue % 360;
            end

            if (not oComponent.Disposed and tSettings[sName] ~= vValue) then
                local vOld = tSettings[sName];
                tSettings[sName] = vValue;
                oComponent.refresh();

                if (bNotify) then
                    tEvents.emit(sEvent, {[sName] = vValue, ["Old"..sName] = vOld});
                end
            end

            return oComponent;
        end;
    end

    for sName, fValidate in pairs(tValidators) do
        fAccessors(sName, fValidate);
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.setValue
    @desc Clamps finite values to Min and the reserve-adjusted effective maximum.
        Unchanged effective values are silent, including requests above capacity.
    @param number nValue Requested progress value.
    @param boolean|nil bNotify Emit OnChange(value, component) and valueChanged.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(_finite(nValue), "Iris value must be finite.");
        nValue = math.max(oComponent.Min, math.min(oComponent.getEffectiveMax(), nValue));

        if (not oComponent.Disposed and oComponent.Value ~= nValue) then
            local nOld = oComponent.Value;
            oComponent.Value = nValue;
            oComponent.refresh();

            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(nValue, oComponent);
                end

                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOld});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.getBackgroundImage
    @desc Returns the source path, or nil when no image is configured.
    @ret string|nil pPath Current background image path.
    !]]
    function oComponent.getBackgroundImage()
        return pImage;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.setBackgroundImage
    @desc Loads a replacement atomically. Nil clears it; failed loads preserve
        the image and raster. The picture never paints outside the globe or over
        blades. Reusing the current path is a no-op.
    @param string|nil pPath Image path or nil.
    @param boolean|nil bNotify Emit backgroundImageChanged and imageLoaded on load.
    @ret table oComponent This component.
    !]]
    function oComponent.setBackgroundImage(pPath, bNotify)
        if (oComponent.Disposed or pPath == pImage) then
            return oComponent;
        end

        local oReplacement = loadImage(pPath);
        local pOld = pImage;
        fClearPicture();

        if (oImage) then
            oImage:delete();
        end

        oImage, pImage = oReplacement, pPath;
        sRasterKey = nil;
        oComponent.refresh();

        if (bNotify) then
            tEvents.emit("backgroundImageChanged", {BackgroundImage = pPath, OldBackgroundImage = pOld});

            if (oImage) then
                tEvents.emit("imageLoaded", {Path = pPath, Width = oImage:GetWidth(), Height = oImage:GetHeight()});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.raster
    @desc Builds one supersampled globe at the selected quality. Layered blade polygons form
        the aperture; native bitmap masks clip both picture and reserve to
        the circle and opening. Monochrome work masks avoid colour-to-mask
        conversion on every update. Cached results are reused until visual state changes.
    !]]
    local function fRaster(nDiameter)
        local bEnabled = oComponent.isEnabled();
        local sState = bEnabled and "Normal" or "Disabled";
        local sKey = table.concat({nDiameter, oComponent.Value, tReserve.Reserved,
            tReserve.ReserveDirection or "auto", tSettings.BladeCount, tSettings.Rotation,
            tSettings.Direction, tSettings.Appearance, tSettings.BackgroundImageFit, tSettings.Supersampling, sState}, ":");

        if (sKey == sRasterKey) then
            return;
        end

        local nScale  = tSettings.Supersampling;
        local nSize   = nDiameter * nScale;
        local nCenter = math.floor(nDiameter / 2) * nScale;
        local nRadius = (math.floor(nDiameter / 2) - 2) * nScale;
        local nBlades = tSettings.BladeCount;
        local nStep = 2 * math.pi / nBlades;
        local nRotation = math.rad(tSettings.Rotation - 90);
        local nReserved = tReserve.Reserved / (oComponent.Max - oComponent.Min);
        local nCurrent = math.max(0, math.min(1 - nReserved,
            (oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min)));
        local bOpening = tSettings.Direction == "opening";
        local sReserveDirection = tReserve.ReserveDirection or (bOpening and "inward" or "outward");
        local bSame = bOpening == (sReserveDirection == "outward");
        local nThreshold = (bSame and nReserved or 0) + nCurrent;
        local nOpen = bOpening and nThreshold or 1 - nThreshold;
        local sNewMaterialKey = table.concat({nSize, sState, tSettings.Appearance}, ":");

        if (sMaterialKey ~= sNewMaterialKey) then
            fClearMaterials();
        end

        local tBrushes = tMaterials;
        local tPalette = {
            Background = {24, 29, 36}, Track = {33, 42, 54},
            Fill = {tRGB.R, tRGB.G, tRGB.B}, Blade = {75, 91, 109},
            ["Blade Alternate"] = {58, 73, 92}, Reserve = {142, 99, 164}
        };

        for sPart, tChannels in pairs(tPalette) do
            if (not tBrushes[sPart] and tSettings.Appearance == "skin") then
                local oMaterial = sPart == "Background"
                    and oComponent.Skin.getBitmap(sArtwork.." "..sPart.." "..sState)
                    or oComponent.Skin.getBitmap(sArtwork.." "..sPart.." "..sState, nSize, nSize);
                tBrushes[sPart] = _wx.wxBrush(oMaterial);
            elseif (not tBrushes[sPart]) then
                local nShade = bEnabled and 1 or 0.5;
                tBrushes[sPart] = _wx.wxBrush(_wx.wxColour(math.floor(tChannels[1] * nShade),
                    math.floor(tChannels[2] * nShade), math.floor(tChannels[3] * nShade)));
            end
        end

        sMaterialKey = sNewMaterialKey;

        local oBitmap = fBuffer("disc", nSize);
        local oDC = _wx.wxMemoryDC();
        oDC:SelectObject(oBitmap);
        oDC:SetBackground(tBrushes.Background);
        oDC:Clear();
        oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        oDC:SetBrush(tBrushes.Track);
        oDC:DrawCircle(nCenter, nCenter, nRadius);
        local sNewPictureKey = table.concat({nSize, tSettings.BackgroundImageFit, sState, tSettings.Appearance}, ":");

        if (oImage and sPictureKey ~= sNewPictureKey) then
            fClearPicture();
            -- Composite alpha and fit into a stationary square before clipping.
            local nWidth, nHeight = oImage:GetWidth(), oImage:GetHeight();
            local nScale = tSettings.BackgroundImageFit == "contain" and nSize / math.max(nWidth, nHeight)
                or nSize / math.min(nWidth, nHeight);
            local nDrawWidth = tSettings.BackgroundImageFit == "stretch" and nSize or math.max(1, math.floor(nWidth * nScale));
            local nDrawHeight = tSettings.BackgroundImageFit == "stretch" and nSize or math.max(1, math.floor(nHeight * nScale));
            local oScaled = oImage:Scale(nDrawWidth, nDrawHeight, _wx.wxIMAGE_QUALITY_HIGH);
            local oScaledBitmap = _wx.wxBitmap(oScaled);
            oPictureBitmap = _wx.wxBitmap(nSize, nSize);
            local oPictureDC = _wx.wxMemoryDC();
            oPictureDC:SelectObject(oPictureBitmap);
            oPictureDC:SetBackground(tBrushes.Track);
            oPictureDC:Clear();
            oPictureDC:DrawBitmap(oScaledBitmap, math.floor((nSize - nDrawWidth) / 2),
                math.floor((nSize - nDrawHeight) / 2), true);
            oPictureDC:SelectObject(_wx.wxNullBitmap);
            oPictureDC:delete();
            oScaledBitmap:delete();
            oScaled:delete();
            sPictureKey = sNewPictureKey;
        end

        tMaterials.Seam = tMaterials.Seam or _wx.wxPen(tArt.color("Seam "..sState),
            math.max(1, math.floor(0.75 * nScale)), _wx.wxPENSTYLE_SOLID);
        local oSeam = tMaterials.Seam;
        oDC:SetPen(oSeam);
        local nVertexRadius = nOpen * nRadius / math.cos(nStep / 2);
        local nTwist = (1 - nOpen) * nStep * 0.7;

        -- Each leaf shares the aperture edge and overlaps its neighbor toward
        -- the outer rim. Alternating materials and seams make the overlap clear.
        for nBlade = 0, nBlades - 1 do
            local nAngle = nRotation + (nBlade - 0.5) * nStep;
            local tPoints = {};

            for _, nInnerAngle in ipairs({nAngle, nAngle + nStep}) do
                tPoints[#tPoints + 1] = _wx.wxPoint(math.floor(nCenter + math.cos(nInnerAngle) * nVertexRadius),
                    math.floor(nCenter + math.sin(nInnerAngle) * nVertexRadius));
            end

            for nIndex = 12, 0, -1 do
                local nOuterAngle = nAngle + nTwist + nStep * nIndex / 12;
                tPoints[#tPoints + 1] = _wx.wxPoint(math.floor(nCenter + math.cos(nOuterAngle) * (nRadius + 2 * nScale)),
                    math.floor(nCenter + math.sin(nOuterAngle) * (nRadius + 2 * nScale)));
            end

            oDC:SetBrush(bOpening and tBrushes[nBlade % 2 == 0 and "Blade" or "Blade Alternate"] or tBrushes.Fill);
            oDC:DrawPolygon(tPoints);

            for _, oPoint in ipairs(tPoints) do
                oPoint:delete();
            end
        end

        oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        tMaterials.Black = tMaterials.Black or _wx.wxBrush(_wx.wxColour(0, 0, 0));
        local oBlack = tMaterials.Black;
        tMaterials.White = tMaterials.White or _wx.wxBrush(_wx.wxColour(255, 255, 255));
        local oWhite = tMaterials.White;

        --[[!
        @fqxn wxLuma.UI.IrisProgress.raster.maskBitmap
        @desc Transfers an owned native monochrome mask to a bitmap. Native
            polygon/circle rasterization replaces Lua scanline loops while keeping
            the supersampled boundaries. The bitmap owns its mask.
        !]]
        local function fMaskBitmap(oTarget, nBoundary, bInvert, bCircle)
            local oMaskBitmap = fBuffer("mask", nSize, 1);
            local oMaskDC = _wx.wxMemoryDC();
            oMaskDC:SelectObject(oMaskBitmap);
            oMaskDC:SetBackground(bInvert and oWhite or oBlack);
            oMaskDC:Clear();
            oMaskDC:SetPen(_wx.wxTRANSPARENT_PEN);
            oMaskDC:SetBrush(bInvert and oBlack or oWhite);

            if (bCircle) then
                oMaskDC:DrawCircle(nCenter, nCenter, nRadius);
            elseif (nBoundary > 0) then
                local tPoints = {};
                local nPolygonRadius = nBoundary * nRadius / math.cos(nStep / 2);

                for nIndex = 0, nBlades - 1 do
                    local nAngle = nRotation + (nIndex - 0.5) * nStep;
                    tPoints[#tPoints + 1] = _wx.wxPoint(
                        math.floor(nCenter + math.cos(nAngle) * nPolygonRadius + 0.5),
                        math.floor(nCenter + math.sin(nAngle) * nPolygonRadius + 0.5));
                end

                oMaskDC:DrawPolygon(tPoints);

                for _, oPoint in ipairs(tPoints) do
                    oPoint:delete();
                end
            end

            oMaskDC:SelectObject(_wx.wxNullBitmap);
            oMaskDC:delete();
            local oMask = _wx.wxMask(oMaskBitmap);
            oTarget:SetMask(oMask);
        end

        --[[!
        @fqxn wxLuma.UI.IrisProgress.raster.layer
        @desc Composites a stationary material or cached picture through a native
            aperture mask. The final circle mask clips every leaf and image layer.
        !]]
        local function fLayer(oBrush, oSource, nBoundary, bInvert)
            local oLayer = fBuffer("layer", nSize);
            local oLayerDC = _wx.wxMemoryDC();
            oLayerDC:SelectObject(oLayer);
            oLayerDC:SetBackground(oBrush);
            oLayerDC:Clear();

            if (oSource) then
                oLayerDC:DrawBitmap(oSource, 0, 0, false);
            end

            oLayerDC:SelectObject(_wx.wxNullBitmap);
            oLayerDC:delete();
            fMaskBitmap(oLayer, nBoundary, bInvert, false);
            oDC:DrawBitmap(oLayer, 0, 0, true);
        end

        if (nOpen > 0) then
            fLayer(bOpening and nCurrent > 0 and tBrushes.Fill or tBrushes.Track,
                oPictureBitmap, nOpen, false);
        end

        if (nReserved > 0) then
            fLayer(tBrushes.Reserve, nil, sReserveDirection == "outward" and nReserved or 1 - nReserved,
                sReserveDirection == "inward");
        end

        oDC:SelectObject(_wx.wxNullBitmap);
        oDC:delete();

        fMaskBitmap(oBitmap, 1, false, true);
        local oComposed = fBuffer("composed", nSize);
        local oComposedDC = _wx.wxMemoryDC();
        oComposedDC:SelectObject(oComposed);
        oComposedDC:SetBackground(tBrushes.Background);
        oComposedDC:Clear();
        oComposedDC:DrawBitmap(oBitmap, 0, 0, true);
        oComposedDC:SelectObject(_wx.wxNullBitmap);
        oComposedDC:delete();

        local oLarge = oComposed:ConvertToImage();
        local oSmall = oLarge:Scale(nDiameter, nDiameter, _wx.wxIMAGE_QUALITY_HIGH);
        local oReplacement = _wx.wxBitmap(oSmall);
        oSmall:delete();
        oLarge:delete();

        if (oRaster) then
            oRaster:delete();
        end

        oRaster, sRasterKey = oReplacement, sKey;
    end

    --[[!
    @fqxn wxLuma.UI.IrisProgress.draw
    @desc Draws the centered cached iris and skinned caption into a borrowed DC.
        Non-square layouts preserve the circle; clipping includes the whole object.
    @param wxDC oDC Borrowed destination.
    @param number nWidth Available width.
    @param number nHeight Available height.
    !]]
    function oComponent.draw(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end

        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)));
        tArt.part(oDC, "Background "..(oComponent.isEnabled() and "Normal" or "Disabled"), 0, 0, nWidth, nHeight);
        local nDiameter = math.floor(math.min(nWidth, nHeight));

        if (nDiameter > 4) then
            fRaster(nDiameter);
            local nX, nY = math.floor((nWidth - nDiameter) / 2), math.floor((nHeight - nDiameter) / 2);
            oDC:DrawBitmap(oRaster, nX, nY, false);
            local nHalf = math.floor((nDiameter / 2 - 2) / math.sqrt(2));
            local oTextClip = _wx.wxDCClipper(oDC, _wx.wxRect(nX + nDiameter / 2 - nHalf,
                nY + nDiameter / 2 - nHalf, math.max(1, nHalf * 2), math.max(1, nHalf * 2)));
            local sDisplay = sText:gsub("%%v", tostring(oComponent.Value)):gsub("%%m", tostring(oComponent.Max));
            oDC:SetFont(oComponent.Skin.Font);
            local nTextWidth, nTextHeight = oDC:GetTextExtent(sDisplay);
            tArt.text(oDC, sDisplay, nX + (nDiameter - nTextWidth) / 2,
                nY + (nDiameter - nTextHeight) / 2, oComponent.isEnabled());
            oTextClip:delete();
        end

        oClip:delete();
    end

    -- The parent owns the native window; this object owns decoded/cached images.
    oComponent.onDestroy = function()
        fClearBuffers();
        fClearPicture();
        fClearMaterials();

        if (oRaster) then
            oRaster:delete();
            oRaster = nil;
        end

        if (oImage) then
            oImage:delete();
            oImage = nil;
        end

        tArt.destroy();
    end;
    return oComponent;
end

return IrisProgress;
