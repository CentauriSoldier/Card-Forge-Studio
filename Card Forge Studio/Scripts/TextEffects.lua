local wx            = require("wx");
local math          = math;
local string        = string;
local table         = table;
local TextEffects   = {};
local tCache        = {};
local tCacheOrigins = {};
local nCacheCount   = 0;
local tCacheUse     = {};
local nCacheClock   = 0;
local pLoadedFile;
local sLoadedStamp;
local tUserEffects  = {};

--[[!
@fqxn CFS.Modules.TextEffects
@desc Renders native font masks and applies named pixel processors. Built-in processors live in this module. A game's Scripts/Effects.lua returns a table indexed by effect name; each entry supplies integer Padding (0..64) and a Shade function. Shade(tMask, nX, nY) returns red, green, blue and alpha bytes. Coordinates are zero-based in the padded raster. tMask exposes Width, Height, FontHeight, Alpha(x,y) (0..255) and Distance(x,y) (distance inside the text edge, zero outside). Out-of-bounds samples return zero. Processors run in the game's UserEnv and must be deterministic; results are cached by font, text, spacing, effect and source-file signature. User names may override built-in names. Editing the file reloads processors on the next requested draw; errors are reported without using stale effects. StampedSilver uses the same stamped geometry with neutral grayscale faces and sidewalls; Stamped retains its warm lighting. No font sizing or fitting is performed.
!]]
local tSteelBands = {{0, 235}, {0.16, 228}, {0.40, 208}, {0.55, 174}, {0.68, 196}, {0.82, 200}, {1, 159}};
local tBuiltIn = {
    Stamped = {
        Padding = 8,
        Shade = function(tMask, nX, nY)
            local nAlpha = tMask.Alpha(nX, nY);
            local nDistance = tMask.Distance(nX, nY);
            local tSteel = tMask.Steel;
            local tColumn, tRow = tSteel.Columns[nX], tSteel.Rows[nY];
            local nBevel = tSteel.Bevel;
            local nRed, nGreen, nBlue;
            local nDepth = tSteel.Depth;
            local nWallAlpha, nWallDepth = 0, 0;
            local nShadow = 0;
            local nWallR, nWallG, nWallB = 0, 0, 0;
            --An opaque front completely hides its sidewall and shadow. Avoid those samples.
            if (nAlpha < 255) then
                for nStep = 1, 8 do
                    local nOffset = tSteel.Offsets[nStep];
                    local nSample = tMask.Alpha(nX - nOffset * 0.6, nY - nOffset);
                    if (nSample > nWallAlpha) then nWallAlpha, nWallDepth = nSample, nOffset; end
                end
                nShadow = (tMask.Alpha(nX - nDepth * 0.6 - 1, nY - nDepth - 1)
                    + tMask.Alpha(nX - nDepth * 0.6 - 2, nY - nDepth - 2)) * 0.28;
                local nWallLight = 42 + 19 * (1 - nWallDepth / nDepth);
                if (tSteel.Neutral) then
                    nWallR, nWallG, nWallB = nWallLight, nWallLight, nWallLight;
                else
                    nWallR, nWallG, nWallB = nWallLight + 5, nWallLight + 2, nWallLight - 4;
                    local nBounce = tRow.Bounce * tColumn.Lamp;
                    nWallR, nWallG, nWallB = nWallR + 66 * nBounce, nWallG + 30 * nBounce, nWallB;
                end
            end

            if (nAlpha > 0) then
                --Average edge gradients across neighboring rows/columns to suppress pixel steps.
                local nDX = (tMask.Distance(nX + 1, nY - 1) + 2 * tMask.Distance(nX + 1, nY) + tMask.Distance(nX + 1, nY + 1)
                    - tMask.Distance(nX - 1, nY - 1) - 2 * tMask.Distance(nX - 1, nY) - tMask.Distance(nX - 1, nY + 1)) / 8;
                local nDY = (tMask.Distance(nX - 1, nY + 1) + 2 * tMask.Distance(nX, nY + 1) + tMask.Distance(nX + 1, nY + 1)
                    - tMask.Distance(nX - 1, nY - 1) - 2 * tMask.Distance(nX, nY - 1) - tMask.Distance(nX + 1, nY - 1)) / 8;
                local nLight = (nDX + nDY) / math.sqrt(2 * (nDX * nDX + nDY * nDY + 0.25));
                --Broad environment reflections cross the complete text run, never repeat per letter.
                local nPosition = math.max(0, math.min(1, tRow.Position + tColumn.Tilt));
                local nFace = tSteelBands[#tSteelBands][2];
                for nBand = 2, #tSteelBands do
                    local tPrevious, tNext = tSteelBands[nBand - 1], tSteelBands[nBand];
                    if (nPosition <= tNext[1]) then
                        local nMix = (nPosition - tPrevious[1]) / (tNext[1] - tPrevious[1]);
                        nMix = nMix * nMix * (3 - 2 * nMix);
                        nFace = tPrevious[2] + (tNext[2] - tPrevious[2]) * nMix;
                        break;
                    end
                end
                --Keep a planar chamfer, with a narrow antialiased transition to the flat face.
                local nBlend = math.max(0, math.min(1, (nDistance - nBevel + 0.2) / 0.4));
                nBlend = nBlend * nBlend * (3 - 2 * nBlend);
                --A planar bevel has a fixed slope; its highlight follows the incident light.
                local nEdge = 118 + 131 * nLight;
                nEdge = math.max(48, nEdge);
                --A thin specular lip separates the bevel from the satin face.
                local nLip = math.exp(-((nDistance - nBevel + 0.18) / 0.22) ^ 2) * math.max(0, nLight);
                nEdge = nEdge + 25 * nLip;
                local nValue = nEdge + (nFace - nEdge) * nBlend;
                --Very shallow brushing runs continuously across the name, without distressing its mask.
                local nBrush = tRow.Brush + 0.45 * math.sin(nY * 31.7 + nX * 0.035);
                nValue = nValue + nBrush * nBlend;
                if (tSteel.Neutral) then
                    nRed, nGreen, nBlue = nValue, nValue, nValue;
                else
                    --Amber bounce is concentrated on lower-facing bevels near the warm lamps.
                    local nNormal = math.sqrt(nDX * nDX + nDY * nDY + 0.1);
                    local nLowerEdge = math.max(0, -nDY / nNormal) * (1 - nBlend);
                    local nLamp = 0.35 + 0.65 * tColumn.Lamp;
                    local nWarmth = nLowerEdge * math.exp(-((nPosition - 0.9) / 0.18) ^ 2) * nLamp;
                    nRed, nGreen, nBlue = nValue + 8 + 70 * nWarmth, nValue + 5 + 25 * nWarmth, nValue - 35 * nWarmth;
                end
            else
                nRed, nGreen, nBlue = nWallR, nWallG, nWallB;
            end

            --Composite the antialiased face over its sidewall instead of leaving a dark fringe.
            local nFront = nAlpha / 255;
            local nBack = nWallAlpha / 255;
            local nOpacity = nFront + nBack * (1 - nFront);
            if (nOpacity > 0) then
                nRed = (nRed * nFront + nWallR * nBack * (1 - nFront)) / nOpacity;
                nGreen = (nGreen * nFront + nWallG * nBack * (1 - nFront)) / nOpacity;
                nBlue = (nBlue * nFront + nWallB * nBack * (1 - nFront)) / nOpacity;
            end
            local nShadowOpacity = nShadow / 255 * (1 - nOpacity);
            local nTotal = nOpacity + nShadowOpacity;
            if (nTotal > 0) then
                nRed = (nRed * nOpacity + 5 * nShadowOpacity) / nTotal;
                nGreen = (nGreen * nOpacity + 5 * nShadowOpacity) / nTotal;
                nBlue = (nBlue * nOpacity + 5 * nShadowOpacity) / nTotal;
            end
            nAlpha = nTotal * 255;

            return nRed, nGreen, nBlue, nAlpha;
        end,
    },
};

--Neutral steel shares the existing bevel, extrusion and sampling geometry.
--The original Stamped effect retains its warm face and amber lamp reflections.
tBuiltIn.StampedSilver = {
    Padding = tBuiltIn.Stamped.Padding,
    Shade = tBuiltIn.Stamped.Shade,
};

--[[!
@fqxn CFS.Modules.TextEffects.Functions.Clear
@desc Releases cached material bitmaps and game processor references.
@ret void none No values returned.
!]]
function TextEffects.Clear()
    for _, oBitmap in pairs(tCache) do oBitmap:delete(); end
    tCache, nCacheCount, tCacheUse, nCacheClock = {}, 0, {}, 0;
    tCacheOrigins = {};
    pLoadedFile, sLoadedStamp, tUserEffects = nil, nil, {};
end

--[[!
@fqxn CFS.Modules.TextEffects.Functions.Get
@desc Resolves a named built-in or game processor, reloading changed game source in UserEnv. Failed loads are not cached.
@param string sName Case-sensitive effect name.
@param string|nil pFile FS game effect path; nil means built-ins only.
@param string sStamp Current source signature, or missing.
@param table tEnvironment Existing game UserEnv.
@ret table tEffect Validated Padding and Shade processor.
!]]
function TextEffects.Get(sName, pFile, sStamp, tEnvironment)
    if (pFile ~= pLoadedFile or sStamp ~= sLoadedStamp) then
        local tEffects = {};
        if (pFile and sStamp ~= "missing") then
            local hFile = assert(io.open(pFile, "rb"));
            local sCode = assert(hFile:read("a"));
            assert(hFile:close());
            local fChunk = assert(load(sCode, "@"..pFile, "t", tEnvironment));
            tEffects = fChunk();
            assert(rawtype(tEffects) == "table", "Effects.lua must return a table of named effects.");
            for sEffect, tEffect in pairs(tEffects) do
                assert(rawtype(sEffect) == "string" and rawtype(tEffect) == "table" and rawtype(tEffect.Shade) == "function", "Invalid game text effect.");
                local nPadding = tEffect.Padding;
                assert(rawtype(nPadding) == "number" and nPadding >= 0 and nPadding <= 64 and nPadding == math.floor(nPadding), "Effect Padding must be an integer from 0 to 64.");
            end
        end
        TextEffects.Clear();
        pLoadedFile, sLoadedStamp, tUserEffects = pFile, sStamp, tEffects;
    end

    return assert(tUserEffects[sName] or tBuiltIn[sName], "Unknown text effect: "..sName);
end

--[[!
@fqxn CFS.Modules.TextEffects.Functions.Render
@desc Renders a complete native text run to an antialiased mask, derives inside-edge distances and shades the padded raster. Zero Style letter spacing retains native run shaping; nonzero spacing follows FontStyle's individual-code-point spacing. Whole-run centering never repositions individual glyphs. The built-in Stamped material uses threefold internal sampling and downsamples the finished material without changing font size or custom processor coordinates. The 32-entry cache evicts only the least recently used bitmap. Cached bitmaps are owned by this module.
@param wxFont oFont Style font used as-is.
@param number nSpacing Style letter spacing in pixels.
@param string sText Valid UTF-8 text without line breaks.
@param string sName Effect name for the cache.
@param table tEffect Processor returned by Get, or an internal Style overlay. Optional NeedsSignedDistance adds a SignedDistance(x,y) sampler (positive inside, negative outside); legacy samplers and material output are unchanged.
@ret wxBitmap|nil oBitmap Rendered material, or nil for whitespace.
@ret number nWidth Visible material width.
@ret number nHeight Visible material height.
@ret number nOffsetX Cropped raster origin relative to the original text draw X; optional for legacy material callers.
@ret number nOffsetY Cropped raster origin relative to the original text draw Y. Offsets are also returned on cache hits; the cached bitmap remains owned by TextEffects.
!]]
function TextEffects.Render(oFont, nSpacing, sText, sName, tEffect)
    local sKey = table.concat({oFont:GetNativeFontInfoDesc(), tostring(nSpacing), sName, sText}, "\0");
    if (tEffect.NeedsSignedDistance) then sKey = sKey.."\0signed"; end
    local oCached = tCache[sKey];
    if (oCached) then
        nCacheClock = nCacheClock + 1;
        tCacheUse[sKey] = nCacheClock;
        local tOrigin = tCacheOrigins[sKey];
        return oCached, oCached:GetWidth(), oCached:GetHeight(), tOrigin.X, tOrigin.Y;
    end

    local oDC = wx.wxMemoryDC();
    local oProbe = wx.wxBitmap(1, 1, 24);
    oDC:SelectObject(oProbe);
    local oGC = assert(wx.wxGraphicsContext.Create(oDC), "Could not create text mask context.");
    oGC:SetFont(oFont, wx.wxWHITE);
    local tParts = {};
    local nWidth, nHeight = oGC:GetTextExtent(sText);
    if (nSpacing ~= 0) then
        nWidth = 0;
        for _, nCode in utf8.codes(sText) do
            local sCharacter = utf8.char(nCode);
            tParts[#tParts + 1] = {Text = sCharacter, X = nWidth};
            nWidth = nWidth + oGC:GetTextExtent(sCharacter) + nSpacing;
        end
        nWidth = nWidth - nSpacing;
    end
    oGC:delete(); oDC:SelectObject(wx.wxNullBitmap); oProbe:delete();

    --The built-in metal is shaded at three samples per pixel; user processors retain their pixel contract.
    local bStamped = tEffect == tBuiltIn.Stamped or tEffect == tBuiltIn.StampedSilver;
    local nRasterScale = bStamped and 3 or 1;
    --Guard space permits italic overhangs and the processor's material outline.
    local nGuard = math.ceil(math.max(nHeight, 1)) + tEffect.Padding;
    local nWidthMask = math.max(1, math.ceil(nWidth + 2 * nGuard) * nRasterScale);
    local nHeightMask = math.max(1, math.ceil(nHeight + 2 * nGuard) * nRasterScale);
    assert(nWidthMask * nHeightMask <= 2000000, "Text effect exceeds the two-million-pixel raster limit.");
    local oMask = wx.wxBitmap(nWidthMask, nHeightMask, 24);
    oDC:SelectObject(oMask); oDC:SetBackground(wx.wxBLACK_BRUSH); oDC:Clear();
    oGC = assert(wx.wxGraphicsContext.Create(oDC));
    oGC:Scale(nRasterScale, nRasterScale);
    oGC:SetFont(oFont, wx.wxWHITE);
    if (nSpacing == 0) then
        oGC:DrawText(sText, nGuard, nGuard);
    else
        for _, tPart in ipairs(tParts) do oGC:DrawText(tPart.Text, nGuard + tPart.X, nGuard); end
    end
    oGC:delete(); oDC:SelectObject(wx.wxNullBitmap); oDC:delete();
    local oImage = oMask:ConvertToImage(); oMask:delete();
    local sRGB = oImage:GetData(); oImage:delete();
    local nLeft, nTop, nRight, nBottom = nWidthMask, nHeightMask, -1, -1;
    for nY = 0, nHeightMask - 1 do
        for nX = 0, nWidthMask - 1 do
            if (sRGB:byte((nY * nWidthMask + nX) * 3 + 1) > 0) then
                nLeft, nTop = math.min(nLeft, nX), math.min(nTop, nY);
                nRight, nBottom = math.max(nRight, nX), math.max(nBottom, nY);
            end
        end
    end
    if (nRight < nLeft) then return nil, 0, 0, 0, 0; end
    local nPadding = tEffect.Padding * nRasterScale;
    nLeft, nTop = math.floor(nLeft / nRasterScale) * nRasterScale, math.floor(nTop / nRasterScale) * nRasterScale;
    nRight, nBottom = math.ceil((nRight + 1) / nRasterScale) * nRasterScale - 1, math.ceil((nBottom + 1) / nRasterScale) * nRasterScale - 1;
    nLeft, nTop = nLeft - nPadding, nTop - nPadding;
    local nW, nH = nRight - nLeft + nPadding + 1, nBottom - nTop + nPadding + 1;
    local tAlpha, tDistance = {}, {};
    for nY = 0, nH - 1 do
        for nX = 0, nW - 1 do
            local nSourceX, nSourceY = nLeft + nX, nTop + nY;
            local nIndex = nY * nW + nX + 1;
            local nAlpha = nSourceX >= 0 and nSourceX < nWidthMask and nSourceY >= 0 and nSourceY < nHeightMask and sRGB:byte((nSourceY * nWidthMask + nSourceX) * 3 + 1) or 0;
            tAlpha[nIndex] = nAlpha;
            tDistance[nIndex] = nAlpha >= 128 and math.huge or 0;
        end
    end
    --Two chamfer passes provide stable bevel normals around the entire run.
    local function fDistance(nX, nY)
        if (nX < 0 or nY < 0 or nX >= nW or nY >= nH) then return 0; end
        return tDistance[nY * nW + nX + 1];
    end
    for nY = 0, nH - 1 do
        for nX = 0, nW - 1 do
            local nI = nY * nW + nX + 1;
            tDistance[nI] = math.min(tDistance[nI], fDistance(nX - 1, nY) + 1, fDistance(nX, nY - 1) + 1, fDistance(nX - 1, nY - 1) + 1.414214, fDistance(nX + 1, nY - 1) + 1.414214);
        end
    end
    for nY = nH - 1, 0, -1 do
        for nX = nW - 1, 0, -1 do
            local nI = nY * nW + nX + 1;
            tDistance[nI] = math.min(tDistance[nI], fDistance(nX + 1, nY) + 1, fDistance(nX, nY + 1) + 1, fDistance(nX + 1, nY + 1) + 1.414214, fDistance(nX - 1, nY + 1) + 1.414214);
        end
    end
    local tMask = {
        Width = nW / nRasterScale, Height = nH / nRasterScale, FontHeight = nHeight,
        Distance = function(nX, nY)
            return fDistance(math.floor(nX * nRasterScale + 0.5), math.floor(nY * nRasterScale + 0.5)) / nRasterScale;
        end,
        Alpha = function(nX, nY)
            nX, nY = math.floor(nX * nRasterScale + 0.5), math.floor(nY * nRasterScale + 0.5);
            if (nX < 0 or nY < 0 or nX >= nW or nY >= nH) then return 0; end
            return tAlpha[nY * nW + nX + 1];
        end,
    };
    -- Optional outside distances share the same raster; legacy processors retain exactly
    -- their existing Alpha/Distance samplers and skip these extra passes altogether.
    if (tEffect.NeedsSignedDistance) then
        local tOutside = {};
        for nIndex, nAlpha in ipairs(tAlpha) do tOutside[nIndex] = nAlpha >= 128 and 0 or math.huge; end
        local function outside(nX, nY)
            if (nX < 0 or nY < 0 or nX >= nW or nY >= nH) then return math.huge; end
            return tOutside[nY * nW + nX + 1];
        end
        for nY = 0, nH - 1 do
            for nX = 0, nW - 1 do
                local nI = nY * nW + nX + 1;
                tOutside[nI] = math.min(tOutside[nI], outside(nX - 1, nY) + 1, outside(nX, nY - 1) + 1,
                    outside(nX - 1, nY - 1) + 1.414214, outside(nX + 1, nY - 1) + 1.414214);
            end
        end
        for nY = nH - 1, 0, -1 do
            for nX = nW - 1, 0, -1 do
                local nI = nY * nW + nX + 1;
                tOutside[nI] = math.min(tOutside[nI], outside(nX + 1, nY) + 1, outside(nX, nY + 1) + 1,
                    outside(nX + 1, nY + 1) + 1.414214, outside(nX - 1, nY + 1) + 1.414214);
            end
        end
        tMask.SignedDistance = function(nX, nY)
            nX, nY = math.floor(nX * nRasterScale + 0.5), math.floor(nY * nRasterScale + 0.5);
            if (nX < 0 or nY < 0 or nX >= nW or nY >= nH) then return -math.max(nW, nH) / nRasterScale; end
            local nIndex = nY * nW + nX + 1;
            if (tAlpha[nIndex] >= 128) then return (tDistance[nIndex] - 0.5) / nRasterScale; end
            return (0.5 - tOutside[nIndex]) / nRasterScale;
        end;
    end
    --These values depend on a row, column or font height, not on individual surface normals.
    --Only the built-in processor uses them; custom effects retain the existing mask contract.
    if (bStamped) then
        local tSteel = {
            Bevel = math.max(1.25, math.min(3.5, nHeight * 0.045)),
            Depth = math.max(2, math.min(4, nHeight * 0.085)),
            Columns = {}, Rows = {}, Offsets = {},
            Neutral = tEffect == tBuiltIn.StampedSilver,
        };
        for nStep = 1, 8 do tSteel.Offsets[nStep] = tSteel.Depth * nStep / 8; end
        for nX = 0, nW - 1 do
            local nPosition = nX / nRasterScale;
            tSteel.Columns[nPosition] = {
                Lamp = math.sin(nPosition / math.max(1, tMask.Width) * math.pi * 3) ^ 8,
                Tilt = 0.025 * (nPosition / math.max(1, tMask.Width - 1) - 0.5),
            };
        end
        for nY = 0, nH - 1 do
            local nPosition = nY / nRasterScale;
            tSteel.Rows[nPosition] = {
                Position = (nPosition - 8) / math.max(1, tMask.Height - 17),
                Bounce = math.exp(-((nPosition - tMask.Height + 10) / 4) ^ 2),
                Brush = 0.9 * math.sin(nPosition * 17.3),
            };
        end
        tMask.Steel = tSteel;
    end

    local function fByte(nValue)
        assert(rawtype(nValue) == "number" and nValue == nValue and math.abs(nValue) < math.huge, "Effect Shade must return four finite color components.");
        return math.max(0, math.min(255, math.floor(nValue + 0.5)));
    end
    local tRGB, tOpacity = {}, {};
    for nY = 0, nH - 1 do
        for nX = 0, nW - 1 do
            local nR, nG, nB, nA = tEffect.Shade(tMask, nX / nRasterScale, nY / nRasterScale);
            tRGB[#tRGB + 1] = string.char(fByte(nR), fByte(nG), fByte(nB));
            tOpacity[#tOpacity + 1] = string.char(fByte(nA));
        end
    end
    local oResult = wx.wxImage(nW, nH);
    oResult:SetData(table.concat(tRGB)); oResult:SetAlpha(table.concat(tOpacity));
    if (nRasterScale > 1) then
        local oSampled = oResult:Scale(nW / nRasterScale, nH / nRasterScale, wx.wxIMAGE_QUALITY_HIGH);
        oResult:delete(); oResult = oSampled;
    end
    local oBitmap = wx.wxBitmap(oResult); oResult:delete();
    --Keep the other 31 titles warm instead of flushing the complete cache.
    if (nCacheCount >= 32) then
        local sOldest, nOldest;
        for sCandidate, nUse in pairs(tCacheUse) do
            if (not nOldest or nUse < nOldest) then sOldest, nOldest = sCandidate, nUse; end
        end
        tCache[sOldest]:delete();
        tCache[sOldest], tCacheUse[sOldest], tCacheOrigins[sOldest] = nil, nil, nil;
        nCacheCount = nCacheCount - 1;
    end
    nCacheClock = nCacheClock + 1;
    tCache[sKey], tCacheUse[sKey] = oBitmap, nCacheClock;
    tCacheOrigins[sKey] = {X = nLeft / nRasterScale - nGuard, Y = nTop / nRasterScale - nGuard};
    nCacheCount = nCacheCount + 1;
    return oBitmap, oBitmap:GetWidth(), oBitmap:GetHeight(), tCacheOrigins[sKey].X, tCacheOrigins[sKey].Y;
end

return TextEffects;
