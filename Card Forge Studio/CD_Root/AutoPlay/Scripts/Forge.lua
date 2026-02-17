local class         = class;
local math          = math;
local rawtype       = rawtype;
local string        = string;
local toboolean     = toboolean;
local tonumber      = tonumber;
local tostring      = tostring;
local type          = type;
    isnumber        = type.isnumber;
    isstring        = type.istring;
local clicks = 0;
local floor         = math.floor;
local clamp         = math.clamp;

local Color         = Color;
local Drawing       = Drawing;
local DrawingFont   = DrawingFont;
local INIFile       = INIFile;
local _nOrientation         = VER;
local _nLastOrientation = VER;

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

local _hWndCardVer;

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
    HHeight      = 1125,
    MajorStep   = 100,
    MinorStep   = 25,
    MajorWidth  = 16,
    MinorWidth  = 10,
    Color       = _nRulerColor,
};
local _tCenterLines = {
    Color       = Color.RGBA(50, 50, 255, 255),
};

local function IsCardVertical(tRow)
    local sIsVertical = tRow.IsVertical;
    local nIsVertical = sIsVertical and tonumber(sIsVertical) or 0;
    nIsVertical       = (nIsVertical == 0 or nIsVertical == 1) and nIsVertical or 0;
    return #nIsVertical;
end

--TODO FIX FINISH  make images for each card type as needed! modify code to reflect this change

--TODO remove magic numbers...put in gobals as original size of card and MOVE TO FORGE.lua


local _nX, _nY          = 0;
local _tImageCache      = {};
local _tUserImageCache  = {};
local function ImageLoadError(sPath, sName, sMsg)
    error("Error in Forge.LoadImage:\r\nError loading card image at path: \""..sPath.."\" with name, \""..sName.."\"."..#sName.."\r\n"..sMsg, 3)
end

local FontStyle   = require("Forge.FontStyle");



return class("Forge",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Forge = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        LoadImage = function(sPath, sName)
            --TODO assertions
            if not (File.DoesExist(sPath)) then
                local sLastError = _tblErrorMessages[Application.GetLastError()];
                local sError = sLastError ~= "Success." and sLastError or "Image could not be found."
                ImageLoadError(sPath, sName or "UNKOWN", sError);
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
        end,
    },
    {--PRIVATE
        --set during Draw, used in DrawText, etc.
        Object                  = null,
        D                       = null,
        InternalDC              = null,
        ------------------------------
        AutoUpdateStyle__AUTO__ = false,
        Orientation             = VER,
        WidthHor__AUTOR_        = null,
        WidthVer__AUTOR_        = null,
        HeightHor__AUTOR_       = null,
        HeightVer__AUTOR_       = null,
        CanvasHor__AUTOR_       = null,
        CanvasVer__AUTOR_       = null,
        CanvasNameHor__AUTOR_   = null,
        CanvasNameVer__AUTOR_   = null,
        CanvasHorCreated        = false,--TODO RO these
        CanvasVerCreated        = false,
        ImageHandleHor          = null,
        ImageHandleVer          = null,
        ImageIDHor              = null,
        ImageIDVer              = null,
        UtilImageHandleHor      = null,
        UtilImageHandleVer      = null,
        UtilImageIDHor          = null,
        UtilImageIDVer          = null,
        Name__AUTOR_            = null,
        StylesINI__AUTOA_       = "", --TODO FINISH STYLE NAMES MUST BE VARIABLE COMPLIANT

        ClearToTransparent = function(this, cdat, nW, nH, D)
            D.SetFilteringMode(DRAW_BLEND_ALLCHANNELS);
            D.DrawRectangle(0, 0, nW, nH, Color.RGBA(0, 0, 0, 0));
            D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
        end,

        CreateImage = function(this, cdat, sHandleIndex, sIDIndex, vOrientation)
            local pri = cdat.pri;
            local nOrientation  = (type(vOrientation) == "number" and (vOrientation == HOR or vOrientation == VER)) and vOrientation or VER;
            local bIsVertical   = nOrientation == VER;
            local nWidth        = bIsVertical and pri.WidthVer      or pri.WidthHor;
            local nHeight       = bIsVertical and pri.HeightVer     or pri.HeightHor;
            local sCanvas       = bIsVertical and pri.CanvasNameVer or pri.CanvasNameHor;
            local sOrientation  = bIsVeritcal and "vertical"        or "horizontal";
            local sName         = pri.Name
            local sBaseError    = "Error in Forge, \"${game}\": Could not";

            --create the image only if it's not alreay been created
            if (pri[sHandleIndex] == null and pri[sIDIndex] == null) then
                --create, check, and store the image handle
                local hImage        = DrawingImage.New(nWidth, nHeight, BIT_DEPTH_32, DRAW_IMAGE_TRANSPARENT);
                local sMessage      = sBaseError.." create ${orientation} image for canvas object, \"${canvas}\".";
                assert(hImage, sMessage % {game = sName, orientation = sOrientation, canvas = sCanvas});
                pri[sHandleIndex]   = hImage;

                --get, check, and store the image ID
                local nImageID      = DrawingImage.GetID(hImage);
                sMessage            = sBaseError.." get ${orientation} image ID for canvas object, \"${canvas}\".";
                assert(nImageID, sMessage % {game = sName, orientation = sOrientation, canvas = sCanvas});
                pri[sIDIndex]       = nImageID;
            end

        end,

        DrawCenterLineHor = function(this, cdat, sObject, D, hInternalDC)
            local pri           = cdat.pri;
            local bIsVeritcal   = pri.Orientation == VER;
            local nWidth        = bIsVeritcal and pri.WidthVer  or pri.WidthHor;
            local nHeight       = bIsVeritcal and pri.HeightVer or pri.HeightHor;

            if (bIsVeritcal) then
                local nMidPointY = floor(nHeight / 2);
                D.DrawLineEx(0, nMidPointY, nWidth, nMidPointY, _tCenterLines.Color);
            else
                --TODO
            end

        end,


        DrawCenterLineVer = function(this, cdat, sObject, D, hInternalDC)
            local pri           = cdat.pri;
            local bIsVeritcal   = pri.Orientation == VER;
            local nWidth        = bIsVeritcal and pri.WidthVer  or pri.WidthHor;
            local nHeight       = bIsVeritcal and pri.HeightVer or pri.HeightHor;

            if (bIsVeritcal) then
                local nMidPointX = floor(nWidth / 2);
                D.DrawLineEx(nMidPointX, 0, nMidPointX, nHeight, _tCenterLines.Color);
            else
                --TODO
            end

        end,

        DrawRulerHor = function(this, cdat, bDrawRulerVer, sObject, D, hInternalDC)
            local pri            = cdat.pri;
            local bIsVeritcal    = pri.Orientation == VER;
            local nY             = _tHorRuler.Y;
            local nWidth         = bIsVeritcal and pri.WidthVer or pri.WidthHor;
            local nMajorStep     = _tHorRuler.MajorStep;
            local nMinorStep     = _tHorRuler.MinorStep;
            local nMajorHeight   = _tHorRuler.MajorHeight;
            local nMinorHeight   = _tHorRuler.MinorHeight;
            local nTextY         = nMajorHeight + 3;--TODO remove magic number
            local oColor         = _tHorRuler.Color;
            --TODO FIX draw the first text of the hor ONLY if the veritcal is NOT drawing...same adjust ver

            local nXMax = nWidth - 1;

            D.DrawLineEx(0, nY, nXMax, nY, oColor);

            for nX = 0, nXMax, nMinorStep do
                --draw the line
                local nHeight = (nX % nMajorStep == 0) and nMajorHeight or nMinorHeight;
                D.DrawLineEx(nX, nY, nX, nY + nHeight, oColor);

                --draw the position text
                if (nX > 0) then
                    local sX = tostring(nX);
                    local nTextWidth = D.GetTextWidth(sX);
                    this.STYLE.RULER.Draw(sObject, D, hInternalDC, floor(this.CenterOnX(nX, nTextWidth)), floor(nTextY), sX);
                end
            end

        end,

        DrawRulerVer = function(this, cdat, bDrawRulerHor, sObject, D, hInternalDC)
            local pri            = cdat.pri;
            local bIsVeritcal    = pri.Orientation == VER;
            local nX             = _tVerRuler.X;
            local nHeight        = bIsVeritcal and pri.HeightVer or pri.HeightHor;
            local nMajorStep     = _tVerRuler.MajorStep;
            local nMinorStep     = _tVerRuler.MinorStep;
            local nMajorWidth    = _tVerRuler.MajorWidth;
            local nMinorWidth    = _tVerRuler.MinorWidth;
            local nTextX         = nMajorWidth + 3;
            local oColor         = _tVerRuler.Color;

            local nYMax = nHeight - 1;

            D.DrawLineEx(nX, 0, nX, nYMax, oColor);
            D.SetDrawingFont(this.STYLE.RULER.GetFont());--TODO FIX This must be gotten from the Forge

            for nY = 0, nYMax, nMinorStep do
                local nWidth        = (nY % nMajorStep == 0) and nMajorWidth or nMinorWidth;
                local nLineLength   = nX + nWidth;

                --draw the line
                D.DrawLineEx(nX, nY, nLineLength, nY, oColor);

                --draw the position text
                if (nY > 0) then
                    local sY = tostring(nY);
                    local nTextHeight = D.GetTextHeight(sY);
                    this.STYLE.RULER.Draw(sObject, D, hInternalDC, floor(nTextX), floor(this.CenterOnY(nY, nTextHeight)), sY);
                end

            end

        end,
        DrawUtilObjects = function(this, cdat, sObject, D, hInternalDC)
            local pri = cdat.pri;
            local bIsVertical   = pri.Orientation == VER;
            local nWidth        = bIsVertical and pri.WidthVer  or pri.WidthHor;
            local nHeight       = bIsVertical and pri.HeightVer or pri.HeightHor;

            pri.ClearToTransparent(nWidth, nHeight, D);

            --draw utility objects
            local bDrawRulerHor = MainMenu.IsChecked("Options:>Draw:>Horizontal Ruler Enabled");
            local bDrawRulerVer = MainMenu.IsChecked("Options:>Draw:>Vertical Ruler Enabled");

            D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);

            if (bDrawRulerHor) then
                pri.DrawRulerHor(bDrawRulerVer, sObject, D, hInternalDC);
            end

            if (bDrawRulerVer) then
                pri.DrawRulerVer(bDrawRulerHor, sObject, D, hInternalDC);
            end

            if (MainMenu.IsChecked("Options:>Draw:>Horizontal Centerline Enabled")) then
                pri.DrawCenterLineHor(sObject, D, hInternalDC);
            end

            if (MainMenu.IsChecked("Options:>Draw:>Vertical Centerline Enabled")) then
                pri.DrawCenterLineVer(sObject, D, hInternalDC);
            end

        end,
    },
    {--PROTECTED

    },
    {--PUBLIC
        Forge = function(this, cdat, nWidthHor,     nHeightHor,
                                    nWidthVer,      nHeightVer)
                                            --sCanvasNameHor, sCanvasNameVer)
            --TODO Assertions
            pri                 = cdat.pri;
            pri.WidthHor        = nWidthHor;
            pri.HeightHor       = nHeightHor;
            pri.WidthVer        = nWidthVer;
            pri.HeightVer       = nHeightVer;
            pri.CanvasNameHor   = "cvs card hor";--sCanvasNameHor;--TODO MOVE TO CONstant
            pri.CanvasNameVer   = "cvs card ver";--sCanvasNameVer;
            pri.Name            = _sGame;

            --import the styles
            local pStyles = _pStyles;
            pri.StylesINI = pStyles;

            --TODO check for file and other things...do error checsk later --THROW ERROR if not
            local tSections     = INIFile.GetSectionNames(pStyles);
            --local tNames        = {};
            local tStyles       = {};

            for nIndex, sStyleRaw in pairs(tSections) do
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
            cdat.pub.STYLE = setmetatable({}, {
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
            });

        end,
        CenterCardDisplay = function(this, cdat)
            local pri = cdat.pri;

            local tPos  = Window.GetPos(HWND_APP);
            local tSize = Window.GetSize(HWND_APP);

            --get the size of the canvases
            local tSizeHor = Input.GetSize(pri.CanvasNameHor);
            local tSizeVer = Input.GetSize(pri.CanvasNameVer);

            Input.SetPos(pri.CanvasNameHor, (_nPageWidth - tSizeHor.Width) / 2, (_nPageHeight - tSizeHor.Height) / 2);
            Input.SetPos(pri.CanvasNameVer, (_nPageWidth - tSizeVer.Width) / 2, (_nPageHeight - tSizeVer.Height) / 2);
        end,
        CenterOnX = function(this, cdat, nVal, nTextWidth) --TODO BUG FIX FINISH These functions NOT working properly on angled text
            local nRet = nVal or 0;

            if (cdat.pri.Orientation == VER) then
                nRet = this.X(nVal) - nTextWidth / 2;
            else
        --TODO
            end

            return nRet;
        end,
        CenterOnY = function(this, cdat, nVal, nTextHeight)
            local nRet = nVal or 0;

            if (cdat.pri.Orientation == VER) then
                nRet = this.Y(nVal) - nTextHeight / 2;
            else
        --TODO
            end

            return nRet;
        end,
        CenterOn = function(this, cdat, nX, nY)

        end,
        --assumes tRow and cProc are valid
        DrawCard = function(this, cdat, cProc, tRow, bExport, fExport)
            local pri = cdat.pri;
            local bIsVertical   = pri.Orientation == VER;
            local nWidth        = bIsVertical and pri.WidthVer              or pri.WidthHor;
            local nHeight       = bIsVertical and pri.HeightVer             or pri.HeightHor;
            local sCanvas       = bIsVertical and pri.CanvasNameVer         or pri.CanvasNameHor;
            local hImage        = bIsVertical and pri.ImageHandleVer        or pri.ImageHandleHor;
            local hUtilImage    = bIsVertical and pri.UtilImageHandleVer    or pri.UtilImageHandleHor;
            local nImageID      = bIsVertical and pri.ImageIDVer            or pri.ImageIDHor;
            local nUtilImageID  = bIsVertical and pri.UtilImageIDVer        or pri.UtilImageIDHor;

            if (pri.Orientation ~= _nLastOrientation) then
                Input.SetVisible(pri.CanvasNameHor, not bIsVertical);
                --Input.SetEnabled(pri.CanvasNameHor, not bIsVertical);
                Input.SetVisible(pri.CanvasNameVer, bIsVertical);
                --Input.SetEnabled(pri.CanvasNameVer, bIsVertical);
                _nLastOrientation = pri.Orientation;
            end

            --draw the card
            local function ProcDraw(sObject, D, hInternalDC)
                pri.ClearToTransparent(nWidth, nHeight, D);
                --get the proc's draw method
                local fProcDraw = cProc.DrawCard(this, cProc, tRow, nWidth, nHeight);

                --check it
                assert(rawtype(fProcDraw) == "function", "Error Drawing Card, \""..tRow.Name.."\".\r\nMissing static DrawCard function in "..tostring(cProc).." class or function not correctly implemented."); --TODO FINISH

                --update private vars for use in DrawText
                pri.Object      = sObject;
                pri.D           = D;
                pri.InternalDC  = hInternalDC;

                --execute the proc's draw method
                fProcDraw(sObject, D, hInternalDC);
            end

            --clear the canvas
            Canvas.Clear(sCanvas, _oClear);

            --draw on the card image
            hImage:Draw(ProcDraw);

            --draw on the util image
            hUtilImage:Draw(pri.DrawUtilObjects);

            --draw the card and util images onto the canvas (since drawing directly on the canvas is no bueno)
            Canvas.Draw(sCanvas,
                        function(sObject, D, hInternalDC)
                            D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
                            D.DrawImage(nImageID, 0, 0);
                            D.DrawImage(nUtilImageID, 0, 0);
                        end
            );

            if (bExport and fExport and type(fExport) == "function") then
                fExport(pri.D, hImage, cProc, tRow); --TODO FINISH PCALL this and send erros to status
            end

            --[[
            --saves the entire canvas!
            local hNew = Canvas.GrabImage(sCanvas);
            if(hNew)then
                DrawingImage.Save(hNew, tRow.Name..".png", DRAW_FORMAT_PNG);
                DrawingImage.Free(hNew);
            end]]
        end,
        --may be called ONLY in the proc's draw
        DrawText = function(this, cdat, sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, ...)
            --TODO assertions
            local pri           = cdat.pri;
            local pub           = cdat.pub;
            local eStyle        = pub.STYLE;

            local fWrap         = rawtype(vWrap)        == "function"   and vWrap       or false;
            local bCenterX      = rawtype(vCenterX)     == "boolean"    and vCenterX    or false;
            local bCenterY      = rawtype(vCenterY)     == "boolean"    and vCenterY    or false;
            local oStyle        = eStyle[sStyle] --TODO add default style as fallback???
            local sObject       = pri.Object;
            local D             = pri.D;
            local hInternalDC   = pri.InternalDC;
            local tLines        = {}; --used for text wrapping
            local nStartOffsetX, nStartOffsetY = 0, 0;

            if (pri.AutoUpdateStyle) then --update the style (if requested)
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
                oStyle.Draw(sObject, D, hInternalDC, floor(nTrueX), floor(nTrueY), sLine, vAngle);
            end

            return nLastX, nLastY, nLastWidth, nLastHeight;
        end,
        DrawStyledText = function(this, cdat, sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, ...)--TODO BUG FIX USe HTML parser, not this
            local pri           = cdat.pri;
            local pub           = cdat.pub;
            local eStyle        = pub.STYLE;

            local fWrap         = rawtype(vWrap)        == "function"   and vWrap       or false;
            local bCenterX      = rawtype(vCenterX)     == "boolean"    and vCenterX    or false;
            local bCenterY      = rawtype(vCenterY)     == "boolean"    and vCenterY    or false;

            local sObject       = pri.Object;
            local D             = pri.D;
            local hInternalDC   = pri.InternalDC;

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
            if (pri.AutoUpdateStyle) then
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
                    oStyle.Prep(D, sPart, false);

                    -- true ink bounds (includes your shadow/outline/etc via Prep)
                    local nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(D, sPart, true);

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

                    oStyle.Prep(D, sPart, false);

                    local nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(D, sPart, true);

                    -- KEY FIX:
                    -- draw so that the ink-box starts at nX (neutralizes negative bearings / kerning tuck)
                    local nDrawX = nX - (nMinX or 0);
                    local nDrawY = nLineY;

                    --TEST (keep it, but make it match the real ink-box)
                    --local R = math.random;
                    --D.DrawRectangle(floor(nX), floor(nY), floor(nTotalW), floor(nTotalH), Color.RGBA(R(1, 255),R(1, 255),R(1, 255),60));
                    --TEST

                    oStyle.Draw(sObject, D, hInternalDC, floor(nDrawX), floor(nDrawY), sPart, vAngle);

                    nX = nX + nTotalW + nPadX;
                end

                nY = nY + (tInfo.H or 0);
            end

            return nBaseX, nBaseY, nBlockW, nBlockH;
        end,
        GetCanvasName = function(this, cdat)
            local pri = cdat.pri;
            return pri.Orientation == VER and pri.CanvasNameVer or pri.CanvasNameHor;
        end,
        GetCenterX = function(this, cdat)
            local pri = cdat.pri;
            return pri.Orientation == VER and pri.WidthVer / 2 or pri.WidthHor / 2;
        end,
        GetCenterY = function(this, cdat)
            local pri = cdat.pri;
            return pri.Orientation == VER and pri.HeightVer / 2 or pri.HeightHor / 2;
        end,
        GetContext = function(this, cdat)
            local pri = cdat.pri;
            return pri.Object, pri.D, pri.InternalDC;
        end,
        GetHeight = function(this, cdat)
            local pri = cdat.pri;
            return pri.Orientation == VER and pri.HeightVer or pri.HeightHor;
        end,
        GetOrientation = function(this, cdat)
            return cdat.pri.Orientation;
        end,
        GetWidth = function(this, cdat)
            local pri = cdat.pri;
            return pri.Orientation == VER and pri.WidthVer or pri.WidthHor;
        end,
        --SetAutoUpdateStyle =  function(this, cdat, vFlag)
    --        cdat.pri.AutoUpdateStyle = rawtype(vFlag) == "boolean" and vFlag or false;
--        end,
        SetOrientation = function(this, cdat, vOrientation)
            local pri = cdat.pri;
            local nOrientation = rawtype(vOrientation) == "number" and vOrientation or VER;
            nOrientation       = (nOrientation == HOR or nOrientation == VER) and nOrientation or VER;
            pri.Orientation    = nOrientation;
            return this;
        end,
    --[[    OnMenu = function(nID, tItemInfo)



    end,]]
        OnShow = function(this, cdat)
            local pri       = cdat.pri;
            local fImage    = pri.CreateImage
            --TODO FINISH streamline/condense this section

            --create the horizontal canvas
            if not (pri.CanvasHorCreated) then
                local bHorCanvasCreated = Canvas.Create(pri.CanvasNameHor);
                assert(bHorCanvasCreated, "Error in Forge, \"${game}\": Could not create horizontal canvas for object, \"${canvas}\"." % {game = pri.Name, canvas = pri.CanvasNameHor});
                pri.CanvasHorCreated = true;
            end

            --create the vertical canvas
            if not (pri.CanvasVerCreated) then
                local bVerCanvasCreated = Canvas.Create(pri.CanvasNameVer);
                assert(bVerCanvasCreated, "Error in Forge, \"${game}\": Could not create vertical canvas for object, \"${canvas}\"." % {game = pri.Name, canvas = pri.CanvasNameVer});
                pri.CanvasVerCreated = true;
            end

            --create the images that will be drawn on the canvas
            fImage("ImageHandleHor",        "ImageIDHor", HOR);
            fImage("ImageHandleVer",        "ImageIDVer", VER);
            fImage("UtilImageHandleHor",    "UtilImageIDHor", HOR);
            fImage("UtilImageHandleVer",    "UtilImageIDVer", VER);

            --mouse event callback functions
            local function MouseUpdate(eEvent)

                if(eEvent.EventCode == CANVAS_MOUSE_MOVE)then
                    _nX = eEvent.Mouse.x;
                    _nY = eEvent.Mouse.y;
                    local bIsVertical = pri.Orientation == VER;
                    local nNegXAdjust = bIsVertical and pri.WidthVer    or pri.WidthHor;
                    local nNegYAdjust = bIsVertical and pri.HeightVer   or pri.WidthVer;

                    if not (_hWndCardVer) then
                        _hWndCardVer = ProcSys.GetWindowHandle(PANE.CARD_VER);
                    end

                    Window.SetText(_hWndCardVer, floor(_nX)..", "..floor(_nY))

                    --Paragraph.SetText("par mouse", floor(_nX)..", "..floor(_nY));
                    --Paragraph.SetText("par neg mouse", floor(_nX - nNegXAdjust)..", "..floor(_nY - nNegYAdjust));
                end

            end

            Canvas.SetCallback(pri.CanvasNameHor, MouseUpdate);
            Canvas.SetCallback(pri.CanvasNameVer, MouseUpdate);

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
            this.CenterCardDisplay();

            --load last set if present
            local pLastSet = _pCSVSource.."\\"..INIFile.GetValue(_pInfo, "SESSION", "LastSet")..".csv";

            if (File.DoesExist(pLastSet)) then
                ProcSys.LoadSet(pLastSet);
            end

        end,
        OnSize = function(this, cdat, nWindowWidth, nWindowHeight, nPageWidth, nPageHeight, nType)
            local pri       = cdat.pri;
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

            --center the images
            this.CenterCardDisplay();
        end,
        STYLE = null, --public enum
        UpdateStyles = function(this, cdat)

            for oStyle in pairs(cdat.pub.STYLE) do
                oStyle.Update();
            end

        end,
        X = function(this, cdat, nVal) --releative functions...get the x value relative otthe build size
            local pri = cdat.pri;
            nRet = -1;

            if (pri.Orientation == VER) then
                local nWidth = pri.WidthVer;
                nRet = (nVal / nWidth) * Input.GetSize(pri.CanvasNameVer).Width;
                else
        --TODO
            end

            return nRet;
        end,
        Y = function(this, cdat, nVal)
            nRet = -1;

            if (cdat.pri.Orientation == VER) then
                local nHeight = pri.HeightVer;
                nRet = (nVal / nHeight) * Input.GetSize(pri.CanvasNameVer).Height;
            else
        --TODO
            end

            return nRet;
        end,
    },
    nil,   --extending class
    true, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
