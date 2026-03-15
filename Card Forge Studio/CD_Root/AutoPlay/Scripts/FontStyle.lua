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
    local isstring      = type.isstring;
    local istable       = type.istable;
local Color         = Color;
local Drawing       = Drawing;
local DrawingFont   = DrawingFont;
local Ini           = Ini;
local ipairs        = ipairs;
local pairs         = pairs;
local table         = table;
local clone         = clone;
local io            = io;

local _oBlack       = Color.RGBA(0, 0, 0, 255);
local _oClear       = Color.RGBA(0, 0, 0, 0);

local _nTimerID             = FONTSTYLE_TIMER_ID;
local _nTimerInterval       = FONTSTYLE_TIMER_INTERVAL;
local _bTimerBusy           = false;
local _oLiveFileRepo        = nil;
local _bFontStylesChanged   = false;
local _oINI                 = nil;

local _tStyles          = {};
local _tStyleMeta       = {};
local _tParsedStyles    = {};

local FontStyle;

local function XPCallError(vErr)
    return debug.traceback(tostring(vErr), 2);
end

local function GetEffectBounds(nW, nH,
    bShadow, nShadowX, nShadowY,
    b3D, n3DStepX, n3DStepY, n3DDepth)

    local nMinX = 0;
    local nMaxX = nW;
    local nMinY = 0;
    local nMaxY = nH;

    local function ApplyDelta(nDX, nDY)
        local nX0 = nDX;
        local nX1 = nW + nDX;
        local nY0 = nDY;
        local nY1 = nH + nDY;

        nMinX = math.min(nMinX, nX0, nX1);
        nMaxX = math.max(nMaxX, nX0, nX1);
        nMinY = math.min(nMinY, nY0, nY1);
        nMaxY = math.max(nMaxY, nY0, nY1);
    end;

    if (bShadow) then
        ApplyDelta(floor(nShadowX or 0), floor(nShadowY or 0));
    end

    if (b3D) then
        local nDepth = floor(n3DDepth or 0);
        ApplyDelta(
            floor((n3DStepX or 0) * nDepth),
            floor((n3DStepY or 0) * nDepth)
        );
    end

    return nMinX, nMinY, nMaxX - nMinX, nMaxY - nMinY;
end

local function ReadStyleFile()
    local sRet = "";
    local hFile = nil;

    hFile = io.open(FS.Styles, "rb");

    if (hFile) then
        sRet = hFile:read("*a");
        hFile:close();
    end

    sRet = isstring(sRet) and sRet or "";
    return sRet;
end

local function BuildFontSignature(tParsed)
    local tFontOptions = istable(tParsed.FontOptions) and tParsed.FontOptions or {};
    local sRet = "";

    sRet = table.concat({
        tostring(tParsed.FontFamily),
        tostring(tParsed.FontSize),
        tostring(tFontOptions.Bold),
        tostring(tFontOptions.Italic),
        tostring(tFontOptions.Underline),
        tostring(tFontOptions.StrikeOut),
        tostring(tFontOptions.HQ),
    }, "\31");

    return sRet;
end

local function BuildEffectSignature(tParsed)
    local sRet = "";

    sRet = table.concat({
        tostring(tParsed.FontColor),

        tostring(tParsed.ShadowEnabled),
        tostring(tParsed.ShadowX),
        tostring(tParsed.ShadowY),
        tostring(tParsed.ShadowColor),

        tostring(tParsed.D3Enabled),
        tostring(tParsed.D3Depth),
        tostring(tParsed.D3StepX),
        tostring(tParsed.D3StepY),
        tostring(tParsed.D3Color),

        tostring(tParsed.GlowEnabled),
        tostring(tParsed.GlowGradientEnabled),
        tostring(tParsed.GlowColor),
        tostring(tParsed.GlowOuterColor),
        tostring(tParsed.GlowRadius),
        tostring(tParsed.GlowAlphaMax),

        tostring(tParsed.OutlineEnabled),
        tostring(tParsed.OutlineThickness),
        tostring(tParsed.OutlineColor),
    }, "\31");

    return sRet;
end

local function ParseFontStyleINI(sSectionName)
    local tRet = nil;
    local tValueNames = nil;

    if (_oINI and isstring(sSectionName) and not sSectionName:isempty()) then
        sSectionName = isstring(sSectionName) and sSectionName:upper() or "";
        tValueNames = _oINI.GetValueNames(sSectionName);

        if (istable(tValueNames) and #tValueNames > 0) then

            local function val(sValName)
                local sRet = "";
                local sVal = _oINI.GetValue(sSectionName, sValName, true);

                if (isstring(sVal)) then
                    sRet = sVal;
                end

                return sRet;
            end

            local sFontFamilyRaw    = val("Family");
            local sFontFamily       = isstring(sFontFamilyRaw) and sFontFamilyRaw:trimright() or "";
            local nFontSize         = floor(tonumber(val("Size")) or 12);
            local nFontColor        = Color.TryFromString(val("Color"), true) or _oBlack;

            local tFontOptions = {
                Bold        = toboolean(val("Bold"))      and true or false,
                Italic      = toboolean(val("Italic"))    and true or false,
                Underline   = toboolean(val("Underline")) and true or false,
                StrikeOut   = toboolean(val("StrikeOut")) and true or false,
                HQ          = toboolean(val("HQ"))        and true or false,
            };

            local nShadowX          = tonumber(val("ShadowX"));
            local nShadowY          = tonumber(val("ShadowY"));
            local nShadowColor      = Color.TryFromString(val("ShadowColor"), true) or _oClear;
            local bShadowEnabled    = toboolean(val("ShadowEnabled")) and true or false;

            local nD3Color          = Color.TryFromString(val("3DColor"), true) or _oClear;
            local nD3Depth          = tonumber(val("3DDepth"));
            local nD3StepX          = tonumber(val("3DStepX"));
            local nD3StepY          = tonumber(val("3DStepY"));
            local b3DEnabled        = toboolean(val("3DEnabled")) and true or false;

            local nGlowColor            = Color.TryFromString(val("GlowColor"), true) or _oClear;
            local nGlowOuterColor       = Color.TryFromString(val("GlowOuterColor"), true) or _oClear;
            local nGlowRadius           = tonumber(val("GlowRadius"));
            local nGlowAlphaMax         = tonumber(val("GlowAlphaMax"));
            local bGlowEnabled          = toboolean(val("GlowEnabled")) and true or false;
            local bGlowGradientEnabled  = false;

            local nOutlineThickness  = tonumber(val("OutlineThickness"));
            local nOutlineColor      = Color.TryFromString(val("OutlineColor"), true) or _oClear;
            local bOutlineEnabled    = toboolean(val("OutlineEnabled")) and true or false;

            sFontFamily = not (sFontFamily:isempty()) and sFontFamily or "Times New Roman";
            bGlowEnabled = isnumber(nGlowRadius) and isnumber(nGlowAlphaMax) and bGlowEnabled;
            bGlowGradientEnabled = bGlowEnabled and nGlowOuterColor ~= _oClear;

            tRet = {
                Name                = sSectionName,

                FontFamily          = sFontFamily,
                FontSize            = nFontSize,
                FontColor           = nFontColor,
                FontOptions         = tFontOptions,

                ShadowEnabled       = isnumber(nShadowX) and isnumber(nShadowY) and bShadowEnabled,
                ShadowX             = floor(nShadowX or 0),
                ShadowY             = floor(nShadowY or 0),
                ShadowColor         = nShadowColor,

                D3Enabled           = isnumber(nD3Depth) and isnumber(nD3StepX) and isnumber(nD3StepY) and b3DEnabled,
                D3Color             = nD3Color,
                D3Depth             = floor(nD3Depth or 0),
                D3StepX             = floor(nD3StepX or 0),
                D3StepY             = floor(nD3StepY or 0),

                GlowEnabled         = bGlowEnabled,
                GlowGradientEnabled = bGlowGradientEnabled,
                GlowColor           = nGlowColor,
                GlowOuterColor      = nGlowOuterColor,
                GlowRadius          = floor(nGlowRadius or 0),
                GlowAlphaMax        = floor(nGlowAlphaMax or 0),

                OutlineEnabled      = isnumber(nOutlineThickness) and bOutlineEnabled,
                OutlineThickness    = floor(nOutlineThickness or 0),
                OutlineColor        = nOutlineColor,
            };
        end

    end

    return tRet;
end

local function SyncStyles()
    local tSectionNames     = {};
    local tSeen             = {};
    local sName             = "";
    local tParsed           = nil;
    local sFontSig          = "";
    local sEffectSig        = "";
    local tMeta             = nil;
    local oStyle            = nil;
    local bFontChanged      = false;
    local bEffectChanged    = false;

    if (_oINI) then
        tSectionNames = _oINI.GetSectionNames();

        for _, sName in ipairs(tSectionNames) do
            sName = sName:upper();
            tSeen[sName] = true;
            tParsed = ParseFontStyleINI(sName);

            if (istable(tParsed)) then
                sFontSig   = BuildFontSignature(tParsed);
                sEffectSig = BuildEffectSignature(tParsed);
                tMeta      = _tStyleMeta[sName];
                oStyle     = _tStyles[sName];

                if not (oStyle) then
                    _tStyles[sName] = FontStyle(sName, tParsed);
                    _tStyleMeta[sName] = {
                        FontSig   = sFontSig,
                        EffectSig = sEffectSig,
                    };
                    _tParsedStyles[sName] = tParsed;
                else
                    bFontChanged   = not (tMeta) or tMeta.FontSig ~= sFontSig;
                    bEffectChanged = not (tMeta) or tMeta.EffectSig ~= sEffectSig;

                    if (bFontChanged or bEffectChanged) then
                        oStyle.ApplyParsed(tParsed, bFontChanged);
                        _tStyleMeta[sName] = {
                            FontSig   = sFontSig,
                            EffectSig = sEffectSig,
                        };
                        _tParsedStyles[sName] = tParsed;
                    end

                end

            end

        end

        for sName in pairs(_tStyles) do

            if not (tSeen[sName]) then
                _tStyles[sName] = nil;
                _tStyleMeta[sName] = nil;
                _tParsedStyles[sName] = nil;
            end

        end

    end

end

--TODO build style repair/update algorithm that brings old/malformed versions in the ini up to date with the current one.

return class("FontStyle",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        FontStyle = function(cFontStyle, sAuthCode)
            FontStyle = cFontStyle;
        end,

        --[[Reload = function()
            LoadAndSync();
        end,]]

        Get = function(sName)
            local oRet;

            if (isstring(sName) and not sName:isempty()) then
                oRet = _tStyles[sName:upper()];
            end

            return oRet;
        end,

        Has = function(sName)
            local bRet = false;

            if (isstring(sName) and not sName:isempty()) then
                bRet = _tStyles[sName:upper()] and true or false;
            end

            return bRet;
        end,

        GetNames = function()
            local tRet = {};
            local sName = "";

            for sName in pairs(_tStyles) do
                table.insert(tRet, sName);
            end

            table.sort(tRet);

            return tRet;
        end,

        UpdateINI = function(sINI)

            if (rawtype(sINI) == "string") then
                _oINI = Ini(sINI);
                SyncStyles();
            end

        end
    },
    {--PRIVATE
        Name__AUTOA_                = "",
        Font__AUTOA_                = 0,
        Color                       = _oBlack,

        ShadowEnabled__AUTOA_       = false,
        ShadowColor__AUTOA_         = _oClear,
        ShadowX__AUTOA_             = 0,
        ShadowY__AUTOA_             = 0,

        D3Enabled                   = false,
        D3Color                     = _oClear,
        D3Depth                     = 0,
        D3StepX                     = 0,
        D3StepY                     = 0,

        GlowEnabled__AUTOA_         = false,
        GlowGradientEnabled__AUTOA_ = false,
        GlowColor                   = _oClear,
        GlowOuterColor              = _oClear,
        GlowRadius__AUTOA_          = 0,
        GlowAlphaMax__AUTOA_        = 0,

        OutlineEnabled__AUTOA_      = false,
        OutlineColor__AUTOA_        = _oClear,
        OutlineThickness__AUTOA_    = 0,

        Draw3D = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, nAngle)
            local pri = cdat.pri;
            local nER = Color.GetRed(pri.D3Color);
            local nEG = Color.GetGreen(pri.D3Color);
            local nEB = Color.GetBlue(pri.D3Color);
            local nI = 0;
            local nAlpha = 0;
            local o3DCol = nil;

            for nI = pri.D3Depth, 1, -1 do
                nAlpha = clamp(20 + (nI * 12), 0, 255);
                o3DCol = Color.RGBA(nER, nEG, nEB, nAlpha);

                if (nAngle) then
                    D.DrawAngledText(
                        floor(nX + (nI * pri.D3StepX)),
                        floor(nY + (nI * pri.D3StepY)),
                        sText,
                        nAngle,
                        o3DCol
                    );
                else
                    D.DrawText(
                        floor(nX + (nI * pri.D3StepX)),
                        floor(nY + (nI * pri.D3StepY)),
                        sText,
                        o3DCol
                    );
                end

            end
        end,

        DrawOutline = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, nAngle)
            local pri = cdat.pri;
            local nBaseX = 0;
            local nBaseY = 0;
            local nRadius = 0;
            local nRadius2 = 0;
            local nDY = 0;
            local nDX = 0;
            local nD2 = 0;

            if not (isnumber(pri.OutlineThickness) and pri.OutlineThickness > 0) then
                return;
            end

            nBaseX = floor(nX);
            nBaseY = floor(nY);
            nRadius = floor(pri.OutlineThickness);
            nRadius2 = nRadius * nRadius;

            for nDY = -nRadius, nRadius do
                for nDX = -nRadius, nRadius do
                    nD2 = (nDX * nDX) + (nDY * nDY);

                    if (nD2 > 0 and nD2 <= nRadius2) then
                        if (nAngle) then
                            D.DrawAngledText(nBaseX + nDX, nBaseY + nDY, sText, nAngle, pri.OutlineColor);
                        else
                            D.DrawText(nBaseX + nDX, nBaseY + nDY, sText, pri.OutlineColor);
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
            local nRadius = 2;
            local nShadowAlpha = Color.GetAlpha(pri.ShadowColor);
            local oBlurCol = Color.RGBA(nSR, nSG, nSB, clamp(nShadowAlpha, 0, 255));
            local nDY = 0;
            local nDX = 0;

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
        FontStyle = function(this, cdat, sName, tParsed)
            local pri = cdat.pri;

            pri.Name = isstring(sName) and sName:upper() or "";

            if (istable(tParsed)) then
                this.ApplyParsed(tParsed, true);
            end
        end,

        ApplyParsed = function(this, cdat, tParsed, bRebuildFont)
            local pri = cdat.pri;
            local tFontOptions = {};
            local sFontFamily = "";
            local nFontSize = 12;

            if (istable(tParsed)) then
                tFontOptions = istable(tParsed.FontOptions) and clone(tParsed.FontOptions) or {};
                sFontFamily  = isstring(tParsed.FontFamily) and tParsed.FontFamily or "Times New Roman";
                nFontSize    = isnumber(tParsed.FontSize) and tParsed.FontSize or 12;

                if (bRebuildFont or not pri.Font) then
                    pri.Font = DrawingFont.Load(sFontFamily, nFontSize, {
                        Bold        = tFontOptions.Bold,
                        Italic      = tFontOptions.Italic,
                        Underline   = tFontOptions.Underline,
                        StrikeOut   = tFontOptions.StrikeOut,
                        HQ          = tFontOptions.HQ,
                    });
                end

                pri.Color               = tParsed.FontColor or _oBlack;

                pri.ShadowEnabled       = tParsed.ShadowEnabled and true or false;
                pri.ShadowX             = floor(tParsed.ShadowX or 0);
                pri.ShadowY             = floor(tParsed.ShadowY or 0);
                pri.ShadowColor         = tParsed.ShadowColor or _oClear;

                pri.D3Enabled           = tParsed.D3Enabled and true or false;
                pri.D3Depth             = floor(tParsed.D3Depth or 0);
                pri.D3StepX             = floor(tParsed.D3StepX or 0);
                pri.D3StepY             = floor(tParsed.D3StepY or 0);
                pri.D3Color             = tParsed.D3Color or _oClear;

                pri.GlowEnabled         = tParsed.GlowEnabled and true or false;
                pri.GlowGradientEnabled = tParsed.GlowGradientEnabled and true or false;
                pri.GlowColor           = tParsed.GlowColor or _oClear;
                pri.GlowOuterColor      = tParsed.GlowOuterColor or _oClear;
                pri.GlowRadius          = floor(tParsed.GlowRadius or 0);
                pri.GlowAlphaMax        = floor(tParsed.GlowAlphaMax or 0);

                pri.OutlineEnabled      = tParsed.OutlineEnabled and true or false;
                pri.OutlineThickness    = floor(tParsed.OutlineThickness or 0);
                pri.OutlineColor        = tParsed.OutlineColor or _oClear;
            end
        end,

        Update = function(this, cdat)
            local sName = cdat.pri.Name;
            local tParsed = nil;
            local sFontSig = "";
            local sEffectSig = "";
            local tMeta = nil;
            local bFontChanged = false;
            local bEffectChanged = false;
            local bRet = false;

            tParsed = ParseFontStyleINI(sName);

            if (istable(tParsed)) then
                sFontSig = BuildFontSignature(tParsed);
                sEffectSig = BuildEffectSignature(tParsed);
                tMeta = _tStyleMeta[sName];

                bFontChanged = not (tMeta) or tMeta.FontSig ~= sFontSig;
                bEffectChanged = not (tMeta) or tMeta.EffectSig ~= sEffectSig;

                if (bFontChanged or bEffectChanged) then
                    this.ApplyParsed(tParsed, bFontChanged);
                    _tStyleMeta[sName] = {
                        FontSig   = sFontSig,
                        EffectSig = sEffectSig,
                    };
                    _tParsedStyles[sName] = tParsed;
                    bRet = true;
                end

            end

            return bRet;
        end,

        Draw = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, vAngle)
            local pri = cdat.pri;
            local nAngle = isnumber(vAngle) and floor(clamp(vAngle, 0, 360)) or nil;

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

        Prep = function(this, cdat, D, sText, bSkipSetFont)
            local pri = cdat.pri;
            local nTextWidth = 0;
            local nTextHeight = 0;
            local nMinX = 0;
            local nMinY = 0;
            local nTotalW = 0;
            local nTotalH = 0;

            if not (bSkipSetFont) then
                D.SetDrawingFont(pri.Font);
                D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
            end

            nTextWidth = D.GetTextWidth(sText);
            nTextHeight = D.GetTextHeight(sText);

            nMinX, nMinY, nTotalW, nTotalH =
                GetEffectBounds(
                    nTextWidth, nTextHeight,
                    pri.ShadowEnabled, pri.ShadowX, pri.ShadowY,
                    pri.D3Enabled, pri.D3StepX, pri.D3StepY, pri.D3Depth
                );

            return nTotalW, nTotalH, nMinX, nMinY;
        end,
    },
    nil,
    false,
    nil
);
