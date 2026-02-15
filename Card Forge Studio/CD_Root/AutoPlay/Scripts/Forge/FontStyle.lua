local class         = class;
local math          = math;
local rawtype       = rawtype;
local string        = string;
local toboolean     = toboolean;
local tonumber      = tonumber;
local tostring      = tostring;
local type          = type;
    local clamp         = math.clamp;
    local floor         = math.floor;
    local isnumber      = type.isnumber;
    local isstring      = type.istring;
    local istable       = type.istable;
local Color         = Color;
local Drawing       = Drawing;
local DrawingFont   = DrawingFont;
local INIFile       = INIFile;

local _tblErrorMessages = _tblErrorMessages;

local _oBlack       = Color.RGBA(0, 0, 0, 255);
local _oClear       = Color.RGBA(0, 0, 0, 0);



local function GetEffectBoundsTEST(nW, nH,
    bShadow, nShadowX, nShadowY, nShadowBlurRadius,
    b3D, n3DStepX, n3DStepY, n3DDepth,
    bOutline, nOutlineThickness,
    nFudgeX, nFudgeY)

    nW = floor(nW or 0);
    nH = floor(nH or 0);

    local nMinX = 0;
    local nMaxX = nW;
    local nMinY = 0;
    local nMaxY = nH;

    local function ApplyRect(nDX, nDY, nPadX, nPadY)
        nDX   = floor(nDX   or 0);
        nDY   = floor(nDY   or 0);
        nPadX = floor(nPadX or 0);
        nPadY = floor(nPadY or 0);

        local nX0 = nDX - nPadX;
        local nX1 = nW + nDX + nPadX;
        nMinX = math.min(nMinX, nX0, nX1);
        nMaxX = math.max(nMaxX, nX0, nX1);

        local nY0 = nDY - nPadY;
        local nY1 = nH + nDY + nPadY;
        nMinY = math.min(nMinY, nY0, nY1);
        nMaxY = math.max(nMaxY, nY0, nY1);
    end;

    -- base text: add small AA/overhang fudge
    ApplyRect(0, 0, nFudgeX or 2, nFudgeY or 1);

    -- shadow: offset + blur radius
    if (bShadow) then
        ApplyRect(nShadowX or 0, nShadowY or 0, nShadowBlurRadius or 0, nShadowBlurRadius or 0);
    end

    -- 3D: farthest layer at depth * step
    if (b3D) then
        local nDepth = floor(n3DDepth or 0);
        ApplyRect((n3DStepX or 0) * nDepth, (n3DStepY or 0) * nDepth, 0, 0);
    end

    -- outline: expands equally in all directions
    if (bOutline) then
        local nT = floor(nOutlineThickness or 0);
        if (nT > 0) then
            ApplyRect(0, 0, nT, nT);
        end
    end

    local nTotalW = nMaxX - nMinX;
    local nTotalH = nMaxY - nMinY;

    return nMinX, nMinY, nTotalW, nTotalH;
end



local function GetEffectBounds(nW, nH,
    bShadow, nShadowX, nShadowY,
    b3D, n3DStepX, n3DStepY, n3DDepth)

    local nMinX = 0;
    local nMaxX = nW;
    local nMinY = 0;
    local nMaxY = nH;

    local function ApplyDelta(nDX, nDY)
        -- X
        local nX0 = nDX;
        local nX1 = nW + nDX;
        nMinX = math.min(nMinX, nX0, nX1);
        nMaxX = math.max(nMaxX, nX0, nX1);

        -- Y
        local nY0 = nDY;
        local nY1 = nH + nDY;
        nMinY = math.min(nMinY, nY0, nY1);
        nMaxY = math.max(nMaxY, nY0, nY1);
    end;

    if (bShadow) then
        local nSX = floor(nShadowX or 0);
        local nSY = floor(nShadowY or 0);
        ApplyDelta(nSX, nSY);
    end

    if (b3D) then
        local nDepth = floor(n3DDepth or 0);
        local nDX    = floor((n3DStepX or 0) * nDepth);
        local nDY    = floor((n3DStepY or 0) * nDepth);
        ApplyDelta(nDX, nDY);
    end

    local nTotalW = nMaxX - nMinX;
    local nTotalH = nMaxY - nMinY;

    local nRetMinX = nMinX;
    local nRetMinY = nMinY;
    local nRetW    = nTotalW;
    local nRetH    = nTotalH;

    return nRetMinX, nRetMinY, nRetW, nRetH;
end














-- Local parser used by BOTH:
--   1) FontStyle.FromINI(pINI, sName)
--   2) this:Update()
--
-- Returns: tParsed (table) OR nil on failure
-- NOTE: Uses your existing string:trim/trimright functions (no extra helpers)

local function ParseFontStyleINI(pINI, sSectionName)
    local tRet = nil;

    local tValueNames = INIFile.GetValueNames(pINI, sSectionName);

    if (tValueNames) then

        local function val(sValName)
            local sRet = "";
            local sVal = INIFile.GetValue(pINI, sSectionName, sValName, true);

            if (type.isstring(sVal)) then
                sRet = sVal;
            end

            return sRet;
        end

        -- Font
        local sFontFamilyRaw    = val("Family");
        local sFontFamily       = type.isstring(sFontFamilyRaw) and sFontFamilyRaw:trimright() or "";
        sFontFamily             = (not sFontFamily:isempty()) and sFontFamily or "Times New Roman";

        local nFontSize         = floor(tonumber(val("Size")) or 12);--TODO FIX MAGIC NUMBER

        -- IMPORTANT: force alpha so 3-channel INI colors are opaque
        local nFontColor        = Color.TryFromString(val("Color"), true) or _oBlack;

        -- Options
        local tFontOptions = {
            Bold        = toboolean(val("Bold"))      and true or false;
            Italic      = toboolean(val("Italic"))    and true or false;
            Underline   = toboolean(val("Underline")) and true or false;
            StrikeOut   = toboolean(val("StrikeOut")) and true or false;
            HQ          = toboolean(val("HQ"))        and true or false;
        };

        -- Shadow
        local nShadowX          = tonumber(val("ShadowX"));
        local nShadowY          = tonumber(val("ShadowY"));
        local nShadowColor      = Color.TryFromString(val("ShadowColor"), true) or _oClear;
        local bShadowEnabled    = toboolean(val("ShadowEnabled")) and true or false;

        -- 3D
        local nD3Color          = Color.TryFromString(val("3DColor"), true) or _oClear;
        local nD3Depth          = tonumber(val("3DDepth"));
        local nD3StepX          = tonumber(val("3DStepX"));
        local nD3StepY          = tonumber(val("3DStepY"));
        local b3DEnabled        = toboolean(val("3DEnabled")) and true or false;

        -- (Optional) Glow (if you later add these keys)
        local nGlowColor            = Color.TryFromString(val("GlowColor"),         true) or _oClear;
        local nGlowOuterColor       = Color.TryFromString(val("GlowOuterColor"),    true) or _oClear;
        local nGlowRadius           = tonumber(val("GlowRadius"));
        local nGlowAlphaMax         = tonumber(val("GlowAlphaMax"));
        local bGlowEnabled          = toboolean(val("GlowEnabled")) and true or false
        bGlowEnabled                = isnumber(nGlowRadius) and isnumber(nGlowAlphaMax) and bGlowEnabled;
        local bGlowGradientEnabled  = bGlowEnabled and nGlowOuterColor ~= _oClear;

        -- Outline
        local nOutlineThickness  = tonumber(val("OutlineThickness"));
        local nOutlineColor      = Color.TryFromString(val("OutlineColor"), true) or _oClear;
        local bOutlineEnabled    = toboolean(val("OutlineEnabled")) and true or false;

        tRet = {
            Name                = sSectionName,

            FontFamily          = sFontFamily,
            FontSize            = nFontSize,
            FontColor           = nFontColor,
            FontOptions         = tFontOptions,

            ShadowEnabled       = isnumber(nShadowX) and isnumber(nShadowY) and bShadowEnabled,
            ShadowX             = floor(nShadowX    or 0),
            ShadowY             = floor(nShadowY    or 0),
            ShadowColor         = nShadowColor,

            D3Enabled           = isnumber(nD3Depth) and isnumber(nD3StepX) and isnumber(nD3StepY) and b3DEnabled,
            D3Color             = nD3Color,
            D3Depth             = floor(nD3Depth    or 0),
            D3StepX             = floor(nD3StepX    or 0),
            D3StepY             = floor(nD3StepY    or 0),

            GlowEnabled         = bGlowEnabled,
            GlowGradientEnabled = bGlowGradientEnabled,
            GlowColor           = nGlowColor,
            GlowOuterColor      = nGlowOuterColor,
            GlowRadius          = floor(nGlowRadius       or 0),
            GlowAlphaMax        = floor(nGlowAlphaMax     or 0),

            OutlineEnabled       = isnumber(nOutlineThickness) and bOutlineEnabled,
            OutlineThickness     = floor(nOutlineThickness or 0),
            OutlineColor         = nOutlineColor,

            INI                 = pINI,
        };

    end

    return tRet;
end

local FontStyle;

--A helper class for Forge.lua...only used by that class and, as such, it's private static in Forge.
return class("FontStyle",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --static constructor (runs after class object creation)
        FontStyle = function(cFontStyle, sAuthCode)
            FontStyle = cFontStyle; --since this is a private, helper class, it can't see itself without this fix.
        end,
        FromINI = function(pINI, sName)
            --TODO assertions

            local tVars = ParseFontStyleINI(pINI, sName);

            --return the FontStyle
            return FontStyle(   tVars.Name, tVars.INI,
                                tVars.FontFamily, tVars.FontSize, tVars.FontColor, tVars.FontOptions,
                                tVars.ShadowX, tVars.ShadowY, tVars.ShadowColor,
                                tVars.OutlineThickness, tVars.OutlineColor,
                                tVars.D3Depth, tVars.D3StepX, tVars.D3StepY, tVars.D3Color,
                                tVars.GlowRadius, tVars.GlowAlphaMax, tVars.GlowColor, tVars.GlowOuterColor);
        end,
    },
    {--PRIVATE
        --basic items
        Name__AUTOR_                = null,
        INI__AUTOA_                 = null,
        --font
        Font__AUTOA_                = null,
        Color                       = null,
        --shadow
        ShadowEnabled__AUTOA_       = false,
        ShadowColor__AUTOA_         = null,
        ShadowX__AUTOA_             = 0,
        ShadowY__AUTOA_             = 0,
        --3D
        D3Enabled                   = false, --THESE cannot be AUTO since the variable name is odd here
        D3Color                     = null, --TODO return these colors by copying them? Do I need to? Aren't they just numbers?
        D3Depth                     = 0,
        D3StepX                     = 0,
        D3StepY                     = 0,
        --GLOW/Gradient
        GlowEnabled__AUTOA_         = false,
        GlowGradientEnabled__AUTOA_ = false,
        GlowColor                   = null,
        GlowRadius__AUTOA_          = 0,
        GlowAlphaMax__AUTOA_        = 0,
        --outline
        OutlineEnabled__AUTOA_      = false,
        OutlineColor__AUTOA_        = null,
        OutlineThickness__AUTOA_    = 0,


        Draw3D = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, nAngle)
            local pri = cdat.pri;
            local nDepth = pri.D3Depth;  -- tweak: how “thick” the 3D is
            local nStepX = pri.D3StepX;  -- tweak: direction (x)
            local nStepY = pri.D3StepY;  -- tweak: direction (y)
            local nColor = pri.D3Color;

            -- use shadow color as the extrusion color (looks natural)
            local nER = Color.GetRed(pri.D3Color);
            local nEG = Color.GetGreen(pri.D3Color);
            local nEB = Color.GetBlue(pri.D3Color);

            -- farthest layer darkest; near layer lighter (simple falloff)
            for nI = nDepth, 1, -1 do
                local nAlpha = clamp(20 + (nI * 12), 0, 255); -- tweak
                local o3DCol = Color.RGBA(nER, nEG, nEB, nAlpha);

                D.DrawText(
                    floor(nX + (nI * nStepX)),
                    floor(nY + (nI * nStepY)),
                    sText,
                    o3DCol
                );
            end

        end,


        DrawOutline = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, nAngle)
            local pri            = cdat.pri;
            local nThickness     = pri.OutlineThickness;
            local nOutlineColor  = pri.OutlineColor;

            if not (isnumber(nThickness) and nThickness > 0) then
                return;
            end

            local nBaseX     = floor(nX);
            local nBaseY     = floor(nY);
            local nRadius    = floor(nThickness);
            local nRadius2   = nRadius * nRadius;

            -- draw text at every offset within the radius (fills holes)
            for nDY = -nRadius, nRadius do

                for nDX = -nRadius, nRadius do
                    local nD2 = (nDX * nDX) + (nDY * nDY);

                    if (nD2 > 0 and nD2 <= nRadius2) then

                        if (nAngle) then
                            D.DrawAngledText(nBaseX + nDX, nBaseY + nDY, sText, nAngle, nOutlineColor);
                        else
                            D.DrawText(nBaseX + nDX, nBaseY + nDY, sText, nOutlineColor);
                        end

                    end

                end

            end

        end,

        -- GLOW (centered on the text, even in all directions, opaque near text -> fades outward)
        -- GLOW (filled falloff, centered, fades out)
        DrawGlow = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, nAngle)
            local pri = cdat.pri;
            local nBaseX = floor(nX);
            local nBaseY = floor(nY);

            local nGlowRadius   = 16;  -- tweak
            local nGlowAlphaMax = 25;  -- tweak (keep LOW; this accumulates fast)
            local oGlowBase     = pri.GlowColor; -- dedicated glow color

            local nGR = Color.GetRed(oGlowBase);
            local nGG = Color.GetGreen(oGlowBase);
            local nGB = Color.GetBlue(oGlowBase);

            local nStep = 2; -- tweak: 1 = heavier/softer, 2 = faster

            for nDY = -nGlowRadius, nGlowRadius, nStep do

                for nDX = -nGlowRadius, nGlowRadius, nStep do
                    local nD2 = (nDX * nDX) + (nDY * nDY);

                    if (nD2 > 0 and nD2 <= (nGlowRadius * nGlowRadius)) then
                        local nDist = math.sqrt(nD2);
                        local nT    = 1 - (nDist / nGlowRadius);      -- 1 near text -> 0 at edge
                        local nA    = clamp(floor(nGlowAlphaMax * (nT * nT)), 0, 255);

                        if (nA > 0) then

                            if (nAngle) then
                                D.DrawAngledText(nBaseX + nDX, nBaseY + nDY, sText, nAngle, Color.RGBA(nGR, nGG, nGB, nA));
                            else
                                D.DrawText(nBaseX + nDX, nBaseY + nDY, sText, Color.RGBA(nGR, nGG, nGB, nA));
                            end

                        end

                    end

                end

            end

        end,

        DrawGlowGradient = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, nAngle)
            local pri = cdat.pri;
            local nBaseX = floor(nX);
            local nBaseY = floor(nY);

            local nGlowRadius   = 17;  -- size
            local nAlphaMax     = 110; -- opacity near text
            local nStep         = 2;   -- 1 smoother, 2 faster

            local oInner = pri.GlowInnerColor; -- color near text
            local oOuter = pri.GlowOuterColor; -- color at edge

            local nIR = Color.GetRed(oInner);
            local nIG = Color.GetGreen(oInner);
            local nIB = Color.GetBlue(oInner);

            local nOR = Color.GetRed(oOuter);
            local nOG = Color.GetGreen(oOuter);
            local nOB = Color.GetBlue(oOuter);

            local nRadius2 = nGlowRadius * nGlowRadius;

            for nDY = -nGlowRadius, nGlowRadius, nStep do

                for nDX = -nGlowRadius, nGlowRadius, nStep do
                    local nDist2 = (nDX * nDX) + (nDY * nDY);

                    if (nDist2 > 0 and nDist2 <= nRadius2) then
                        local nDist = math.sqrt(nDist2);

                        -- t = 0 at text, 1 at edge
                        local nT = nDist / nGlowRadius;

                        -- COLOR gradient (linear)
                        local nRed   = floor((nIR * (1 - nT)) + (nOR * nT));
                        local nGreen = floor((nIG * (1 - nT)) + (nOG * nT));
                        local nBlue  = floor((nIB * (1 - nT)) + (nOB * nT));

                        -- ALPHA falloff (strong near text -> 0 at edge)
                        local nA = clamp(floor(nAlphaMax * ((1 - nT) * (1 - nT))), 0, 255);

                        if (nA > 0) then

                            if (nAngle) then
                                D.DrawAngledText(nBaseX + nDX, nBaseY + nDY, sText, nAngle, Color.RGBA(nRed, nGreen, nBlue, nA));
                            else
                                D.DrawText(nBaseX + nDX, nBaseY + nDY, sText, Color.RGBA(nRed, nGreen, nBlue, nA));
                            end

                        end

                    end

                end

            end

        end,

        DrawShadow = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, nAngle)
            local pri = cdat.pri;
            local nBaseX = floor(nX + pri.ShadowX);
            local nBaseY = floor(nY + pri.ShadowY);

            local nSR = Color.GetRed(pri.ShadowColor);
            local nSG = Color.GetGreen(pri.ShadowColor);
            local nSB = Color.GetBlue(pri.ShadowColor);

            local nRadius     = 2;   -- tweak TODO FINISH ALLOW AS OPTION in INI
            local nShadowAlpha= Color.GetAlpha(pri.ShadowColor);

            local oBlurCol = Color.RGBA(nSR, nSG, nSB, clamp(nShadowAlpha, 0, 255));

            for nDY = -nRadius, nRadius do

                for nDX = -nRadius, nRadius do

                    if ((nDX * nDX) + (nDY * nDY)) <= (nRadius * nRadius) then

                        if (nAngle) then
                            D.DrawAngledText(nBaseX + nDX, nBaseY + nDY, sText, nAngle, oBlurCol);
                        else
                            D.DrawText(nBaseX + nDX, nBaseY + nDY, sText, oBlurCol);
                        end

                    end

                end

            end

        end,
    },
    {--PROTECTED

    },
    {--PUBLIC
        FontStyle = function(   this, cdat, sName, pINI, sFontFamily, nFontSize, vColor, vFontOptions,
                                            nShadowX, nShadowY, vShadowColor, vShadowEndColor,
                                            vOutlineThickness, vOutlineColor,
                                            vD3Depth, vD3StepX, vD3StepY, vD3Color,
                                            vGlowRadius, vGlowAlphaMax, vGlowColor, vGlowOuterColor)
            local pri = cdat.pri;
            --TODO assertions

            pri.Name            = sName;
            pri.INI             = pINI; --assert

            --shadow
            local bShadowXIsValid   = rawtype(nShadowX) == "number";
            local bShadowYIsValid   = rawtype(nShadowY) == "number";
            pri.ShadowEnabled   = bShadowXIsValid   and bShadowYIsValid;
            pri.ShadowColor     = vShadowColor      or  _oClear; --TODO CHECK COLOR TYPE THEN SET
            pri.ShadowX         = bShadowXIsValid   and floor(nShadowX) or 0;
            pri.ShadowY         = bShadowYIsValid   and floor(nShadowY) or 0;

            --3D
            local b3DDepthIsValid   = rawtype(vD3Depth) == "number";
            local b3DStepXIsValid   = rawtype(vD3StepX) == "number";
            local b3DStepYIsValid   = rawtype(vD3StepY) == "number";
            pri.D3Enabled           = b3DDepthIsValid and b3DStepXIsValid and b3DStepYIsValid;
            pri.D3Depth             = b3DDepthIsValid and floor(vD3Depth) or 0;
            pri.D3StepX             = b3DStepXIsValid and floor(vD3StepX) or 0;
            pri.D3StepY             = b3DStepYIsValid and floor(vD3StepY) or 0;
            pri.D3Color             = vD3Color or _oClear;--TODO CHECK COLOR TYPE THEN SET

            --glow TODO FINISH

            --outline
            local bOutlineIsValid    = rawtype(vOutlineThickness) == "number" and (vOutlineThickness >= 1);
            pri.OutlineEnabled   = bOutlineIsValid;
            pri.OutlineColor     = vOutlineColor      or  _oClear; --TODO CHECK COLOR TYPE THEN SET
            pri.OutlineThickness = bOutlineIsValid    and floor(vOutlineThickness) or 0;



            --create the font
            local tFontOptions = type(vFontOptions) == "table" and clone(vFontOptions) or {};
            pri.Color           = vColor; --TODO CHECK COLOR TYPE THEN SET
            pri.Font = DrawingFont.Load(sFontFamily, nFontSize, {
                Bold        = tFontOptions.Bold,
                Italic      = tFontOptions.Italic,
                Underline   = tFontOptions.Underline,
                StrikeOut   = tFontOptions.StrikeOut,
                HQ          = tFontOptions.HQ
            });

            --TODO CHECK FONT

        end,
        --ONLY called by forge
        Draw = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, vAngle)
            local pri       = cdat.pri;
            local nAngle    = isnumber(vAngle) and floor(clamp(vAngle, 0, 360)) or nil;

            -- HARD RULE: never rely on Prep() for draw state
            D.SetDrawingFont(pri.Font);
            D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);

            if (pri.ShadowEnabled) then
                pri.DrawShadow(sObject, D, hInternalDC, nX, nY, sText, nAngle);
            end

            if (pri.D3Enabled) then
                pri.Draw3D(sObject, D, hInternalDC, nX, nY, sText, nAngle);
            end

            if (pri.OutlineEnabled) then
                pri.DrawOutline(sObject, D, hInternalDC, nX, nY, sText, nAngle);
            end

            if (nAngle) then
                D.DrawAngledText(nX, nY, sText, nAngle, pri.Color);
            else
                D.DrawText(nX, nY, sText, pri.Color);
            end
        end,

        DrawOLD = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, vAngle)
            local pri       = cdat.pri;
            local nAngle    = isnumber(vAngle) and floor(clamp(vAngle, 0, 360)) or nil;

            if (pri.ShadowEnabled) then --draw the shadow
                pri.DrawShadow(sObject, D, hInternalDC, nX, nY, sText, nAngle);
            end

            if (pri.D3Enabled) then --draw 3D
                pri.Draw3D(sObject, D, hInternalDC, nX, nY, sText, nAngle);
            end
--[[
            if (pri.GlowEnabled) then --draw glow
                pri.DrawGlow(nX, nY, sText, sObject, D, hInternalDC);
            elseif (pri.GlowGradientEnabled) then --draw gradient glow
                pri.DrawGlowGradient(nX, nY, sText, sObject, D, hInternalDC);
            end
]]
            if (pri.OutlineEnabled) then --draw the border
                pri.DrawOutline(sObject, D, hInternalDC, nX, nY, sText, nAngle);
            end

            --draw the text
            if (nAngle) then
                D.DrawAngledText(nX, nY, sText, nAngle, pri.Color);
            else
                D.DrawText(nX, nY, sText, pri.Color);
            end

        end,

        Get3DEnabled = function(this, cdat)
            return cdat.pri.D3Enabled;
        end,
        Get3DDepth = function(this, cdat)
            return cdat.pri.D3Depth;
        end,
        Get3DStepX = function(this, cdat)
            return cdat.pri.D3StepX;
        end,
        Get3DStepY = function(this, cdat)
            return cdat.pri.D3StepY;
        end,

        Prep = function(this, cdat, D, sText, bSkipSetFont)
            local pri = cdat.pri;

             --set the font and filtering mode(s)
            if not (bSkipSetFont) then
                D.SetDrawingFont(pri.Font);
                D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
            end

            local nTextWidth  = D.GetTextWidth(sText);
            local nTextHeight = D.GetTextHeight(sText);

            local nMinX, nMinY, nTotalW, nTotalH =
                GetEffectBounds(    nTextWidth, nTextHeight,
                                    pri.ShadowEnabled, pri.ShadowX, pri.ShadowY,
                                    pri.D3Enabled, pri.D3StepX, pri.D3StepY, pri.D3Depth);

            return  nTotalW, nTotalH, nMinX, nMinY;
        end,
        PrepTEST = function(this, cdat, D, sText, bSkipSetFont)
            local pri = cdat.pri;

            --set the font and filtering mode(s)
            if not (bSkipSetFont) then
                D.SetDrawingFont(pri.Font);
                D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
            end

            local nTextWidth  = D.GetTextWidth(sText);
            local nTextHeight = D.GetTextHeight(sText);

            -- IMPORTANT: these must match your actual draw implementations
            local nShadowBlurRadius = pri.ShadowEnabled and 2 or 0; -- DrawShadow uses local nRadius = 2
            local nOutlineThickness = (pri.OutlineEnabled and pri.OutlineThickness) or 0;

            -- small AA/overhang safety so glyphs like "D" don't get clipped by tight bounds
            local nFudgeX = 2;
            local nFudgeY = 1;

            local nMinX, nMinY, nTotalW, nTotalH =
                GetEffectBounds(
                    nTextWidth, nTextHeight,
                    pri.ShadowEnabled, pri.ShadowX, pri.ShadowY, nShadowBlurRadius,
                    pri.D3Enabled, pri.D3StepX, pri.D3StepY, pri.D3Depth,
                    pri.OutlineEnabled, nOutlineThickness,
                    nFudgeX, nFudgeY
                );

            return nTotalW, nTotalH, nMinX, nMinY;
        end,

        SetINI = function(this, cdat)
            --TODO
            --type.istring(vINI)  and File.DoesExist(vINI) and
            --
        end,

        --LOCAL PARSER (assumes it exists in this same file; you said we’d build it)
        --local function ParseFontStyleINI(pINI, sSectionName)
        --    ... returns a table or nil ...
        --end
        Update = function(this, cdat)
            --TODO assertions
            local pri   = cdat.pri;
            local bRet  = false;
            local tParsed = ParseFontStyleINI(pri.INI, pri.Name);

            if (type(tParsed) == "table") then

                --font
                if (tParsed.FontFamily ~= nil) then
                    pri.Font = DrawingFont.Load(tParsed.FontFamily, tParsed.FontSize, {
                        Bold        = tParsed.FontOptions.Bold,
                        Italic      = tParsed.FontOptions.Italic,
                        Underline   = tParsed.FontOptions.Underline,
                        StrikeOut   = tParsed.FontOptions.StrikeOut,
                        HQ          = tParsed.FontOptions.HQ
                    });
                end

                if (tParsed.FontColor ~= nil) then
                    pri.Color = tParsed.FontColor;
                end

                --shadow / gradient shadow
                pri.ShadowX         = tParsed.ShadowX;
                pri.ShadowY         = tParsed.ShadowY;
                pri.ShadowColor     = tParsed.ShadowColor;
                pri.ShadowEnabled   = tParsed.ShadowEnabled;

                --3D
                pri.D3Enabled       = tParsed.D3Enabled;
                pri.D3Color         = tParsed.D3Color;
                pri.D3Depth         = tParsed.D3Depth;
                pri.D3StepX         = tParsed.D3StepX;
                pri.D3StepY         = tParsed.D3StepY;

                --Glow
                pri.GlowEnabled             = tParsed.GlowEnabled;
                pri.GlowGradientEnabled     = tParsed.GlowGradientEnabled;
                pri.GlowColor               = tParsed.GlowColor;
                pri.GlowRadius              = tParsed.GlowRadius;
                pri.GlowAlphaMax            = tParsed.GlowAlphaMax;

                --border
                pri.OutlineEnabled   = tParsed.OutlineEnabled;
                pri.OutlineThickness = tParsed.OutlineThickness;
                pri.OutlineColor     = tParsed.OutlineColor;

                bRet = true;
            end


            return bRet;
        end,
    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
