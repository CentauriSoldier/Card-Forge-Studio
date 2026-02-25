
--[[tUserEnv.S = {}; --TODO MOVE THIS TO FORGE!!!!
--local tStyles = INIFile.GetSectionNames(FS.Styles); --_TODO load this from forge, not from INI...too slow

--if (tStyles) then

    for _, sStyle in pairs(ProcSys.GetForge().STYLE) do
        tUserEnv.S[sStyle] = setmetatable(
        {
            O = '<'..sStyle..'>',
            C = '</'..sStyle..'>',
        },
        {
            __call = function(t, vText)
                return '<'..sStyle..'>'..tostring(vText)..'</'..sStyle..'>'
            end,
        }
        );
    end

--end]]

local class             = class;
local math              = math;
local rawtype           = rawtype;
local string            = string;
local toboolean         = toboolean;
local tonumber          = tonumber;
local tostring          = tostring;
local type              = type;
    isnumber            = type.isnumber;
    isstring            = type.istring;
local floor             = math.floor;
local clamp             = math.clamp;
local GetActiveCardSet  = ProcSys.GetActiveCardSet;
local SanitizePath      = SanitizePath;

local _pAppCFG      = FS.AppCFG;

local Color         = Color;
local Drawing       = Drawing;
local DrawingFont   = DrawingFont;
local INIFile       = INIFile;

local _nX                   = 0;
local _nY                   = 0;
local oWhite                = Color.RGBA(255, 255, 255, 255); --TODO Fix names!!! _
local _oBlack               = Color.RGBA(0, 0, 0, 255);
local _oClear               = Color.RGBA(0, 0, 0, 0)
local _nRulerColor          = Color.RGBA(240, 100, 100, 255); --TODO change these values from INI file
local _nRulerBGColor        = Color.RGBA(255, 255, 255, 0)
local _bForgeAutoSizing     = false;
local _nPageWidth           = -1;
local _nPageHeight          = -1;

local _hWndCardVer;  --TODO FIX REMOVE THIS

local _sCanvas = FORGE_CANVAS_NAME;

--redraw and file sync fields
local _tLastRow;
local _bRedrawRequested         = false;
local _bIsResizing              = false;
local _nTimeDelta               = 0;
local _nSizingDelta             = FORGE_REDRAW_SIZING_INTERVAL;
local _nRedrawTimerID           = FORGE_REDRAW_TIMER_ID;
local _nRedrawTimerInterval     = FORGE_REDRAW_TIMER_INTERVAL;

local _tHorRuler            = {--TODO static functions and variables io change these values
    Y           = 0,
    Width       = 825,
    MajorStep   = 100,
    MinorStep   = 25,
    MajorHeight = 16,
    MinorHeight = 10,
    Color       = _nRulerColor,
};
local _tVerRuler            = {--TODO static functions and variables io change these values
    X           = 0,
    HHeight     = 1125,
    MajorStep   = 100,
    MinorStep   = 25,
    MajorWidth  = 16,
    MinorWidth  = 10,
    Color       = _nRulerColor,
};
local _tCenterLines = {
    Color       = Color.RGBA(50, 50, 255, 255),
};

local function sink() end

--[[
local function IsCardVertical(tRow)
    local sIsVertical = tRow.IsVertical;
    local nIsVertical = sIsVertical and tonumber(sIsVertical) or 0;
    nIsVertical       = (nIsVertical == 0 or nIsVertical == 1) and nIsVertical or 0;
    return #nIsVertical;
end]]

--TODO FIX FINISH  make images for each card type as needed! modify code to reflect this change

--TODO remove magic numbers...put in gobals as original size of card and MOVE TO FORGE.lua

local FontStyle   = require("Forge.FontStyle");



--set during Draw, used in DrawText, etc.
local _Object       = null;
local _D            = null;
local _InternalDC   = null;
-----------------------------------------------
local _tStyle          = {};
local _bAutoUpdateStyle = false;
-----------------------------------------------
local _bCanvasCreated   = false;
local _nCanvasWidth     = 100;
local _nCanvasHeight    = 100;
-----------------------------------------------
local _hImage           = null;
local _nImageID         = null;
local _hImageExport     = null;
local _nImageExportID   = null;
local _hImageUtil       = null;
local _nImageUtilID     = null;
-----------------------------------------------
local _tImageCache      = {};
local _tUserImageCache  = {};
-----------------------------------------------
_oActiveCardSet = false;
_nCardWidth     = 100;
_nCardHeight    = 100;
_sCardSetName   = "";

--local Styles           = ""; --TODO FINISH STYLE NAMES MUST BE VARIABLE COMPLIANT




local function ImageLoadError(sPath, sName, sMsg)
    error("Error in Forge.LoadImage:\r\nError loading card image at path: \""..sPath.."\" with name, \""..sName.."\"."..#sName.."\r\n"..sMsg, 4);
end

local function LoadImage(sPath, sName)
    --TODO assertions
    if not (File.DoesExist(sPath)) then
        local sLastError = _tblErrorMessages[Application.GetLastError()];
        local sError = sLastError ~= "Success." and sLastError or "Image could not be found."
        ImageLoadError(sPath, sName or "UNKNOWN", sError);
    end

    if not (_tUserImageCache[sPath] and _tUserImageCache[sPath].Handle) then-- and _tUserImageCache[sPath].ID) then

        local hImage = DrawingImage.Load(sPath);

        _tUserImageCache[sPath] = {
            Handle = hImage,
        };

        if not (hImage) then
            ImageLoadError(sPath, sName, "Image could not be loaded with DrawingImage.Load().");
        end

        local nID = DrawingImage.GetID(hImage);

        if not (nID) then
            ImageLoadError(sPath, sName, "Image ID not retrieved DrawingImage.GetID().");
        end

        _tUserImageCache[sPath].ID = nID;
    end

    return _tUserImageCache[sPath].Handle, _tUserImageCache[sPath].ID;

end


local function CenterCardDisplay()
    local tPos  = Window.GetPos(HWND_APP);
    local tSize = Window.GetSize(HWND_APP);

    --get the size of the canvas
    local tSize = Input.GetSize(_sCanvas);
    Input.SetPos(_sCanvas, (_nPageWidth - tSize.Width) / 2, (_nPageHeight - tSize.Height) / 2);
end

local function ClearToTransparent(nW, nH, D)
    D.SetFilteringMode(DRAW_BLEND_ALLCHANNELS);
    D.DrawRectangle(0, 0, nW, nH, Color.RGBA(0, 0, 0, 0));
    D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
end

local function CreateImage(hImage, nImageID)
    local hRet          = hImage;
    local nRet          = nImageID;
    local sMessage;
    local sBaseError    = "Forge.CreateImage (private static): Could not";

    --create the image only if it's not already been created
    if (hImage == null and nImageID == null) then
        --create, check, and store the image handle
        hRet        = DrawingImage.New(_nCardWidth, _nCardHeight, BIT_DEPTH_32, DRAW_IMAGE_TRANSPARENT);
        sMessage    = sBaseError.." create image for canvas object, \"${canvas}\".";
        assert(hImage, sMessage % {game = sName, canvas = _sCanvas}); --TODO REMOVE THE NAME OR GET THE NAME FROM GAME

        --get, check, and store the image ID
        nRet        = DrawingImage.GetID(hImage);
        sMessage    = sBaseError.." get image ID for canvas object, \"${canvas}\".";
        assert(nImageID, sMessage % {game = sName, canvas = _sCanvas});
    end

    return hRet, nRet;
end

local function DrawCenterLineHor(sObject, D, hInternalDC)
    local nMidPointY = floor(nHeight / 2);
    D.DrawLineEx(0, nMidPointY, _nCardWidth, nMidPointY, _tCenterLines.Color);
end


local function DrawCenterLineVer(sObject, D, hInternalDC)
    local nMidPointX = floor(nWidth / 2);
    D.DrawLineEx(nMidPointX, 0, nMidPointX, _nCardHeight, _tCenterLines.Color);
end

local function DrawRulerHor(bDrawRulerVer, sObject, D, hInternalDC)
    local nY             = _tHorRuler.Y;
    local nMajorStep     = _tHorRuler.MajorStep;
    local nMinorStep     = _tHorRuler.MinorStep;
    local nMajorHeight   = _tHorRuler.MajorHeight;
    local nMinorHeight   = _tHorRuler.MinorHeight;
    local nTextY         = nMajorHeight + 3;--TODO remove magic number
    local oColor         = _tHorRuler.Color;
    --TODO FIX draw the first text of the hor ONLY if the veritcal is NOT drawing...same adjust ver

    local nXMax = _nCardWidth - 1;

    D.DrawLineEx(0, nY, nXMax, nY, oColor);

    for nX = 0, nXMax, nMinorStep do
        --draw the line
        local nHeight = (nX % nMajorStep == 0) and nMajorHeight or nMinorHeight;
        D.DrawLineEx(nX, nY, nX, nY + nHeight, oColor);

        --draw the position text
        if (nX > 0) then
            local sX = tostring(nX);
            local nTextWidth = D.GetTextWidth(sX);
            _tStyle.RULER.Draw(sObject, D, hInternalDC, floor(this.CenterOnX(nX, nTextWidth)), floor(nTextY), sX);
        end
    end

end

DrawRulerVer = function(bDrawRulerHor, sObject, D, hInternalDC)
    local nX             = _tVerRuler.X;
    local nMajorStep     = _tVerRuler.MajorStep;
    local nMinorStep     = _tVerRuler.MinorStep;
    local nMajorWidth    = _tVerRuler.MajorWidth;
    local nMinorWidth    = _tVerRuler.MinorWidth;
    local nTextX         = nMajorWidth + 3;
    local oColor         = _tVerRuler.Color;

    local nYMax = _nCardHeight - 1;

    D.DrawLineEx(nX, 0, nX, nYMax, oColor);
    D.SetDrawingFont(_tStyle.RULER.GetFont());--TODO FIX This must be gotten from the Forge

    for nY = 0, nYMax, nMinorStep do
        local nWidth        = (nY % nMajorStep == 0) and nMajorWidth or nMinorWidth;
        local nLineLength   = nX + nWidth;

        --draw the line
        D.DrawLineEx(nX, nY, nLineLength, nY, oColor);

        --draw the position text
        if (nY > 0) then
            local sY = tostring(nY);
            local nTextHeight = D.GetTextHeight(sY);
            _tStyle.RULER.Draw(sObject, D, hInternalDC, floor(nTextX), floor(this.CenterOnY(nY, nTextHeight)), sY);
        end

    end

end

DrawUtilObjects = function(sObject, D, hInternalDC)
    ClearToTransparent(_nCardWidth, _nCardHeight, D);

    --draw utility objects
    local bDrawRulerHor = MainMenu.IsChecked("Options:>Draw:>Horizontal Ruler Enabled");
    local bDrawRulerVer = MainMenu.IsChecked("Options:>Draw:>Vertical Ruler Enabled");

    D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);

    if (bDrawRulerHor) then
        DrawRulerHor(bDrawRulerVer, sObject, D, hInternalDC);
    end

    if (bDrawRulerVer) then
        DrawRulerVer(bDrawRulerHor, sObject, D, hInternalDC);
    end

    if (MainMenu.IsChecked("Options:>Draw:>Horizontal Centerline Enabled")) then
        DrawCenterLineHor(sObject, D, hInternalDC);
    end

    if (MainMenu.IsChecked("Options:>Draw:>Vertical Centerline Enabled")) then
        DrawCenterLineVer(sObject, D, hInternalDC);
    end

end






return class("Forge",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Forge = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        LoadImage = LoadImage,
        STYLE = _tStyle,

        DrawCard = function(tRow, nWidth, nHeight)--, bExport, fExport) --TODO move this out to private static to be used here and in new export function
            --in case a resize happens
            _tLastRow  = tRow;

            --draw the card
            local function ProcDraw(sObject, D, hInternalDC)
                ClearToTransparent(nWidth, nHeight, D);
                --get the proc's draw method
                --local fProcDraw         = cProc.DrawCard(this, cProc, tRow, nWidth, nHeight);
                local fSetOnImageDraw   = sink;
                local oCardSet          = ProcSys.GetActiveCardSet();

                if (type(oCardSet) == "CardSet") then --TODO MOVE THIS OUT TO ITS OWN PRIVATE FUNCTION
                    --get the chunk from the active card set
                    local sDrawChunk = oCardSet.GetCallCode("Draw");

                    --the error message in case things go south
                    local sCardSetName  = oCardSet.GetName();
                    local sChunkName    = sCardSetName.." Draw";

                    --update the Forge index in the user env
                    UserEnv.ForgeUpdateRoot {
                        _tRow            = tRow,
                        _bDrawBorder     = MainMenu.IsChecked("Options:>Draw:>Border Enabled"),
                        _bDrawOverlay    = MainMenu.IsChecked("Options:>Draw:>Overlay Enabled"),
                    };
                    local st=""
                    for k, v in pairs(UserEnv.GetCommandList()) do
                        st = st.."|"..v;
                    end

                    --p(st)

                    --wUser.pGame         = FS.Game;
                    --wUser.pCardSet      = oCardSet.GetPath();
                    --wUser.pSymbols      = FS.Symbols;
                    --wUser.pDocs         = FS.Docs;

                    --try to load the chuck
                    --p(type(sDrawChunk), type(sChunkName), type(wUser))
                    local fChunk, sError = load(sDrawChunk, sChunkName, "t", UserEnv.Get());
                    if not (fChunk) then
                        error("Error loading Draw file for CardSet "..sCardSetName..".\r\n"..sError, 2); --TODO LOG/display
                    end

                    --try to call the chunk
                    local bOk, vReturnOrError = pcall(fChunk);

                    if not (bOk) then --TODO are drafts gettging loaded back in? Are they even needed...?
                        p("ERror 539 - Forge: "..vReturnOrError)
                        --error(sChunkName..": "..tostring(vDescOrErr), 3); TODO LOG and display
                    end

                    fSetOnImageDraw = vReturnOrError;--(this, tRow, nWidth, nHeight);
                end
                --check it
                --assert(rawtype(fProcDraw) == "function", "Error Drawing Card, \""..tRow.Name.."\".\r\nMissing static DrawCard function in "..tostring(cProc).." class or function not correctly implemented."); --TODO FINISH

                --update private vars for use in DrawText and other functions
                _Object      = sObject;
                _D           = D;
                _InternalDC  = hInternalDC;

                --execute the proc's draw method
                fSetOnImageDraw(sObject, D, hInternalDC);
                --fProcDraw(sObject, D, hInternalDC)
            end

            --reset the image size to its original size
            --hImage:Resize(nWidth, nHeight, DRAW_RESIZE_RAW);

            --clear the canvas
            Canvas.Clear(_sCanvas, _oClear);

            --draw on the card image
            _hImage:Draw(ProcDraw);

            --draw on the util image
            _hUtilImage:Draw(DrawUtilObjects);

            --resize the image to the canvas size
            --local tSize = Input.GetSize(_sCanvas);
            --hImage:Resize(tSize.Width, tSize.Height, DRAW_RESIZE_RAW);

            --draw the card and util images onto the canvas (since drawing directly on the canvas is no bueno)
            Canvas.Draw(_sCanvas,
                        function(sObject, D, hInternalDC)
                            D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
                            D.DrawImage(_nImageID,      0, 0, _nCanvasWidth, _nCanvasHeight);
                            D.DrawImage(_nImageUtilID,  0, 0, _nCanvasWidth, _nCanvasHeight);
                        end
            );

            --if (bExport and fExport and type(fExport) == "function") then --TODO DO NOT CALL THIS HERE>..Teach export should not be displayed first
            --    fExport(D, hImage, cProc, tRow); --TODO FINISH PCALL this and send erros to status
            --end

            --[[
            --saves the entire canvas!
            local hNew = Canvas.GrabImage(_sCanvas);
            if(hNew)then
                DrawingImage.Save(hNew, tRow.Name..".png", DRAW_FORMAT_PNG);
                DrawingImage.Free(hNew);
            end]]
        end,
        DrawImage = function(this, cdat, pImage, nX, nY, nWidth, nHeight, sName)
            --TODO assertions
            local hImage, nImage = LoadImage(FS.Game.."\\"..SanitizePath(pImage), sName);
            D.SetFilteringMode(DRAW_BLEND_ALPHABLEND);
            D.DrawImage(nImage, nX, nY, nWidth, nHeight);
        end,
        --may be called ONLY in the proc's draw
        DrawText = function(this, cdat, sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, ...)
            --TODO assertions
            local eStyle        = _tStyle;

            local fWrap         = rawtype(vWrap)        == "function"   and vWrap       or false;
            local bCenterX      = rawtype(vCenterX)     == "boolean"    and vCenterX    or false;
            local bCenterY      = rawtype(vCenterY)     == "boolean"    and vCenterY    or false;
            local oStyle        = eStyle[sStyle] --TODO add default style as fallback???
            local tLines        = {}; --used for text wrapping
            local nStartOffsetX, nStartOffsetY = 0, 0;

            if (_bAutoUpdateStyle) then --update the style (if requested)
                oStyle.Update();
            end

            local nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(D, sText);

            if (fWrap) then
                tLines, nStartOffsetX, nStartOffsetY = fWrap(nTotalW, nTotalH, sText, vAngle, {...});
                ---TODO verify table
            else
                tLines[1] = sText;
            end

            local nLastX, nLastY, nLastWidth, nLastHeight;

            local bFirstLine, nBaseX, nBaseY, nTrueX, nTrueY, nLineYAdjuster;
            local nLinePadding  = 2; --TODO FINISH PUT IN PRI AND ALLOW MUTATE
            local nLineReturn   = nTotalH;
            local nHalfHeight   = nTotalH / 3;

            for nLine, sLine in ipairs(tLines) do
                nLineYAdjuster = nHalfHeight * (nLine - 1);
                bFirstLine = nLine == 1;

                nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(D, sLine, true);
                nBaseX = bCenterX and (nRawX - (nTotalW / 2) - nMinX) or nRawX;
                nBaseY = bCenterY and (nRawY - (nTotalH / 2) - nMinY) or nRawY;

                nTrueX = nBaseX + (bFirstLine and nStartOffsetX or 0);
                nTrueY = nBaseY + (bFirstLine and nStartOffsetY or 0) + nLineYAdjuster;

                nLastX      = nTrueX;
                nLastY      = nTrueY;
                nLastWidth  = nTotalW;
                nLastHeight = nTotalH;

                --draw the text
                --oStyle.Draw(sObject, D, hInternalDC, floor(nTrueX), floor(nTrueY), sLine, vAngle);
                oStyle.Draw(_Object, _D, _InternalDC, floor(nTrueX), floor(nTrueY), sLine, vAngle);
            end

            return nLastX, nLastY, nLastWidth, nLastHeight;
        end,
        DrawStyledText = function(this, cdat, sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, ...)--TODO BUG FIX USe HTML parser, not this
            local eStyle        = _tStyle;

            local fWrap         = rawtype(vWrap)        == "function"   and vWrap       or false;
            local bCenterX      = rawtype(vCenterX)     == "boolean"    and vCenterX    or false;
            local bCenterY      = rawtype(vCenterY)     == "boolean"    and vCenterY    or false;

            --------------------------------------------------------------------
            -- PARSE HELPERS
            --------------------------------------------------------------------
            local function BuildRuns(sIn)
                local tRuns  = {};
                local sPlain = "";

                local i = 1;
                local n = #sIn;

                while (i <= n) do
                    local a = sIn:find("<", i, true);

                    if not a then
                        local s = sIn:sub(i);
                        if (#s > 0) then
                            tRuns[#tRuns + 1] = { Style = sStyle, Text = s };
                            sPlain = sPlain .. s;
                        end
                        break;
                    end

                    if (a > i) then
                        local s = sIn:sub(i, a - 1);
                        tRuns[#tRuns + 1] = { Style = sStyle, Text = s };
                        sPlain = sPlain .. s;
                    end

                    local b = sIn:find(">", a + 1, true);
                    if not b then
                        local s = sIn:sub(a);
                        tRuns[#tRuns + 1] = { Style = sStyle, Text = s };
                        sPlain = sPlain .. s;
                        break;
                    end

                    local tag = sIn:sub(a + 1, b - 1):upper();
                    local close = "</" .. tag .. ">";
                    local c = sIn:find(close, b + 1, true);

                    if not c then
                        local s = sIn:sub(a);
                        tRuns[#tRuns + 1] = { Style = sStyle, Text = s };
                        sPlain = sPlain .. s;
                        break;
                    end

                    local inner = sIn:sub(b + 1, c - 1);
                    local use = eStyle[tag] and tag or sStyle;

                    tRuns[#tRuns + 1] = { Style = use, Text = inner };
                    sPlain = sPlain .. inner;

                    i = c + #close;
                end

                return tRuns, sPlain;
            end

            --------------------------------------------------------------------
            -- PARSE (runs + plain string)
            --------------------------------------------------------------------
            local tRunsSrc, sPlain = BuildRuns(sText);

            --------------------------------------------------------------------
            -- UPDATE STYLES (if requested)
            --------------------------------------------------------------------
            if (_bAutoUpdateStyle) then
                local oDef = eStyle[sStyle];
                if (oDef and oDef.Update) then
                    oDef.Update();
                end

                for _, r in ipairs(tRunsSrc) do
                    local o = eStyle[r.Style];
                    if (o and o.Update) then
                        o.Update();
                    end
                end
            end

            --------------------------------------------------------------------
            -- WRAP (wrapper contract is plain string)
            --------------------------------------------------------------------
            local tLines        = {};
            local nStartOffsetX = 0;
            local nStartOffsetY = 0;

            if (fWrap) then
                local oDef = eStyle[sStyle];
                local nW, nH = oDef.Prep(D, sPlain);
                tLines, nStartOffsetX, nStartOffsetY = fWrap(nW, nH, sPlain, vAngle, {...});
            else
                tLines[1] = sPlain;
            end

            --------------------------------------------------------------------
            -- BUILD PER-LINE SEGMENTS (preserves style runs across wrapped lines)
            --------------------------------------------------------------------
            local tLineSegs = {};
            do
                local nRun = 1;
                local nPos = 1;

                for iLine, sLine in ipairs(tLines) do
                    local tSegs = {};
                    local nRemain = #sLine;

                    while (nRemain > 0) do
                        local r = tRunsSrc[nRun];
                        if not r then
                            tSegs[#tSegs + 1] = { Style = sStyle, Text = sLine:sub(#sLine - nRemain + 1) };
                            break;
                        end

                        local sRunText = r.Text;
                        local nRunRemain = (#sRunText - nPos) + 1;

                        if (nRunRemain <= 0) then
                            nRun = nRun + 1;
                            nPos = 1;
                        else
                            local nTake = math.min(nRunRemain, nRemain);
                            local sPart = sRunText:sub(nPos, nPos + nTake - 1);

                            tSegs[#tSegs + 1] = { Style = r.Style, Text = sPart };

                            nPos = nPos + nTake;
                            nRemain = nRemain - nTake;

                            if (nPos > #sRunText) then
                                nRun = nRun + 1;
                                nPos = 1;
                            end
                        end
                    end

                    tLineSegs[iLine] = tSegs;
                end
            end

            --------------------------------------------------------------------
            -- MEASURE BLOCK (INK-BOX LAYOUT: neutralize negative bearings)
            --------------------------------------------------------------------
            local tLineInfo = {};
            local nBlockW   = 0;
            local nBlockH   = 0;

            local nPadX = 1; -- keep your safety pad

            for iLine, tSegs in ipairs(tLineSegs) do
                local nX = 0;

                local nLineMinX = 0;
                local nLineMaxX = 0;
                local nLineMinY = 0;
                local nLineMaxY = 0;

                for _, seg in ipairs(tSegs) do
                    local oStyle = eStyle[seg.Style] or eStyle[sStyle];
                    local sPart  = seg.Text;

                    -- ensure correct font set
                    oStyle.Prep(_D, sPart, false);

                    -- true ink bounds (includes your shadow/outline/etc via Prep)
                    local nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(_D, sPart, true);

                    -- LAYOUT RULE:
                    -- place ink-box start at nX (so negative nMinX can't backtrack into previous segment)
                    local nPartMinX = nX;
                    local nPartMaxX = nX + nTotalW;

                    local nPartMinY = nMinY;
                    local nPartMaxY = nMinY + nTotalH;

                    if (nLineMinX > nPartMinX) then nLineMinX = nPartMinX end
                    if (nLineMaxX < nPartMaxX) then nLineMaxX = nPartMaxX end
                    if (nLineMinY > nPartMinY) then nLineMinY = nPartMinY end
                    if (nLineMaxY < nPartMaxY) then nLineMaxY = nPartMaxY end

                    nX = nX + nTotalW + nPadX;
                end

                local nLineW = nLineMaxX - nLineMinX;
                local nLineH = nLineMaxY - nLineMinY;

                tLineInfo[iLine] = {
                    MinX = nLineMinX,
                    MinY = nLineMinY,
                    W    = nLineW,
                    H    = nLineH,
                };

                if (nBlockW < nLineW) then nBlockW = nLineW end
                nBlockH = nBlockH + nLineH;
            end

            --------------------------------------------------------------------
            -- BASE POSITION (top-left of the block)
            --------------------------------------------------------------------
            local nBaseX = bCenterX and (nRawX - (nBlockW / 2)) or nRawX;
            local nBaseY = bCenterY and (nRawY - (nBlockH / 2)) or nRawY;

            nBaseX = nBaseX + (nStartOffsetX or 0);
            nBaseY = nBaseY + (nStartOffsetY or 0);

            --------------------------------------------------------------------
            -- DRAW PASS (INK-BOX LAYOUT: drawX = penX - nMinX)
            --------------------------------------------------------------------
            local nY = nBaseY;

            for iLine, tSegs in ipairs(tLineSegs) do
                local tInfo = tLineInfo[iLine] or { MinX = 0, MinY = 0, H = 0 };

                local nX = nBaseX;                    -- pen x = ink-box start
                local nLineY = nY - (tInfo.MinY or 0); -- align to real top

                for _, seg in ipairs(tSegs) do
                    local oStyle = eStyle[seg.Style] or eStyle[sStyle];
                    local sPart  = seg.Text;

                    oStyle.Prep(_D, sPart, false);

                    local nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(_D, sPart, true);

                    -- KEY FIX:
                    -- draw so that the ink-box starts at nX (neutralizes negative bearings / kerning tuck)
                    local nDrawX = nX - (nMinX or 0);
                    local nDrawY = nLineY;

                    --TEST (keep it, but make it match the real ink-box)
                    --local R = math.random;
                    --D.DrawRectangle(floor(nX), floor(nY), floor(nTotalW), floor(nTotalH), Color.RGBA(R(1, 255),R(1, 255),R(1, 255),60));
                    --TEST

                    oStyle.Draw(_Object, _D, _InternalDC, floor(nDrawX), floor(nDrawY), sPart, vAngle);

                    nX = nX + nTotalW + nPadX;
                end

                nY = nY + (tInfo.H or 0);
            end

            return nBaseX, nBaseY, nBlockW, nBlockH;
        end,
        Init = function()
            --import the styles
            local pStyles = FS.Styles;
            --StylesINI = pStyles;

            --TODO check for file and other things...do error checsk later --THROW ERROR if not
            local tSections     = INIFile.GetSectionNames(pStyles);
            --local tNames        = {};
            local tStyles       = {};

            table.sort(tSections);

            for nIndex, sStyleRaw in ipairs(tSections) do
                local sStyle = sStyleRaw:upper();
                --store the style name
                --tNames[nIndex]  = sStyle:upper();
                --create the style
                --tStyles[nIndex] = FontStyle.FromINI(pStyles, sStyle);
                tStyles[sStyle] = FontStyle.FromINI(pStyles, sStyle);
                --run the initial update --TODO BUG fix the FontStyle so it does this upon and creation so it doesn't need done here
                tStyles[sStyle]:Update();
            end

            --create and store the STYLE table
            local sErrorPrefix = "Error assigning new FontStyle in Forge.STYLE: ";
            _tStyle = setmetatable({}, {
                __index = function(t, k)

                    if rawtype(k) == "string" then
                        return tStyles[k:upper()] or nil;
                    end

                end,
                __newindex = function(t, k, v)

                    if (type(k) ~= "string") then
                        error(sErrorPrefix.."index must be variable-compliant string. Got "..type(k)..'.');
                    end

                    if not (k:variabalcompliant()) then
                        error(sErrorPrefix.."index must be variable-compliant string. Got "..k..'.');
                    end

                    if not (type(v) == "FontStyle") then
                        error(sErrorPrefix.."value must be FontStyle. Got "..type(v)..'.');
                    end

                    tStyles[k] = v;
                end,
                __pairs = function()
                    local nIndex    = 0;
                    local nMax      = 0;
                    local tKeys     = {};

                    for vKey in pairs(tStyles) do
                        nMax = nMax + 1;
                        tKeys[nMax] = vKey;
                    end

                    table.sort(tKeys, fComp);

                    return function()
                        nIndex = nIndex + 1;

                        if (nIndex <= nMax) then
                            local sIndex = tKeys[nIndex];
                            return nIndex, sIndex, tStyles[sIndex];
                        end

                    end

                end,
            });
        end,
        OnShow = function()
            local fImage    = CreateImage
            --TODO FINISH streamline/condense this section

            --create the canvas
            if not (_bCanvasCreated) then
                local bCanvasCreated = Canvas.Create(_sCanvas);
                assert(bCanvasCreated, "Error in Forge, \"${game}\": Could not create canvas for object, \"${canvas}\"." % {game = "TODO GET GAME NAME", canvas = _sCanvas});
            end

            --create the Forge images
            _hImage,        _nImageID       = fImage(_hImage,         _nImageID);
            _hImageExport,  _nImageExportID = fImage(_hImageExport,   _nImageExportID);
            _hImageUtil,    _nImageUtilID   = fImage(_hImageUtil,     _nImageUtilID);

            --mouse event callback functions
            local function MouseUpdate(eEvent)

                if(eEvent.EventCode == CANVAS_MOUSE_MOVE) then
                    _nX = eEvent.Mouse.x;
                    _nY = eEvent.Mouse.y;

                    if not (_hWndCardVer) then
                        _hWndCardVer = ProcSys.GetWindowHandle(PANE.CARD_VER); --TODO ERROR NO LONGER USING THIS PANE NAME
                    end

                    Window.SetText(_hWndCardVer, floor(_nX)..", "..floor(_nY))

                    --Paragraph.SetText("par mouse", floor(_nX)..", "..floor(_nY));
                    --Paragraph.SetText("par neg mouse", floor(_nX - nNegXAdjust)..", "..floor(_nY - nNegYAdjust));
                end

            end

            Canvas.SetCallback(_sCanvas, MouseUpdate);

            --set the Forge's window size and adjust the images
            local sSection = "ForgeWindow";
            local nX        = tonumber(INIFile.GetValue(_pAppCFG, sSection, "X"));
            local nY        = tonumber(INIFile.GetValue(_pAppCFG, sSection, "Y"));
            local nWidth    = tonumber(INIFile.GetValue(_pAppCFG, sSection, "Width"));
            local nHeight   = tonumber(INIFile.GetValue(_pAppCFG, sSection, "Height"));

            _bForgeAutoSizing = true;

            if (nX and nY) then
                Window.SetPos(HWND_APP, nX, nY);
            end

            if (nWidth and nHeight) then
                Window.SetSize(HWND_APP, nWidth, nHeight);
            end

            _bForgeAutoSizing = false;

            --center the images
            CenterCardDisplay();

            --load last set if present  --TODO MOVE THIS TO PROCSYS...IT HAS NO BUSINESS HERE
            local sLastCardSetUUID  = INIFile.GetValue(FS.Info, "SESSION", "LastSet");
            local oGame             = Game.GetActive();
            local oLastCardSet      = oGame.GetCardSet(sLastCardSetUUID);

            if (type(oLastCardSet) == "CardSet") then
                ProcSys.LoadCardSet(oLastCardSet);
            end

            Page.StartTimer(_nRedrawTimerInterval,      _nRedrawTimerID);
        end,
        OnSize = function(nWindowWidth, nWindowHeight, nPageWidth, nPageHeight, nType)
            local tPos      = Window.GetPos(HWND_APP);
            local sSection  = "ForgeWindow";

            if not (_bForgeAutoSizing) then
                INIFile.SetValue(_pAppCFG, sSection, "Width", tostring(nWindowWidth));
                INIFile.SetValue(_pAppCFG, sSection, "Height", tostring(nWindowHeight));
                INIFile.SetValue(_pAppCFG, sSection, "X", tostring(tPos.X));
                INIFile.SetValue(_pAppCFG, sSection, "Y", tostring(tPos.Y));
            end

            _nPageWidth     = nPageWidth;
            _nPageHeight    = nPageHeight;

            --TODO FINISH adjust canvas size using math.rect functions TODO use set data in the module (for width and height)
            local tOuter    = {x = 0, y = 0, width = nPageWidth, height = nPageHeight};
            local tInner    = {x = 0, y = 0, width = _nCardWidth, height = _nCardHeight};

            local tRect     = math.geometry.fitrect(tOuter, tInner, true);
            Input.SetSize(_sCanvas, tRect.width, tRect.height);
            Input.SetPos(_sCanvas, tRect.x, tRect.y);

            --store the canvas size info
            local tSize     = Input.GetSize(_sCanvas);
            _nCanvasWidth   = tSize.Width;
            _nCanvasHeight  = tSize.Height;

            --center the images
            CenterCardDisplay();

            if (_tLastRow) then
                _bRedrawRequested   = true;
                _bIsResizing        = true;
            end

        end,
        STYLE = null, --public enum
        OnTimer = function(nID)

            if (nID == _nRedrawTimerID) then
                --increment the delta time
                _nTimeDelta = _nTimeDelta + _nRedrawTimerInterval;

                --check if a redraw request was made and that we're done resizing
                if (_bRedrawRequested and not _bIsResizing) then
                    --redraw the card
                    Forge.DrawCard(_tLastRow);
                    --fulfill the request
                    _bRedrawRequested = false;
                end

                --if enough time has passed...
                if (_nTimeDelta >= _nSizingDelta) then
                    --...indicate resizing has stopped
                    _bIsResizing    = false;
                    --...and reset the time delta
                    _nTimeDelta     = 0;
                end

            end

        end,
        SetActiveCardSet = function(oCardSet)

            if not (type(oCardSet) == "CardSet") then
                --TODO THROW ERROR
            end

            _oActiveCardSet = oCardSet;
            _nCardWidth     = oCardSet.GetCardWidth();
            _nCardHeight    = oCardSet.GetCardHeight();
            _sCardSetName   = oCardSet.GetName();
        end,
        UpdateStyles = function(this, cdat)

            for oStyle in pairs(_tStyle) do
                oStyle.Update();
            end

        end,
    },
    {--PRIVATE
        Forge = function(this, cdat) end
    },
    {--PROTECTED

    },
    {},     --PUBLIC
    nil,    --extending class
    true,   --if the class is final
    nil     --interface(s) (either nil, or interface(s))
);
