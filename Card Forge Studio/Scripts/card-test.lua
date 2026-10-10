--[[!
@fqxn CFS.Modules.card-test
@desc Development test harness; not a public application API.
@vis private
!]]

-- Standalone wxLua rendering experiment. All game inputs are read-only.
local _pScripts = assert(debug.getinfo(1, "S").source:match("^@(.+[/\\])"));
local _pRuntime = _pScripts.."../";
package.cpath = _pRuntime.."Bin/?.dll;"..package.cpath;

local _tWx = require("wx");
local _pGame = "C:/Users/CS/Sync/Projects/GitHub/Skystrike-Protocol/Source/Data/";
local _pSet = _pGame.."CardSets/d297ae9d-01e3-4268-92e6-6569aa484d8d/";
local _pStudio = _pRuntime.."CFS Archive/Scripts/";
local _nWidth, _nHeight = 825, 1125;
local _nImages, _nTexts = 0, 0;
local _tImages, _tStyles = {}, {};

local function readFile(pFile)
    local hFile = assert(io.open(pFile, "rb"));
    local sText = hFile:read("*a");
    hFile:close();

    return sText;
end

local function colour(sValue, oDefault)
    if (type(sValue) ~= "string" or sValue == "") then
        return oDefault or _tWx.wxColour(0, 0, 0, 0);
    end

    local tParts = {};

    for sPart in sValue:gmatch("%d+") do
        tParts[#tParts + 1] = tonumber(sPart);
    end

    if (#tParts >= 3 and sValue:find(",", 1, true)) then
        return _tWx.wxColour(tParts[1], tParts[2], tParts[3], tParts[4] or 255);
    end

    local sHex = sValue:gsub("#", "");
    assert(sHex:match("^%x%x%x%x%x%x$"), "Unsupported colour: "..sValue);

    return _tWx.wxColour(tonumber(sHex:sub(1, 2), 16), tonumber(sHex:sub(3, 4), 16), tonumber(sHex:sub(5, 6), 16));
end

local _tEnvironment = setmetatable({Color = {RGBA = _tWx.wxColour}}, {__index = _G});

local function import(pRelative)
    assert(not pRelative:find("..", 1, true), "Import must stay inside game data.");

    return assert(load(readFile(_pGame..pRelative), "@"..pRelative, "t", _tEnvironment))();
end

_tEnvironment.Import = import;
local _tCFG = import("Scripts/CFG.lua");
local _tCSV = assert(loadfile(_pStudio.."Plugins/FTCSV/ftcsv.lua"))();
local _tRows, _tHeaders = _tCSV.parse(_pSet.."Data.csv", ",");
local _tBase, _nRow;

for nRow, tRow in ipairs(_tRows) do
    if (tRow.Name == "AA AZR-9 Skywatch") then
        _tBase, _nRow = tRow, nRow;
        break;
    end
end

assert(_tBase, "Selected card not found.");
assert(_tBase.Description == "", "This first test requires an empty description.");

-- The real row processor is executed with a fixed random seed for repeatability.
-- Its LuaEx numeric-length truth test is adapted in memory, never on disk.
math.randomseed(12345);
local function randomFloat(nMin, nMax)
    return math.random(math.floor(nMin * 10000), math.floor(nMax * 10000)) / 10000;
end

local _tProcessEnvironment = setmetatable({
    CFG = _tCFG,
    _NUMBER = "number",
    max = math.max, min = math.min, floor = math.floor, ceil = math.ceil,
    rand = math.random, randf = randomFloat,
    clamp = function(nValue, nMin, nMax) return math.max(nMin, math.min(nMax, nValue)); end,
    driftf = function(nValue, nDrift) return nValue + nValue * randomFloat(-nDrift, nDrift); end,
    sum = function(...)
        local nTotal = 0;

        for _, nValue in ipairs({...}) do
            nTotal = nTotal + nValue;
        end

        return nTotal;
    end,
    RNG = {rollPercentage = function(nChance)
        nChance = type(nChance) == "number" and nChance > 0 and nChance <= 100 and math.ceil(nChance) or 50;

        return math.random(1, 100) <= nChance;
    end},
}, {__index = _G});

local _sProcessor, _nReplacements = readFile(_pSet.."RowProc.lua"):gsub("#%(tonumber%(tRow%.DriftOn%) or 0%)", "((tonumber(tRow.DriftOn) or 0) ~= 0)");
assert(_nReplacements == 1, "Row processor compatibility expression changed.");
local _fProcess = assert(load(_sProcessor, "@read-only RowProc.lua", "t", _tProcessEnvironment))();
local _tFinal, _tProcessing = {}, {};

local function getFinalValue(sColumn, sType)
    if (_tFinal[sColumn] == nil) then
        assert(not _tProcessing[sColumn], "Circular data dependency: "..sColumn);
        _tProcessing[sColumn] = true;
        local vValue = _fProcess(_nRow, 0, sColumn, _tBase, _tBase[sColumn], getFinalValue);
        _tFinal[sColumn] = vValue == nil and _tBase[sColumn] or vValue;
        _tProcessing[sColumn] = nil;
    end

    return sType == "number" and assert(tonumber(_tFinal[sColumn])) or _tFinal[sColumn];
end

for _, sColumn in ipairs(_tHeaders) do
    getFinalValue(sColumn);
end

-- Resolve the per-field style references used by the game's Styles.ini.
local sSection;

for sLine in readFile(_pGame.."Styles.ini"):gmatch("[^\r\n]+") do
    local sNewSection = sLine:match("^%[([^%]]+)%]$");

    if (sNewSection) then
        sSection = sNewSection;
        _tStyles[sSection] = {};
    elseif (sSection and not sLine:match("^%s*;")) then
        local sKey, sValue = sLine:match("^([^=]+)=(.*)$");

        if (sKey) then
            _tStyles[sSection][sKey] = sValue;
        end
    end
end

local function styleValue(sStyle, sKey, tSeen)
    tSeen = tSeen or {};
    local sToken = sStyle.."."..sKey;
    assert(not tSeen[sToken], "Circular style reference: "..sToken);
    tSeen[sToken] = true;
    local sValue = assert(_tStyles[sStyle], "Missing style: "..sStyle)[sKey] or "";
    local sReference = sValue:match("^<([^>]+)>$");

    return sReference and styleValue(sReference, sKey, tSeen) or sValue;
end

_tWx.wxInitAllImageHandlers();
local _oBitmap = _tWx.wxBitmap(_nWidth, _nHeight, 32);
local _oDC = _tWx.wxMemoryDC();
_oDC:SelectObject(_oBitmap);
_oDC:SetBackground(_tWx.wxBrush(_tWx.wxWHITE));
_oDC:Clear();
local _oGraphics = assert(_tWx.wxGraphicsContext.Create(_oDC));

local function drawImage(pImage, nX, nY, nWidth, nHeight)
    local oImage = _tImages[pImage];

    if (not oImage) then
        oImage = _tWx.wxImage(_pGame..pImage, _tWx.wxBITMAP_TYPE_PNG);
        assert(oImage:IsOk(), "Cannot load artwork: "..pImage);
        _tImages[pImage] = oImage;
    end

    _oGraphics:DrawBitmap(_tWx.wxBitmap(oImage), nX, nY, nWidth, nHeight);
    _nImages = _nImages + 1;
end

local function drawText(sStyle, nX, nY, vText, bCenterX, bCenterY, vAngle, fWrap, ...)
    assert(not vAngle, "Angled text is outside this initial test.");
    local sText = tostring(vText);
    local nSize = math.floor(tonumber(styleValue(sStyle, "Size")) or 12);
    local oFont = _tWx.wxFont(nSize, _tWx.wxFONTFAMILY_DEFAULT,
        styleValue(sStyle, "Italic") == "true" and _tWx.wxFONTSTYLE_ITALIC or _tWx.wxFONTSTYLE_NORMAL,
        styleValue(sStyle, "Bold") == "true" and _tWx.wxFONTWEIGHT_BOLD or _tWx.wxFONTWEIGHT_NORMAL,
        styleValue(sStyle, "Underline") == "true", styleValue(sStyle, "Family"));
    local oTextColour = colour(styleValue(sStyle, "Color"), _tWx.wxBLACK);
    _oGraphics:SetFont(oFont, oTextColour);
    local nTextWidth, nTextHeight = _oGraphics:GetTextExtent(sText);
    local tLines, nOffsetX, nOffsetY = {sText}, 0, 0;

    if (fWrap) then
        tLines, nOffsetX, nOffsetY = fWrap(nTextWidth, nTextHeight, sText, vAngle, ...);
    end

    local function paint(sLine, nAtX, nAtY, oColour)
        _oGraphics:SetFont(oFont, oColour);
        _oGraphics:DrawText(sLine, nAtX, nAtY);
    end

    for nLine, sLine in ipairs(tLines) do
        _oGraphics:SetFont(oFont, oTextColour);
        local nLineWidth = _oGraphics:GetTextExtent(sLine);
        local nAtX = nX + nOffsetX - (bCenterX and nLineWidth / 2 or 0);
        local nAtY = nY + nOffsetY + (nLine - 1) * nTextHeight - (bCenterY and nTextHeight / 2 or 0);

        if (styleValue(sStyle, "ShadowEnabled") == "true") then
            local oShadow = colour(styleValue(sStyle, "ShadowColor"));
            local nShadowX = tonumber(styleValue(sStyle, "ShadowX")) or 0;
            local nShadowY = tonumber(styleValue(sStyle, "ShadowY")) or 0;

            for nDY = -2, 2 do
                for nDX = -2, 2 do
                    if (nDX * nDX + nDY * nDY <= 4) then
                        paint(sLine, nAtX + nShadowX + nDX, nAtY + nShadowY + nDY, oShadow);
                    end
                end
            end
        end

        if (styleValue(sStyle, "3DEnabled") == "true") then
            local nDepth = tonumber(styleValue(sStyle, "3DDepth"));
            local nStepX = tonumber(styleValue(sStyle, "3DStepX"));
            local nStepY = tonumber(styleValue(sStyle, "3DStepY"));
            local oDepthColour = colour(styleValue(sStyle, "3DColor"));

            if (nDepth and nStepX and nStepY) then
                for nLayer = math.floor(nDepth), 1, -1 do
                    local oLayerColour = _tWx.wxColour(oDepthColour:Red(), oDepthColour:Green(), oDepthColour:Blue(), math.min(255, 20 + nLayer * 12));
                    paint(sLine, math.floor(nAtX + nLayer * nStepX), math.floor(nAtY + nLayer * nStepY), oLayerColour);
                end
            end
        end

        if (styleValue(sStyle, "OutlineEnabled") == "true") then
            local nRadius = math.floor(tonumber(styleValue(sStyle, "OutlineThickness")) or 0);
            local oOutline = colour(styleValue(sStyle, "OutlineColor"));

            for nDY = -nRadius, nRadius do
                for nDX = -nRadius, nRadius do
                    local nDistance = nDX * nDX + nDY * nDY;

                    if (nDistance > 0 and nDistance <= nRadius * nRadius) then
                        paint(sLine, nAtX + nDX, nAtY + nDY, oOutline);
                    end
                end
            end
        end

        paint(sLine, nAtX, nAtY, oTextColour);
    end

    _nTexts = _nTexts + 1;

    return nX, nY, nTextWidth, nTextHeight * #tLines;
end

local _tDrawEnvironment = setmetatable({
    _tRow = _tFinal, _nCardWidth = _nWidth, _nCardHeight = _nHeight, CFG = _tCFG,
    p = function() end,
    Forge = {DrawImage = drawImage, DrawText = drawText},
    ScaleStyle = function(sStyle, vValue, nMax)
        local nValue = tonumber(vValue);

        return nValue and nValue <= nMax and sStyle or sStyle.."SM";
    end,
}, {__index = _G});

local _sEnv = readFile(_pGame.."Scripts/ENV.lua");
local _sWrap = assert(_sEnv:match("^(.-)\n%-%-scales a numeric value"));
assert(load(_sWrap, "@read-only WrapName", "t", _tDrawEnvironment))();
local _sDraw, _nEmptyReplacement = readFile(_pSet.."Draw.lua"):gsub("tRow%.DeployCostX:isempty%(%)", '(tRow.DeployCostX == "")');
assert(_nEmptyReplacement == 1);
local _fDraw = assert(load(_sDraw, "@read-only Draw.lua", "t", _tDrawEnvironment))();
_fDraw("card-test", {
    GetOutputInfo = function() return {Width = _nWidth, Height = _nHeight}; end,
    DrawRectangle = function(nX, nY, nWidth, nHeight, oColour)
        _oGraphics:SetPen(_tWx.wxTRANSPARENT_PEN);
        _oGraphics:SetBrush(_tWx.wxBrush(oColour));
        _oGraphics:DrawRectangle(nX, nY, nWidth, nHeight);
    end,
});

_oGraphics:Flush();
_oGraphics:delete();
_oDC:SelectObject(_tWx.wxNullBitmap);
_oDC:delete();
local _oImage = _oBitmap:ConvertToImage();
assert(_oImage:IsOk() and _oImage:GetWidth() == _nWidth and _oImage:GetHeight() == _nHeight);
assert(_oImage:SaveFile(_pRuntime.."card-test.png", _tWx.wxBITMAP_TYPE_PNG));
print("Rendered ".._tFinal.Name..": ".._nImages.." image layers, ".._nTexts.." text fields; PNG saved.");

if (arg[1] ~= "--verify") then
    local oFrame = _tWx.wxFrame(_tWx.NULL, _tWx.wxID_ANY, "Skystrike Protocol - ".._tFinal.Name, _tWx.wxDefaultPosition, _tWx.wxSize(600, 840));
    local oPanel = _tWx.wxPanel(oFrame, _tWx.wxID_ANY);
    local nMargin = 8;
    local nMinimumHeight = 150;
    local nMinimumWidth = math.ceil(nMinimumHeight * _nWidth / _nHeight);
    local oPreview = _tWx.wxStaticBitmap(oPanel, _tWx.wxID_ANY, _oBitmap);
    local nLastWidth, nLastHeight = 0, 0;

    local function resizePreview()
        local oSize = oPanel:GetClientSize();
        local nAvailableWidth = math.max(1, oSize:GetWidth() - nMargin * 2);
        local nAvailableHeight = math.max(1, oSize:GetHeight() - nMargin * 2);
        local nScale = math.min(nAvailableWidth / _nWidth, nAvailableHeight / _nHeight);
        local nWidth = math.max(1, math.floor(_nWidth * nScale));
        local nHeight = math.max(1, math.floor(_nHeight * nScale));

        if (nWidth ~= nLastWidth or nHeight ~= nLastHeight) then
            oPreview:SetBitmap(_tWx.wxBitmap(_oImage:Scale(nWidth, nHeight, _tWx.wxIMAGE_QUALITY_HIGH)));
            nLastWidth, nLastHeight = nWidth, nHeight;
        end

        oPreview:SetSize(math.floor((oSize:GetWidth() - nWidth) / 2), math.floor((oSize:GetHeight() - nHeight) / 2), nWidth, nHeight);

        return nWidth, nHeight;
    end

    oPanel:Connect(_tWx.wxEVT_SIZE, function(oEvent)
        resizePreview();
        oEvent:Skip();
    end);
    oFrame:CreateStatusBar();
    oFrame:SetStatusText("Real game artwork/data; fixed test seed; wxLua renderer.");
    oFrame:SetMinClientSize(_tWx.wxSize(nMinimumWidth + nMargin * 2, nMinimumHeight + nMargin * 2 + oFrame:GetStatusBar():GetSize():GetHeight()));
    oFrame:Show(true);
    resizePreview();
    local oTimer;

    if (arg[1] == "--smoke") then
        oTimer = _tWx.wxTimer(oFrame);
        oFrame:Connect(_tWx.wxEVT_TIMER, function()
            for _, tSize in ipairs({{220, 240}, {800, 600}, {600, 1000}}) do
                oPanel:SetSize(tSize[1], tSize[2]);
                local nWidth, nHeight = resizePreview();
                assert(nWidth <= tSize[1] - nMargin * 2 and nHeight <= tSize[2] - nMargin * 2);
                assert(math.abs(nWidth / nHeight - _nWidth / _nHeight) < 0.01);
            end

            print("Preview resize checks passed: narrow, wide, and tall layouts.");
            oFrame:Close(true);
        end);
        oTimer:Start(250, true);
    end

    _tWx.wxGetApp():MainLoop();
end

-- Explicitly terminate the standalone test host after verification or window close.
os.exit(0);



