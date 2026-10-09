local class         = class;
local math          = math;
    local clamp         = math.clamp;
    local floor         = math.floor;
local rawtype       = rawtype;
local string        = string;
local toboolean     = toboolean;
local tonumber      = tonumber;
local tostring      = tostring;
local type          = type;
    local isnumber      = type.isnumber;
    local isstring      = type.isstring;
    local istable       = type.istable;
local wx            = require("wx");
local INI           = require("Plugins.INI");
local Color         = {};
local DrawingFont   = {};

Color.RGBA = function(nR, nG, nB, nA) return (nR << 24) | (nG << 16) | (nB << 8) | nA end
Color.GetRed = function(oColor) return (oColor >> 24) & 255 end
Color.GetGreen = function(oColor) return (oColor >> 16) & 255 end
Color.GetBlue = function(oColor) return (oColor >> 8) & 255 end
Color.GetAlpha = function(oColor) return oColor & 255 end

function Color.TryFromString(sValue)
    if (rawtype(sValue) ~= "string") then return nil end

    local sText     = sValue:match("^%s*(.-)%s*$");
    local tChannels = {};

    if (sText:find(",", 1, true)) then
        for sChannel in sText:gmatch("[^,]+") do
            local nChannel = tonumber(sChannel);
            if (not nChannel or nChannel < 0 or nChannel > 255) then return nil end
            tChannels[#tChannels + 1] = nChannel;
        end

        if (#tChannels == 3 or #tChannels == 4) then
            return Color.RGBA(tChannels[1], tChannels[2], tChannels[3], tChannels[4] or 255);
        end
        return nil;
    end

    local sHex = sText:gsub("^#", "");

    if ((#sHex == 6 or #sHex == 8) and sHex:match("^%x+$")) then
        return Color.RGBA(tonumber(sHex:sub(1, 2), 16), tonumber(sHex:sub(3, 4), 16), tonumber(sHex:sub(5, 6), 16), #sHex == 8 and tonumber(sHex:sub(7, 8), 16) or 255);
    end

    return nil;
end

function DrawingFont.Load(sFamily, nSize, tOptions)
    local oFont = wx.wxFont(nSize, wx.wxFONTFAMILY_DEFAULT, tOptions.Italic and wx.wxFONTSTYLE_ITALIC or wx.wxFONTSTYLE_NORMAL, tOptions.Bold and wx.wxFONTWEIGHT_BOLD or wx.wxFONTWEIGHT_NORMAL, tOptions.Underline or false, sFamily);

    if (tOptions.StrikeOut) then
        oFont:SetStrikethrough(true);
    end

    return oFont;
end

local function Ini(pFile)
    local tSections = {};
    local tNames    = {};
    local oConfig   = wx.wxFileConfig("", "", pFile, "", wx.wxCONFIG_USE_LOCAL_FILE);
    oConfig:DisableAutoSave();
    oConfig:SetExpandEnvVars(false);
    local bOK, sError = xpcall(function()
        local bGroup, sSection, nGroup = oConfig:GetFirstGroup();
        while (bGroup) do
            tNames[#tNames + 1] = sSection;
            tSections[sSection] = {};
            oConfig:SetPath("/"..sSection);
            local bEntry, sKey, nEntry = oConfig:GetFirstEntry();
            while (bEntry) do
                local bFound, sValue = oConfig:Read(sKey, "");
                tSections[sSection][sKey] = bFound and sValue or "";
                bEntry, sKey, nEntry = oConfig:GetNextEntry(nEntry);
            end
            oConfig:SetPath("/");
            bGroup, sSection, nGroup = oConfig:GetNextGroup(nGroup);
        end
    end, debug.traceback);
    oConfig:delete();
    assert(bOK, sError);

    return {
        GetValue = function(sSection, sKey, bInherit)
            local tSeen = {};
            while (not tSeen[sSection]) do
                tSeen[sSection] = true;
                local sValue = tSections[sSection] and tSections[sSection][sKey] or "";
                local sReference = sValue:match("^%s*<%s*(.-)%s*>%s*$");
                if (not bInherit or not sReference) then return sValue end
                sSection = sReference;
            end
            return "";
        end,
        GetValueNames = function(sSection)
            local tKeys = {};
            for sKey in pairs(tSections[sSection] or {}) do tKeys[#tKeys + 1] = sKey; end
            table.sort(tKeys);
            return tKeys;
        end,
        GetSectionNames = function() return tNames end,
    };
end
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
    b3D, n3DStepX, n3DStepY, n3DDepth, bGlow, nGlowRadius)

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
    end

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

    if (bGlow) then
        local nRadius = math.max(0, floor(nGlowRadius or 0));
        ApplyDelta(-nRadius, -nRadius);
        ApplyDelta(nRadius, nRadius);
    end

    return nMinX, nMinY, nMaxX - nMinX, nMaxY - nMinY;
end

local function DrawTextRun(pri, D, nX, nY, sText, nAngle, nColor)
    if (pri.LetterSpacing == 0) then
        if (nAngle) then D.DrawAngledText(nX, nY, sText, nAngle, nColor);
        else D.DrawText(nX, nY, sText, nColor); end
        return;
    end
    local nOffset = 0;
    local nRadians = math.rad(nAngle or 0);
    for _, nCodePoint in utf8.codes(sText) do
        local sCharacter = utf8.char(nCodePoint);
        local nDrawX = nX + math.cos(nRadians) * nOffset;
        local nDrawY = nY - math.sin(nRadians) * nOffset;
        if (nAngle) then D.DrawAngledText(nDrawX, nDrawY, sCharacter, nAngle, nColor);
        else D.DrawText(nDrawX, nDrawY, sCharacter, nColor); end
        nOffset = nOffset + D.GetTextWidth(sCharacter) + pri.LetterSpacing;
    end
end

local function MeasureTextRun(pri, D, sText)
    if (pri.LetterSpacing == 0) then return D.GetTextWidth(sText); end
    local nWidth, nCount = 0, 0;
    for _, nCodePoint in utf8.codes(sText) do
        nWidth = nWidth + D.GetTextWidth(utf8.char(nCodePoint));
        nCount = nCount + 1;
    end
    return nWidth + math.max(0, nCount - 1) * pri.LetterSpacing;
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
        tostring(tParsed.LetterSpacing),
        tostring(tParsed.BackgroundEnabled),
        tostring(tParsed.BackgroundColor),
        tostring(tParsed.BackgroundPadding),
        tostring(tParsed.ShadowRadius),
        tostring(tParsed.ShadowSoftness),

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

local function ParseFontStyleINI(sSectionName, oReader)
    local oSource = oReader or _oINI;
    local tRet = nil;
    local tValueNames = nil;

    if (oSource and isstring(sSectionName) and not sSectionName:isempty()) then
        sSectionName = isstring(sSectionName) and sSectionName:upper() or "";
        tValueNames = oSource.GetValueNames(sSectionName);

        if (istable(tValueNames) and #tValueNames > 0) then

            local function val(sValName)
                local sRet = "";
                local sVal = oSource.GetValue(sSectionName, sValName, true);

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
                LetterSpacing       = tonumber(val("LetterSpacing")) or 0,
                BackgroundEnabled   = toboolean(val("BackgroundEnabled")) and true or false,
                BackgroundColor     = Color.TryFromString(val("BackgroundColor"), true) or _oClear,
                BackgroundPadding   = math.max(0, tonumber(val("BackgroundPadding")) or 0),
                ShadowRadius        = math.max(0, tonumber(val("ShadowRadius")) or 2),
                ShadowSoftness      = val("ShadowRadius") ~= "",

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




--create the STYLE constant
local tStyleProxy = {};
local tStyleProxyMeta = {
    __index = function(t, k)
        local sName = rawtype(k) == "string" and k or "";
        return not (sName:isempty()) and _tStyles[sName:upper()] or nil;
    end,

    __newindex = function(t, k, v)
        error("Styles is read-only.", 2);
    end,

    __metatable = "locked",
};

local tStyle = setmetatable(tStyleProxy, tStyleProxyMeta);
constant("STYLE", tStyle);

return class("FontStyle",
    {--METAMETHODS
        __call = function(this, cdat, self, sText)
            --TODO assertions
            local sName = cdat.pri.Name;
            return '<'..sName..'>'..sText..'</'..sName..'>'
        end,
    },
    {--STATIC PUBLIC
        --[[!
            @fqxn CFS.Classes.FontStyle.Methods.FontStyle
            @desc Initializes the FontStyle class reference for internal static use.
            @param class cFontStyle The FontStyle class.
            @param string sAuthCode An authorization code.
        !]]
        FontStyle = function(cFontStyle, sAuthCode)
            FontStyle = cFontStyle;
        end,

        --[[Reload = function()
            LoadAndSync();
        end,]]

        --[[!
            @fqxn CFS.Classes.FontStyle.Methods.Get
            @desc Gets a font style object by name.
            @param string sName The name of the font style to retrieve.
            @return FontStyle|nil oFontStyle The matching FontStyle object, or nil if not found.
        !]]
        Parse = function(sName, oReader)
            return ParseFontStyleINI(sName, oReader);
        end,

        Get = function(sName)
            local oRet;

            if (isstring(sName) and not sName:isempty()) then
                oRet = _tStyles[sName:upper()];
            end

            return oRet;
        end,


        --[[!
            @fqxn CFS.Classes.FontStyle.Methods.Has
            @desc Checks if a font style exists.
            @param string sName The name of the font style.
            @return boolean bHas True if the style exists; otherwise false.
        !]]
        Has = function(sName)
            local bRet = false;

            if (isstring(sName) and not sName:isempty()) then
                bRet = _tStyles[sName:upper()] and true or false;
            end

            return bRet;
        end,


        --[[!
            @fqxn CFS.Classes.FontStyle.Methods.GetNames
            @desc Gets all registered font style names.
            @return table tNames A sorted array of font style names.
        !]]
        GetNames = function()
            local tRet = {};
            local sName = "";

            for sName in pairs(_tStyles) do
                table.insert(tRet, sName);
            end

            table.sort(tRet);

            return tRet;
        end,


        --[[!
            @fqxn CFS.Classes.FontStyle.Methods.UpdateINI
            @desc Loads and synchronizes font styles from an INI file.
            @param string sINI The path to the INI file.
        !]]
        UpdateINI = function(sINI)

            if (rawtype(sINI) == "string") then
                _oINI = Ini(sINI);
                SyncStyles();
            end

        end
    },
    {--PRIVATE
        Name__AUTOA_                = "",
        Font__AUTOA_                = null,
        Color                       = _oBlack,
        LetterSpacing               = 0,
        BackgroundEnabled           = false,
        BackgroundColor             = _oClear,
        BackgroundPadding           = 0,
        ShadowRadius                = 2,
        ShadowSoftness              = false,

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

        DrawGlow = function(this, cdat, sObject, D, hInternalDC, nX, nY, sText, nAngle)
            local pri = cdat.pri;
            local nRadius = math.max(0, floor(pri.GlowRadius));
            local nAlphaMax = clamp(floor(pri.GlowAlphaMax), 0, 255);
            if (nRadius == 0 or nAlphaMax == 0) then return; end
            local nInner = pri.GlowColor;
            local nOuter = pri.GlowGradientEnabled and pri.GlowOuterColor or nInner;
            -- Sample translucent rings behind the glyphs. Outer rings fade out;
            -- per-sample opacity avoids making the overlapping passes opaque.
            for nDistance = nRadius, 1, -1 do
                local nMix = nDistance / nRadius;
                local function channel(fChannel)
                    return floor(fChannel(nInner) * (1 - nMix) + fChannel(nOuter) * nMix + 0.5);
                end
                local nSamples = math.min(32, math.max(8, math.ceil(2 * math.pi * nDistance)));
                local nAlpha = floor(nAlphaMax * (channel(Color.GetAlpha) / 255) * math.exp(-2 * nMix * nMix) / nSamples + 0.5);
                if (nAlpha > 0) then
                    local nColor = Color.RGBA(channel(Color.GetRed), channel(Color.GetGreen), channel(Color.GetBlue), nAlpha);
                    for nSample = 0, nSamples - 1 do
                        local nRadians = 2 * math.pi * nSample / nSamples;
                        local nDrawX = nX + math.cos(nRadians) * nDistance;
                        local nDrawY = nY + math.sin(nRadians) * nDistance;
                        if (nAngle) then
                            DrawTextRun(pri, D, nDrawX, nDrawY, sText, nAngle, nColor);
                        else
                            DrawTextRun(pri, D, nDrawX, nDrawY, sText, nil, nColor);
                        end
                    end
                end
            end
        end,

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

                DrawTextRun(pri, D, floor(nX + nI * pri.D3StepX), floor(nY + nI * pri.D3StepY), sText, nAngle, o3DCol);

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
                            DrawTextRun(pri, D, nBaseX + nDX, nBaseY + nDY, sText, nAngle, pri.OutlineColor);
                        else
                            DrawTextRun(pri, D, nBaseX + nDX, nBaseY + nDY, sText, nil, pri.OutlineColor);
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
            local nRadius = pri.ShadowRadius;
            local nShadowAlpha = Color.GetAlpha(pri.ShadowColor);
            local oBlurCol = Color.RGBA(nSR, nSG, nSB, clamp(nShadowAlpha, 0, 255));
            local nDY = 0;
            local nDX = 0;

            for nDY = -nRadius, nRadius do
                for nDX = -nRadius, nRadius do
                    if ((nDX * nDX) + (nDY * nDY)) <= (nRadius * nRadius) then
                        local nWeight = nRadius == 0 and 1 or math.exp(-2 * (nDX * nDX + nDY * nDY) / (nRadius * nRadius));
                        if (pri.ShadowSoftness) then
                            oBlurCol = Color.RGBA(nSR, nSG, nSB, floor(nShadowAlpha * nWeight / math.max(1, nRadius * nRadius)));
                        end
                        if (nAngle) then
                            DrawTextRun(pri, D, nBaseX + nDX, nBaseY + nDY, sText, nAngle, oBlurCol);
                        else
                            DrawTextRun(pri, D, nBaseX + nDX, nBaseY + nDY, sText, nil, oBlurCol);
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
                pri.LetterSpacing       = tParsed.LetterSpacing or 0;
                pri.BackgroundEnabled   = tParsed.BackgroundEnabled and true or false;
                pri.BackgroundColor     = tParsed.BackgroundColor or _oClear;
                pri.BackgroundPadding   = math.max(0, tParsed.BackgroundPadding or 0);
                pri.ShadowRadius        = math.max(0, floor(tParsed.ShadowRadius or 2));
                pri.ShadowSoftness      = tParsed.ShadowSoftness ~= false;

                pri.ShadowEnabled       = tParsed.ShadowEnabled and true or false;
                pri.ShadowX             = floor(tParsed.ShadowX or 0);
                pri.ShadowY             = floor(tParsed.ShadowY or 0);
                pri.ShadowColor         = tParsed.ShadowColor or _oClear;

                pri.D3Enabled           = tParsed.D3Enabled and true or false;
                pri.D3Depth             = floor(tParsed.D3Depth or 0);
                pri.D3StepX             = floor(tParsed.D3StepX or 0);
                pri.D3StepY             = floor(tParsed.D3StepY or 0);
                pri.D3Color             = tParsed.D3Color or _oClear;

                -- Glow is rendered before the other text effects.
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

            if (pri.BackgroundEnabled) then
                local nPadding = pri.BackgroundPadding;
                if (nAngle and D.DrawTextBackground) then
                    D.DrawTextBackground(nX, nY, MeasureTextRun(pri, D, sText), D.GetTextHeight(sText), nPadding, pri.BackgroundColor, nAngle);
                else
                    D.DrawRectangle(nX - nPadding, nY - nPadding,
                        MeasureTextRun(pri, D, sText) + 2 * nPadding, D.GetTextHeight(sText) + 2 * nPadding, pri.BackgroundColor);
                end
            end
            if (pri.GlowEnabled) then
                pri.DrawGlow(sObject, D, hInternalDC, nX, nY, sText, nAngle);
            end

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
                DrawTextRun(pri, D, nX, nY, sText, nAngle, pri.Color);
            else
                DrawTextRun(pri, D, nX, nY, sText, nil, pri.Color);
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

            nTextWidth = MeasureTextRun(pri, D, sText);
            nTextHeight = D.GetTextHeight(sText);

            nMinX, nMinY, nTotalW, nTotalH =
                GetEffectBounds(
                    nTextWidth, nTextHeight,
                    pri.ShadowEnabled, pri.ShadowX, pri.ShadowY,
                    pri.D3Enabled, pri.D3StepX, pri.D3StepY, pri.D3Depth,
                    pri.GlowEnabled, pri.GlowRadius
                );

            local nPadding = pri.BackgroundEnabled and pri.BackgroundPadding or 0;
            local nShadowRadius = pri.ShadowEnabled and pri.ShadowRadius or 0;
            local nOutlineRadius = pri.OutlineEnabled and pri.OutlineThickness or 0;
            local nExtra = math.max(nPadding, nShadowRadius, nOutlineRadius);
            nMinX, nMinY = nMinX - nExtra, nMinY - nExtra;
            nTotalW, nTotalH = nTotalW + 2 * nExtra, nTotalH + 2 * nExtra;
            return nTotalW, nTotalH, nMinX, nMinY;
        end,
    },
    nil,
    false,
    nil
);
