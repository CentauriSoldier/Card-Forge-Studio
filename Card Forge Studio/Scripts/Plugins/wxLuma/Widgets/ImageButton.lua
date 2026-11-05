local _wx     = require("wx");
local _Input  = require("wxLuma.Core.ControlInput");
local _Events = require("wxLuma.Core.ControlEvents");
local ImageButton = {};

--[[!
@fqxn wxLuma.UI.ImageButton.create
@desc Image action button using shared capture, keyboard, containment and lifecycle.
    Keeps one decoded source and one scaled bitmap per visual state at the current
    size. Transparent pixels reveal the optional Background painter. Parent owns
    the native control; destroy releases only this component's artwork.
@param wxWindow oParent Native owner.
@param table tOptions Skin, Image (path); optional Text, Enabled, Background(DC, component),
    OnClick(component), AlphaHit (true). AlphaHit=false uses the full control rectangle.
    Hover enlarges the image; press shrinks it. Alpha tests use the stable normal
    image footprint, excluding transparent pixels and caption. RGB images are opaque.
    Text styling: TextPosition (bottom/top/left/right/center), TextAlign (center/left/right),
    TextOffsetX/Y, TextGap, FontSize, FontFace, Bold, Italic, Underline, Strikethrough,
    TextColour, DisabledTextColour, TextShadow and TextOutline. See setTextOptions.
@ret table oComponent Shared input/events, image, text and style accessors.
!]]
function ImageButton.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "ImageButton requires Skin.");
    assert(type(tOptions.Image) == "string" and tOptions.Image ~= "", "Image path is required.");
    assert(tOptions.Text == nil or type(tOptions.Text) == "string", "Text must be a string.");
    assert(tOptions.OnClick == nil or type(tOptions.OnClick) == "function", "OnClick must be a function.");
    assert(tOptions.Background == nil or type(tOptions.Background) == "function", "Background must be a function.");
    assert(tOptions.AlphaHit == nil or type(tOptions.AlphaHit) == "boolean", "AlphaHit must be boolean.");
    local tEvents;
    local oComponent = _Input.create(oParent, tOptions, "ImageButton", function(oButton, tInput)
        local oImage;
        local pImage, sAlpha;
        local bAlphaHit = tOptions.AlphaHit ~= false;
        local tBitmaps = {};
        local nCachedWidth, nCachedHeight;
        tInput.Toggle, tInput.Enter = true, true;
        oButton.Skin = tOptions.Skin;
        oButton.isEnabled = tInput.enabled;

        -- Release the bounded render cache when source or display size changes.
        local function fClear()
            for _, oBitmap in pairs(tBitmaps) do oBitmap:delete(); end
            tBitmaps = {};
            nCachedWidth, nCachedHeight = nil, nil;
        end

        --[[!
        @fqxn wxLuma.UI.ImageButton.setImage
        @desc Decode before replacing the source; a failed load leaves current art intact.
        @param string pValue Image filename.
        @ret table oComponent This button.
        !]]
        function oButton.setImage(pValue)
            assert(not oButton.Disposed, "ImageButton is disposed.");
            assert(type(pValue) == "string" and pValue ~= "", "Image path is required.");
            if (pValue == pImage) then return oButton; end
            local hFile = assert(io.open(pValue, "rb"), "Image file cannot be opened: "..pValue);
            hFile:close();
            local oReplacement = _wx.wxImage(pValue, _wx.wxBITMAP_TYPE_ANY);
            if (not oReplacement:IsOk()) then
                oReplacement:delete();
                error("Image could not be decoded: "..pValue);
            end
            fClear();
            if (oImage) then oImage:delete(); end
            oImage, pImage = oReplacement, pValue;
            sAlpha = oImage:HasAlpha() and oImage:GetAlpha() or nil;
            tInput.refresh();
            return oButton;
        end

        --[[!
        @fqxn wxLuma.UI.ImageButton.getImage
        @ret string pImage Current image path.
        !]]
        function oButton.getImage() return pImage; end

        local tTextOptions;
        local oTextFont;
        local sMeasuredText;
        local nTextWidth, nTextHeight = 0, 0;
        local tTextKeys = {TextPosition = true, TextAlign = true, TextOffsetX = true, TextOffsetY = true,
            TextGap = true, FontSize = true, FontFace = true, Bold = true, Italic = true,
            Underline = true, Strikethrough = true, TextColour = true, DisabledTextColour = true,
            TextShadow = true, TextOutline = true};

        local function fFinite(nValue)
            return type(nValue) == "number" and nValue == nValue and math.abs(nValue) < math.huge;
        end
        local function fColour(tValue)
            assert(type(tValue) == "table", "Text colour requires RGBA fields.");
            local tCopy = {};
            for _, sKey in ipairs({"R", "G", "B", "A"}) do
                local nValue = tValue[sKey];
                assert(fFinite(nValue) and nValue % 1 == 0 and nValue >= 0 and nValue <= 255,
                    "Text colour requires integer RGBA channels from 0 through 255.");
                tCopy[sKey] = nValue;
            end
            return tCopy;
        end
        local function fCopy(tValue)
            local tCopy = {};
            for sKey, vValue in pairs(tValue) do
                tCopy[sKey] = type(vValue) == "table" and fCopy(vValue) or vValue;
            end
            return tCopy;
        end
        local function fMeasure()
            if (sMeasuredText == oButton.Text) then return; end
            local oMeasure = _wx.wxClientDC(oButton.Control);
            oMeasure:SetFont(oTextFont);
            nTextWidth, nTextHeight = oMeasure:GetTextExtent(oButton.Text);
            oMeasure:delete(); sMeasuredText = oButton.Text;
        end

        --[[!
        @fqxn wxLuma.UI.ImageButton.setTextOptions
        @desc Atomically updates supplied settings. Position is top/bottom/left/right/center;
            center overlays the image. Alignment is left/center/right in the text region.
            Offsets are client pixels; gap reserves caption space. Font size is in points.
            Colours are copied RGBA tables. Shadow is false or {Colour, OffsetX, OffsetY};
            outline is false or {Colour, Width} (1-4 pixels). Decorations are independent.
            Source images are not decoded again. Invalid settings preserve current styling.
        @param table tChanges TextPosition, TextAlign, TextOffsetX/Y, TextGap, FontSize,
            FontFace, Bold, Italic, Underline, Strikethrough, TextColour, DisabledTextColour,
            TextShadow, TextOutline. Unspecified settings retain their current values.
        @ret table oComponent This button.
        !]]
        function oButton.setTextOptions(tChanges)
            assert(not oButton.Disposed and type(tChanges) == "table", "Text options require a live button and table.");
            local tNext = tTextOptions and fCopy(tTextOptions) or {
                TextPosition = "bottom", TextAlign = "center", TextOffsetX = 0, TextOffsetY = 0, TextGap = 8,
                FontSize = tOptions.Skin.Font:GetPointSize(), FontFace = tOptions.Skin.Font:GetFaceName(),
                Bold = tOptions.Skin.Font:GetWeight() >= _wx.wxFONTWEIGHT_BOLD,
                Italic = tOptions.Skin.Font:GetStyle() ~= _wx.wxFONTSTYLE_NORMAL,
                Underline = tOptions.Skin.Font:GetUnderlined(), Strikethrough = tOptions.Skin.Font:GetStrikethrough(),
                TextColour = {R = 208, G = 218, B = 230, A = 255},
                DisabledTextColour = {R = 114, G = 126, B = 139, A = 255},
                TextShadow = false, TextOutline = false
            };
            for sKey, vValue in pairs(tChanges) do
                assert(tTextKeys[sKey], "Unknown text option: "..tostring(sKey));
                tNext[sKey] = vValue;
            end
            assert(tNext.TextPosition == "top" or tNext.TextPosition == "bottom" or tNext.TextPosition == "left"
                or tNext.TextPosition == "right" or tNext.TextPosition == "center", "Invalid TextPosition.");
            assert(tNext.TextAlign == "left" or tNext.TextAlign == "center" or tNext.TextAlign == "right", "Invalid TextAlign.");
            assert(fFinite(tNext.TextOffsetX) and fFinite(tNext.TextOffsetY), "Text offsets must be finite.");
            assert(fFinite(tNext.TextGap) and tNext.TextGap >= 0, "TextGap must be nonnegative and finite.");
            assert(fFinite(tNext.FontSize) and tNext.FontSize % 1 == 0 and tNext.FontSize >= 1
                and tNext.FontSize <= 512, "FontSize must be an integer from 1 through 512.");
            assert(type(tNext.FontFace) == "string" and tNext.FontFace ~= "", "FontFace must be a nonempty string.");
            for _, sKey in ipairs({"Bold", "Italic", "Underline", "Strikethrough"}) do
                assert(type(tNext[sKey]) == "boolean", sKey.." must be boolean.");
            end
            tNext.TextColour = fColour(tNext.TextColour);
            tNext.DisabledTextColour = fColour(tNext.DisabledTextColour);
            for _, sKey in ipairs({"TextShadow", "TextOutline"}) do
                local tEffect = tNext[sKey];
                assert(tEffect == false or type(tEffect) == "table", sKey.." requires false or an effect table.");
                if (tEffect) then
                    if (sKey == "TextShadow") then
                        assert(fFinite(tEffect.OffsetX) and fFinite(tEffect.OffsetY), "Shadow offsets must be finite.");
                        tNext[sKey] = {Colour = fColour(tEffect.Colour), OffsetX = tEffect.OffsetX, OffsetY = tEffect.OffsetY};
                    else
                        assert(fFinite(tEffect.Width) and tEffect.Width % 1 == 0 and tEffect.Width >= 1
                            and tEffect.Width <= 4, "Outline Width must be an integer from 1 through 4.");
                        tNext[sKey] = {Colour = fColour(tEffect.Colour), Width = tEffect.Width};
                    end
                end
            end
            local oReplacement = _wx.wxFont(tNext.FontSize, tOptions.Skin.Font:GetFamily(),
                tNext.Italic and _wx.wxFONTSTYLE_ITALIC or _wx.wxFONTSTYLE_NORMAL,
                tNext.Bold and _wx.wxFONTWEIGHT_BOLD or _wx.wxFONTWEIGHT_NORMAL,
                tNext.Underline, tNext.FontFace);
            if (not oReplacement:IsOk()) then oReplacement:delete(); error("Unable to create text font."); end
            oReplacement:SetStrikethrough(tNext.Strikethrough);
            local oOldFont = oTextFont;
            oTextFont, tTextOptions, sMeasuredText = oReplacement, tNext, nil;
            fMeasure(); fClear();
            if (oOldFont) then oOldFont:delete(); end
            tInput.refresh();
            return oButton;
        end

        --[[!
        @fqxn wxLuma.UI.ImageButton.getTextOptions
        @ret table tOptions Independent snapshot of text settings, including effect/colour tables.
        !]]
        function oButton.getTextOptions() return fCopy(tTextOptions); end

        --[[!
        @fqxn wxLuma.UI.ImageButton.setText
        @param string sValue Button caption; empty hides it.
        @ret table oComponent This button.
        !]]
        function oButton.setText(sValue)
            assert(not oButton.Disposed and type(sValue) == "string", "Text must be a string on a live button.");
            if (oButton.Text ~= sValue) then
                oButton.Text = sValue; fMeasure(); fClear(); tInput.refresh();
            end
            return oButton;
        end

        --[[!
        @fqxn wxLuma.UI.ImageButton.getText
        @ret string sText Current caption.
        !]]
        function oButton.getText() return oButton.Text; end

        local function fRegions(nWidth, nHeight)
            fMeasure();
            local nX, nY, nW, nH = 0, 0, nWidth, nHeight;
            local nTX, nTY, nTW, nTH = 4, nHeight - nTextHeight - 4, math.max(1, nWidth - 8), nTextHeight;
            if (oButton.Text ~= "") then
                local nGap = tTextOptions.TextGap;
                if (tTextOptions.TextPosition == "top") then
                    nY = nTextHeight + nGap; nH = math.max(1, nHeight - nY); nTY = 4;
                elseif (tTextOptions.TextPosition == "bottom") then
                    nH = math.max(1, nHeight - nTextHeight - nGap);
                elseif (tTextOptions.TextPosition == "left") then
                    nX = nTextWidth + nGap; nW = math.max(1, nWidth - nX);
                    nTW = nTextWidth; nTY = (nHeight - nTextHeight) / 2;
                elseif (tTextOptions.TextPosition == "right") then
                    nW = math.max(1, nWidth - nTextWidth - nGap);
                    nTX = nWidth - nTextWidth - 4; nTW = nTextWidth; nTY = (nHeight - nTextHeight) / 2;
                else
                    nTY = (nHeight - nTextHeight) / 2;
                end
            end
            return nX, nY, nW, nH, nTX, nTY, nTW, nTH;
        end

        local function fDrawText(oDC, nWidth, nHeight, nOffset)
            local _, _, _, _, nX, nY, nW = fRegions(nWidth, nHeight);
            if (tTextOptions.TextAlign == "center") then nX = nX + (nW - nTextWidth) / 2;
            elseif (tTextOptions.TextAlign == "right") then nX = nX + nW - nTextWidth; end
            nX = math.floor(nX + tTextOptions.TextOffsetX + nOffset);
            nY = math.floor(nY + tTextOptions.TextOffsetY + nOffset);
            oDC:SetFont(oTextFont); oDC:SetBackgroundMode(_wx.wxTRANSPARENT);
            local function fPaint(tColour, nDX, nDY)
                local oColour = _wx.wxColour(tColour.R, tColour.G, tColour.B, tColour.A);
                oDC:SetTextForeground(oColour); oDC:DrawText(oButton.Text, nX + nDX, nY + nDY);
                oColour:delete();
            end
            if (tTextOptions.TextShadow) then
                local tShadow = tTextOptions.TextShadow;
                fPaint(tShadow.Colour, math.floor(tShadow.OffsetX), math.floor(tShadow.OffsetY));
            end
            if (tTextOptions.TextOutline) then
                local tOutline = tTextOptions.TextOutline;
                for nDY = -tOutline.Width, tOutline.Width do
                    for nDX = -tOutline.Width, tOutline.Width do
                        if (nDX ~= 0 or nDY ~= 0) then fPaint(tOutline.Colour, nDX, nDY); end
                    end
                end
            end
            fPaint(tInput.enabled() and tTextOptions.TextColour or tTextOptions.DisabledTextColour, 0, 0);
        end

        tInput.activate = function()
            if (tOptions.OnClick) then tOptions.OnClick(oButton); end
            if (tEvents and not oButton.Disposed) then tEvents.emit("activated", {}); end
        end;
        -- Keep hit geometry independent of hover/press animation to avoid edge flicker.
        local function fGeometry(nWidth, nHeight, nFactor)
            local nLeft, nTop, nAvailableWidth, nAvailableHeight = fRegions(nWidth, nHeight);
            local nScale = math.min(nAvailableWidth / oImage:GetWidth(),
                nAvailableHeight / oImage:GetHeight()) * nFactor;
            local nW = math.max(1, math.floor(oImage:GetWidth() * nScale));
            local nH = math.max(1, math.floor(oImage:GetHeight() * nScale));
            return nLeft + math.floor((nAvailableWidth - nW) / 2),
                nTop + math.floor((nAvailableHeight - nH) / 2), nW, nH;
        end

        --[[!
        @fqxn wxLuma.UI.ImageButton.hitTest
        @desc Tests control-local pixels. Alpha mode uses the normal image footprint;
            any nonzero source alpha is interactive. Visual scaling cannot change a hit.
        @param number nX Client x.
        @param number nY Client y.
        @ret boolean bHit Whether the enabled button accepts this point.
        !]]
        function oButton.hitTest(nX, nY)
            if (not tInput.enabled() or type(nX) ~= "number" or type(nY) ~= "number") then return false; end
            local nWidth, nHeight = oButton.Control:GetClientSizeWH();
            if (not (nX >= 0 and nY >= 0 and nX < nWidth and nY < nHeight)) then return false; end
            if (not bAlphaHit) then return true; end
            local nLeft, nTop, nW, nH = fGeometry(nWidth, nHeight, 0.92);
            if (nX < nLeft or nY < nTop or nX >= nLeft + nW or nY >= nTop + nH) then return false; end
            if (not sAlpha) then return true; end
            local nSourceX = math.floor((nX - nLeft) * oImage:GetWidth() / nW);
            local nSourceY = math.floor((nY - nTop) * oImage:GetHeight() / nH);
            return sAlpha:byte(nSourceY * oImage:GetWidth() + nSourceX + 1) > 0;
        end

        --[[!
        @fqxn wxLuma.UI.ImageButton.setAlphaHit
        @param boolean bValue True for image-alpha hits; false for the full rectangle.
        @ret table oComponent This button.
        !]]
        function oButton.setAlphaHit(bValue)
            assert(type(bValue) == "boolean", "AlphaHit must be boolean.");
            assert(not oButton.Disposed, "ImageButton is disposed.");
            tInput.release(); oButton.Hover = false;
            bAlphaHit = bValue; tInput.refresh();
            return oButton;
        end

        --[[!
        @fqxn wxLuma.UI.ImageButton.getAlphaHit
        @ret boolean bAlphaHit Current hit-testing policy.
        !]]
        function oButton.getAlphaHit() return bAlphaHit; end
        tInput.inside = oButton.hitTest;
        tInput.draw = function(oDC, nWidth, nHeight, sState)
            if (not oImage or nWidth < 1 or nHeight < 1) then return; end
            if (nWidth ~= nCachedWidth or nHeight ~= nCachedHeight) then
                fClear(); nCachedWidth, nCachedHeight = nWidth, nHeight;
            end
            local nFactor = sState == "Hover" and 1 or sState == "Pressed" and 0.88 or 0.92;
            local nX, nY, nW, nH = fGeometry(nWidth, nHeight, nFactor);
            if (not tBitmaps[sState]) then
                local oScaled = oImage:Scale(nW, nH, _wx.wxIMAGE_QUALITY_HIGH);
                local oState = sState == "Disabled" and oScaled:ConvertToGreyscale() or nil;
                tBitmaps[sState] = _wx.wxBitmap(oState or oScaled);
                if (oState) then oState:delete(); end
                oScaled:delete();
            end
            local nOffset = sState == "Pressed" and 1 or 0;
            oDC:DrawBitmap(tBitmaps[sState], nX + nOffset, nY + nOffset, true);
            if (oButton.Text ~= "") then fDrawText(oDC, nWidth, nHeight, nOffset); end
        end;

        -- Image buttons supply their own hover and press feedback;
        -- do not paint the shared input base's rectangular focus indicator.
        function oButton.draw(oDC, nWidth, nHeight)
            if (oButton.Disposed) then return; end
            if (tOptions.Background) then
                tOptions.Background(oDC, oButton);
            else
                local oBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
                oDC:SetBackground(oBrush); oDC:Clear(); oBrush:delete();
            end
            local sState = oButton.getState();
            tInput.draw(oDC, nWidth, nHeight, sState);
        end
        tInput.destroy = function()
            fClear();
            if (oImage) then oImage:delete(); oImage = nil; end
            sAlpha = nil;
            if (oTextFont) then oTextFont:delete(); oTextFont = nil; end
        end;
        local tInitialText = {};
        for sKey in pairs(tTextKeys) do tInitialText[sKey] = tOptions[sKey]; end
        oButton.setTextOptions(tInitialText);
        oButton.setImage(tOptions.Image);
    end);
    tEvents = _Events.attach(oComponent, nil, {"activated"});
    return oComponent;
end
return ImageButton;
