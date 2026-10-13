-- Translate resolved game styles for HTML; Styles.ini remains the source of truth.
local StyleEditor = require("Windows.StyleEditor");
local Styles = {};

local function quote(sText)
    return '"'..tostring(sText):gsub('[\\"\r\n]', function(sChar) return "\\"..string.format("%x ", sChar:byte()); end)..'"';
end

local function colour(nColor)
    return string.format("rgba(%d,%d,%d,%.5f)", (nColor >> 24) & 255, (nColor >> 16) & 255, (nColor >> 8) & 255, (nColor & 255) / 255);
end

-- CSS paints its first shadow on top; FontStyle draws its last effect on top.
-- Convert the same effect offsets to em so manual-only font sizes scale them.
local function effects(tStyle)
    local tLayers = {};
    local nFontPixels = math.max(1, tStyle.FontSize * 4 / 3);
    local function layer(nX, nY, nColor)
        tLayers[#tLayers + 1] = string.format("%.9gem %.9gem 0 %s", nX / nFontPixels, nY / nFontPixels, colour(nColor));
    end
    local function rgba(nColor, nAlpha)
        return (nColor & 0xffffff00) | math.max(0, math.min(255, math.floor(nAlpha)));
    end

    if (tStyle.GlowEnabled and tStyle.GlowRadius > 0 and tStyle.GlowAlphaMax > 0) then
        local nRadius = tStyle.GlowRadius;
        local nInner = tStyle.GlowColor;
        local nOuter = tStyle.GlowGradientEnabled and tStyle.GlowOuterColor or nInner;
        for nDistance = nRadius, 1, -1 do
            local nMix = nDistance / nRadius;
            local function channel(nShift)
                return math.floor(((nInner >> nShift) & 255) * (1 - nMix) + ((nOuter >> nShift) & 255) * nMix + 0.5);
            end
            local nSamples = math.min(32, math.max(8, math.ceil(2 * math.pi * nDistance)));
            local nAlpha = math.floor(tStyle.GlowAlphaMax * (channel(0) / 255) * math.exp(-2 * nMix * nMix) / nSamples + 0.5);
            if (nAlpha > 0) then
                local nColor = (channel(24) << 24) | (channel(16) << 16) | (channel(8) << 8) | nAlpha;
                for nSample = 0, nSamples - 1 do
                    local nRadians = 2 * math.pi * nSample / nSamples;
                    layer(math.cos(nRadians) * nDistance, math.sin(nRadians) * nDistance, nColor);
                end
            end
        end
    end
    if (tStyle.ShadowEnabled) then
        local nRadius = tStyle.ShadowRadius;
        for nY = -nRadius, nRadius do
            for nX = -nRadius, nRadius do
                if (nX * nX + nY * nY <= nRadius * nRadius) then
                    local nColor = tStyle.ShadowColor;
                    if (tStyle.ShadowSoftness) then
                        local nWeight = nRadius == 0 and 1 or math.exp(-2 * (nX * nX + nY * nY) / (nRadius * nRadius));
                        nColor = rgba(nColor, (nColor & 255) * nWeight / math.max(1, nRadius * nRadius));
                    end
                    layer(tStyle.ShadowX + nX, tStyle.ShadowY + nY, nColor);
                end
            end
        end
    end
    if (tStyle.D3Enabled) then
        for nDepth = tStyle.D3Depth, 1, -1 do
            layer(nDepth * tStyle.D3StepX, nDepth * tStyle.D3StepY, rgba(tStyle.D3Color, 20 + nDepth * 12));
        end
    end
    if (tStyle.OutlineEnabled) then
        local nRadius = tStyle.OutlineThickness;
        for nY = -nRadius, nRadius do
            for nX = -nRadius, nRadius do
                local nDistance = nX * nX + nY * nY;
                if (nDistance > 0 and nDistance <= nRadius * nRadius) then layer(nX, nY, tStyle.OutlineColor); end
            end
        end
    end
    local tShadows = {};
    for nIndex = #tLayers, 1, -1 do tShadows[#tShadows + 1] = tLayers[nIndex]; end
    return #tShadows > 0 and table.concat(tShadows, ",") or "none";
end

-- Names are generated rather than stored. Encode punctuation to avoid collisions.
function Styles.tag(sName)
    return "s-"..sName:lower():gsub("[^a-z0-9]", function(sChar) return string.format("-%02x-", sChar:byte()); end);
end

-- Read the game's sheet, independent of the active card set's style cache.
function Styles.load(pFile)
    local tModel = StyleEditor.model(pFile);
    local tCSS, tItems = {}, {};

    for _, sName in ipairs(tModel.names) do
        local tStyle = assert(tModel.parsed(sName), "Cannot parse game style: "..sName);
        local tFont = tStyle.FontOptions;
        local tValues = {
            "font-family:"..quote(tStyle.FontFamily),
            "font-size:"..tStyle.FontSize.."pt",
            "color:"..colour(tStyle.FontColor),
            "font-weight:"..(tFont.Bold and "bold" or "normal"),
            "font-style:"..(tFont.Italic and "italic" or "normal"),
            "letter-spacing:"..tStyle.LetterSpacing.."px",
        };
        local tDecorations = {};
        if (tFont.Underline) then tDecorations[#tDecorations + 1] = "underline"; end
        if (tFont.StrikeOut) then tDecorations[#tDecorations + 1] = "line-through"; end
        tValues[#tValues + 1] = "text-decoration:"..(#tDecorations > 0 and table.concat(tDecorations, " ") or "none");
        if (tStyle.BackgroundEnabled) then
            tValues[#tValues + 1] = "background-color:"..colour(tStyle.BackgroundColor);
            tValues[#tValues + 1] = "padding:"..tStyle.BackgroundPadding.."px";
        end
        tValues[#tValues + 1] = "text-shadow:"..effects(tStyle);
        local sTag = Styles.tag(sName);
        tCSS[#tCSS + 1] = "[data-style="..quote(sName).."],"..sTag.."{"..table.concat(tValues, ";").."}";
        tCSS[#tCSS + 1] = ".manual-text "..sTag..",.manual-text [data-style="..quote(sName).."]{font-size:inherit}";
        tItems[#tItems + 1] = {name = sName, tag = sTag, style = tStyle};
    end

    return table.concat(tCSS, "\n"), tModel.original, tItems;
end

return Styles;
