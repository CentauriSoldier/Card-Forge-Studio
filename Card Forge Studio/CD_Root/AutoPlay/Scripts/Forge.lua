-------------------------🅻🅾🅲🅰🅻🅸🆉🅰🆃🅸🅾🅽--------------------
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

local FontStyle   = require("Forge.FontStyle");
-------------------------------------------------------------------
--TODO move all these settings to file
local _oWhite               = Color.RGBA(255, 255, 255, 255); --TODO Fix names!!! _
local _oBlack               = Color.RGBA(0, 0, 0, 255);
local _oClear               = Color.RGBA(0, 0, 0, 0)
local _nRulerColor          = Color.RGBA(240, 100, 100, 255); --TODO change these values from INI file
local _nRulerBGColor        = Color.RGBA(255, 255, 255, 0)

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

local _fDraw;

-------------------------------------------------------------------
local _nPageWidth           = -1;
local _nPageHeight          = -1;
-------------------------------------------------------------------
--set during Draw, used in DrawText, etc.
local _Object       = null;
local _D            = null;
local _InternalDC   = null;
-------------------------------------------------------------------
local _tStyles          = {};
local _bAutoUpdateStyle = false;
--------------------🅲🅰🅽🆅🅰🆂 🆁🅴🅻🅰🆃🅴🅳-----------------------
local _sCanvas          = FORGE_CANVAS_NAME;
local _bCanvasCreated   = false;
local _nCanvasWidth     = 100;
local _nCanvasHeight    = 100;
local _hWndCard         = false;
---------------------🅼🅾🆄🆂🅴 & 🆂🆃🅰🆃🆄🆂------------------------
local _sStatusObject            = FORGE_STATUS_NAME;
local _sStatusMouseObject       = FORGE_STATUS_MOUSE_NAME;
local _sStatusMouseNegObject    = FORGE_STATUS_MOUSE_NEG_NAME;
local _nStatusHeight            = 50;  --applies to all status par objects
local _nStatusMouseWidth        = 180; --applies to both mouse status par objects
local _sStatus                  = "";
-----------------------🅲🅾🆅 🆅🅰🅻🆄🅴🆂----------------------------
local _CoVXW = 1;
local _CoVYH = 1;
---------------------🅳🆁🅰🆆 🅿🅻🆄🅶🅸🅽 🅸🅼🅰🅶🅴🆂-----------------
local _hImage           = null;
local _nImageID         = null;
local _hImageExport     = null;
local _nImageExportID   = null;
local _hImageUtil       = null;
local _nImageUtilID     = null;
-------------------------------------------------------------------
local _tImageCache      = {};
local _tUserImageCache  = {};
-------------------------🅲🅰🆁🅳 🅸🅽🅵🅾---------------------------
local _oActiveCardSet = false;
local _nCardWidth     = 100;
local _nCardHeight    = 100;
local _sCardSetName   = "";
---------------🆁🅴🅳🆁🅰🆆 & 🅵🅸🅻🅴 🆂🆈🅽🅲 🅵🅸🅴🅻🅳🆂--------------
local _tLastRow;
local _bRedrawRequested         = false;
local _bIsResizing              = false;
local _bForgeAutoSizing         = false;
local _nTimeDelta               = 0;
local _nSizingDelta             = FORGE_REDRAW_SIZING_INTERVAL;
local _nRedrawTimerID           = FORGE_REDRAW_TIMER_ID;
local _nRedrawTimerInterval     = FORGE_REDRAW_TIMER_INTERVAL;
-------------------------------------------------------------------

--local Styles           = ""; --TODO FINISH STYLE NAMES MUST BE VARIABLE COMPLIANT

local function sink() end


local function ImageLoadError(sPath, sName, sMsg)
    error("Error in Forge.LoadImage:\r\nError loading card image at path: \""..sPath.."\" with name, \""..sName.."\"."..#sName.."\r\n"..sMsg, 4);
end

local function LoadImage(sPath, sName)
    --TODO assertions
    if not (File.DoesExist(sPath)) then
        local sLastError = _tblErrorMessages[Application.GetLastError()];
        local sError = sLastError ~= "Success." and sLastError or "Image could not be found."..sLastError --TODO QUESTION is this correct?
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


local function ClearToTransparent(D)
    D.SetFilteringMode(DRAW_BLEND_ALLCHANNELS);
    D.DrawRectangle(0, 0, _nCardWidth, _nCardHeight, Color.RGBA(0, 0, 0, 0));
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
        assert(hRet, sMessage % {canvas = _sCanvas});

        --get, check, and store the image ID
        nRet        = DrawingImage.GetID(hRet);
        sMessage    = sBaseError.." get image ID for canvas object, \"${canvas}\" having image handle, ${handle}.";
        assert(nRet, sMessage % {canvas = _sCanvas, handle = tostring(hRet) or "nil"});
    end

    return hRet, nRet;
end

local function DrawCenterLineHor(sObject, D, hInternalDC)
    local nMidPointY = floor(_nCardHeight / 2);
    D.DrawLineEx(0, nMidPointY, _nCardWidth, nMidPointY, _tCenterLines.Color);
end


local function DrawCenterLineVer(sObject, D, hInternalDC)
    local nMidPointX = floor(_nCardWidth / 2);
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

    local nXMax = _nCardWidth - 1;

    D.DrawLineEx(0, nY, nXMax, nY, oColor);

    for nX = 0, nXMax, nMinorStep do

        --draw the line
        local nHeight = (nX % nMajorStep == 0) and nMajorHeight or nMinorHeight;
        D.DrawLineEx(nX, nY, nX, nY + nHeight, oColor);

        --draw the position text
        local bDrawText = nX > 0 and not (nX == nMinorStep and bDrawRulerVer);

        if (bDrawText) then
            local sX = tostring(nX);
            local nTextWidth = D.GetTextWidth(sX);
            _tStyles.RULER.Draw(sObject, D, hInternalDC, floor(Forge.CenterOnX(nX, nTextWidth)), floor(nTextY), sX);
        end
    end

end

local function DrawRulerVer(bDrawRulerHor, sObject, D, hInternalDC) --TODO minor issue, realign first minor step when HOR ruler is drawing to be in line with both minor ticks
    local nX             = _tVerRuler.X;
    local nMajorStep     = _tVerRuler.MajorStep;
    local nMinorStep     = _tVerRuler.MinorStep;
    local nMajorWidth    = _tVerRuler.MajorWidth;
    local nMinorWidth    = _tVerRuler.MinorWidth;
    local nTextX         = nMajorWidth + 3;
    local oColor         = _tVerRuler.Color;

    local nYMax = _nCardHeight - 1;

    D.DrawLineEx(nX, 0, nX, nYMax, oColor);
    D.SetDrawingFont(_tStyles.RULER.GetFont());--TODO FIX This must be gotten from the Forge

    for nY = 0, nYMax, nMinorStep do
        local nWidth        = (nY % nMajorStep == 0) and nMajorWidth or nMinorWidth;
        local nLineLength   = nX + nWidth;

        --draw the line
        D.DrawLineEx(nX, nY, nLineLength, nY, oColor);

        --draw the position text
        if (nY > 0) then
            local sY = tostring(nY);
            local nTextHeight = D.GetTextHeight(sY);
            _tStyles.RULER.Draw(sObject, D, hInternalDC, floor(nTextX), floor(Forge.CenterOnY(nY, nTextHeight)), sY);
        end

    end

end

local function DrawUtilObjects(sObject, D, hInternalDC)
    ClearToTransparent(D);

    if MainMenu.IsChecked("Options:>Draw:>Utility Overlay") then

        --draw utility objects
        local bDrawRulerHor = MainMenu.IsChecked("Options:>Draw:>Horizontal Ruler");
        local bDrawRulerVer = MainMenu.IsChecked("Options:>Draw:>Vertical Ruler");

        D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);

        if (bDrawRulerHor) then
            DrawRulerHor(bDrawRulerVer, sObject, D, hInternalDC);
        end

        if (bDrawRulerVer) then
            DrawRulerVer(bDrawRulerHor, sObject, D, hInternalDC);
        end

        if (MainMenu.IsChecked("Options:>Draw:>Horizontal Centerline")) then
            DrawCenterLineHor(sObject, D, hInternalDC);
        end

        if (MainMenu.IsChecked("Options:>Draw:>Vertical Centerline")) then
            DrawCenterLineVer(sObject, D, hInternalDC);
        end

    end

end





--[[tUserEnv.S = {}; --TODO INTEGRATE THIS INTO A FUNCTION!
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



--[[!
    @fqxn CFS.Classes.Forge
    @desc <h2>Forge</h2>

    <p>
      The <strong>Forge</strong> is the card rendering and preview subsystem for Card Forge Studio.
      It draws the currently selected card from ProcSys onto a dedicated canvas, maintains internal
      render targets for composition, and provides editor-facing visual utilities (rulers, centerlines, etc.).
    </p>

    <h3>Responsibilities</h3>
    <ul>
      <li><strong>Card preview rendering</strong> – Draws the active card by executing the active CardSet’s live <code>Draw</code> script against the current row data.</li>
      <li><strong>Offscreen composition</strong> – Renders card artwork and utility overlays into separate images, then composites them onto the canvas.</li>
      <li><strong>Live scripting integration</strong> – Loads and executes the CardSet <code>Draw</code> chunk via the UserEnv, supporting a live-update workflow.</li>
      <li><strong>Utility overlays</strong> – Draws editor aids such as horizontal/vertical rulers and centerlines as a separate overlay layer.</li>
      <li><strong>Mouse feedback & status</strong> – Tracks mouse position over the canvas and updates dedicated status paragraph objects with scaled coordinates.</li>
      <li><strong>Clipboard convenience</strong> – Supports copying mouse coordinate readouts via mouse click actions.</li>
      <li><strong>Resize-aware redraw</strong> – Handles window/canvas resizing by deferring redraw until resizing stabilizes, then re-rendering the last active row.</li>
      <li><strong>Style system</strong> – Loads FontStyle definitions from an INI source, exposes style lookup behavior, and supports optional auto-refresh of style state.</li>
      <li><strong>Image caching</strong> – Caches user image handles/IDs to avoid redundant loads during repeated draws.</li>
    </ul>

    <h3>Render model</h3>
    <ul>
      <li>The Forge maintains multiple internal image targets: a primary card image, a utility overlay image, and an export image target.</li>
      <li>Each draw clears to transparent, executes the CardSet draw routine, renders utility overlays, and composites the results onto the canvas.</li>
      <li>Canvas mouse coordinates are scaled back into card-space using internally maintained conversion factors.</li>
    </ul>

    <h3>Lifecycle</h3>
    <ol>
      <li><strong>OnShow</strong> creates the canvas (one-time), restores window placement, installs mouse callbacks, and starts the redraw timer.</li>
      <li><strong>SetActiveCardSet</strong> updates card dimensions and recreates internal render targets for the new set.</li>
      <li><strong>DrawCard</strong> renders the active card row and overlay layers, then composites them to the canvas.</li>
      <li><strong>OnSize</strong> recomputes layout for canvas + status objects and queues a deferred redraw when appropriate.</li>
      <li><strong>OnTimer</strong> fulfills deferred redraw requests once resizing has settled.</li>
    </ol>

    <h3>Notes</h3>
    <ul>
      <li>Utility overlays are editor aids and are rendered separately from card artwork, allowing them to be enabled/disabled without modifying the CardSet draw script or affecting the exports.</li>
      <li>CardSet draw logic is executed in the configured UserEnv, keeping drawing behavior set-specific while the Forge remains a generic renderer/compositor.</li>
    </ul>
!]]
return class("Forge",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Forge = function(cForge, sAuthCode) end, --static constructor (runs after class object creation)
        LoadImage = LoadImage,
        STYLE__RO = _tStyleDecoy,
        CenterOnX = function(nVal, nTextWidth) --TODO BUG FIX FINISH These functions NOT working properly on angled text
            local nRet = nVal or 0;
            nRet = nVal - nTextWidth / 2;
            return nRet;
        end,
        CenterOnY = function(nVal, nTextHeight)
            local nRet = nVal or 0;
            nRet = nVal - nTextHeight / 2;
            return nRet;
        end,
        CenterOn = function(nX, nY)

        end,
        --[[!
            @fqxn CFS.Classes.Forge.Methods.DrawCard
            @desc Draws the currently selected card into the Forge canvas.

            <p>
              Executes the active CardSet’s live <code>Draw</code> script using the current row data,
              renders editor utility overlays (rulers, centerlines, etc.) into a separate layer,
              and composites all results onto the Forge canvas.
            </p>

            <h3>Behavior</h3>
            <ul>
              <li>Clears internal render targets to transparent before drawing.</li>
              <li>Loads and executes the CardSet <code>Draw</code> chunk in the active UserEnv.</li>
              <li>Invokes the CardSet-provided draw function to render card artwork.</li>
              <li>Renders utility overlays into a dedicated utility image.</li>
              <li>Composites the card image and utility image onto the canvas.</li>
            </ul>

            <h3>Notes</h3>
            <ul>
              <li>This method does not perform export; it is strictly for preview rendering.</li>
              <li>Utility overlays are rendered independently of card artwork.</li>
              <li>The most recently drawn row is cached to support deferred redraw after resizing.</li>
              <li>Intended to be called by ProcSys in response to selection changes or redraw requests.</li>
            </ul>

            @param table tRow Final grid row data for the card being drawn.
        !]]
        DrawCard = function(tRow)--, bExport, fExport) --TODO move this out to private static to be used here and in new export function
            --in case a resize happens
            _tLastRow  = tRow;

            --draw the card
            local function ProcDraw(sObject, D, hInternalDC)
                --update private vars for use in DrawText and other functions
                _Object      = sObject;
                _D           = D;
                _InternalDC  = hInternalDC;

                ClearToTransparent(D);

                --execute the proc's draw method
                _fDraw(sObject, D, hInternalDC);
            end

            --reset the image size to its original size
            --hImage:Resize(nWidth, nHeight, DRAW_RESIZE_RAW);

            --clear the canvas
            Canvas.Clear(_sCanvas, _oClear);

            --draw on the card image
            _hImage:Draw(ProcDraw);

            --draw on the util image
            _hImageUtil:Draw(DrawUtilObjects);

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
        --[[!
            @fqxn CFS.Classes.Forge.Methods.DrawImage
            @desc Draws an image onto the active card render target.

            <p>
              Loads (or retrieves from cache) an image from the active game directory and draws it
              into the current card draw context. This method is primarily intended for use by
              CardSet <code>Draw</code> scripts, but may also be used internally by the Forge.
            </p>

            <h3>Behavior</h3>
            <ul>
              <li>Resolves the image path relative to the active game folder.</li>
              <li>Sanitizes the provided path to prevent invalid or unsafe access.</li>
              <li>Caches image handles to avoid redundant loads across draw calls.</li>
              <li>Draws the image using alpha blending.</li>
            </ul>

            <h3>Notes</h3>
            <ul>
              <li>This method must be called from within an active card draw pass.</li>
              <li>Images are drawn into the card image layer, not the utility overlay layer.</li>
              <li>Repeated calls with the same image path reuse cached image handles.</li>
            </ul>

            @param string pImage  Relative image path (from the game directory).
            @param number nX      X position in card-space coordinates.
            @param number nY      Y position in card-space coordinates.
            @param number nWidth  Draw width in card-space units.
            @param number nHeight Draw height in card-space units.
            @param string sName   Optional image identifier used for error reporting.
            @ex
            -- Draw an image asset onto the card at a fixed position
            local pOgre = "Images/Ogre.png";
            Forge.DrawImage(pOgre, 100, 100, 32, 32);
        !]]
        DrawImage = function(pImage, nX, nY, nWidth, nHeight, sName)
            --TODO assertions
            local hImage, nImage = LoadImage(FS.Game.."\\"..SanitizePath(pImage, pImage), sName);
            _D.SetFilteringMode(DRAW_BLEND_ALPHABLEND);
            _D.DrawImage(nImage, nX, nY, nWidth, nHeight);
        end,
        --[[!
            @fqxn CFS.Classes.Forge.Methods.DrawText
            @desc Draws plain text onto the active card render target using a single style.

            <p>
              Renders text using the specified FontStyle during the active card draw pass.
              This method is intended for use by CardSet <code>Draw</code> scripts and supports
              optional centering, rotation, and custom wrapping behavior.
            </p>

            <h3>Behavior</h3>
            <ul>
              <li>Uses the specified style from <code>Forge.STYLE</code>.</li>
              <li>Optionally centers text around the provided coordinates.</li>
              <li>Supports rotated text via an angle parameter.</li>
              <li>Supports custom line-wrapping through a user-supplied wrapper function.</li>
            </ul>

            <h3>Notes</h3>
            <ul>
              <li>Must be called from within an active card draw pass.</li>
              <li>Text is drawn into the card image layer, not the utility overlay.</li>
              <li>Returns the final draw position and measured size of the last rendered line.</li>
            </ul>

            @param string  sStyle   Name of the FontStyle to use.
            @param number  nRawX    Base X position in card-space coordinates.
            @param number  nRawY    Base Y position in card-space coordinates.
            @param string  sText    Text to draw.
            @param boolean vCenterX Optional horizontal centering flag.
            @param boolean vCenterY Optional vertical centering flag.
            @param number  vAngle   Optional rotation angle (degrees).
            @param function|nil vWrap Optional wrapping function.
            @return number nX       Final X position of the last line drawn.
            @return number nY       Final Y position of the last line drawn.
            @return number nWidth   Width of the rendered text block.
            @return number nHeight  Height of the rendered text block.

            @ex
            -- Draw centered title text near the top of the card
            Forge.DrawText(
                "TITLE",
                412, 60,
                "Example Card",
                true, true
            );
        !]]
        DrawText = function(sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, ...)
            --TODO assertions
            local eStyle        = _tStyles;

            local fWrap         = rawtype(vWrap)        == "function"   and vWrap       or false;
            local bCenterX      = rawtype(vCenterX)     == "boolean"    and vCenterX    or false;
            local bCenterY      = rawtype(vCenterY)     == "boolean"    and vCenterY    or false;
            local oStyle        = eStyle[sStyle] --TODO add default style as fallback???
            local tLines        = {}; --used for text wrapping
            local nStartOffsetX, nStartOffsetY = 0, 0;

            if (_bAutoUpdateStyle) then --update the style (if requested)
                oStyle.Update();
            end

            local nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(_D, sText);

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

                nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(_D, sLine, true);
                nBaseX = bCenterX and (nRawX - (nTotalW / 2) - nMinX) or nRawX;
                nBaseY = bCenterY and (nRawY - (nTotalH / 2) - nMinY) or nRawY;

                nTrueX = nBaseX + (bFirstLine and nStartOffsetX or 0);
                nTrueY = nBaseY + (bFirstLine and nStartOffsetY or 0) + nLineYAdjuster;

                nLastX      = nTrueX;
                nLastY      = nTrueY;
                nLastWidth  = nTotalW;
                nLastHeight = nTotalH;

                --draw the text
                --oStyle.Draw(_sObject, _D, _InternalDC, floor(nTrueX), floor(nTrueY), sLine, vAngle);
                oStyle.Draw(_Object, _D, _InternalDC, floor(nTrueX), floor(nTrueY), sLine, vAngle);
            end

            return nLastX, nLastY, nLastWidth, nLastHeight;
        end,
        --[[!
            @fqxn CFS.Classes.Forge.Methods.DrawStyledText
            @desc Draws text containing inline style markup onto the active card render target.

            <p>
              Renders text that includes inline style tags (e.g. <code>&lt;BOLD&gt;</code>,
              <code>&lt;ITALIC&gt;</code>) using multiple FontStyles in a single draw call.
              This method is intended for CardSet <code>Draw</code> scripts that require
              rich text composition.
            </p>

            <h3>Behavior</h3>
            <ul>
              <li>Parses inline style tags and resolves them against <code>Forge.STYLE</code>.</li>
              <li>Preserves style runs across wrapped lines.</li>
              <li>Uses ink-box layout to neutralize negative bearings and kerning artifacts.</li>
              <li>Supports centering, rotation, and custom wrapping behavior.</li>
            </ul>

            <h3>Notes</h3>
            <ul>
              <li>Must be called from within an active card draw pass.</li>
              <li>Tags that do not resolve to a known style fall back to the base style.</li>
              <li>Returns the top-left position and total size of the rendered text block.</li>
            </ul>

            @param string  sStyle   Base FontStyle name.
            @param number  nRawX    Base X position in card-space coordinates.
            @param number  nRawY    Base Y position in card-space coordinates.
            @param string  sText    Text with inline style markup.
            @param boolean vCenterX Optional horizontal centering flag.
            @param boolean vCenterY Optional vertical centering flag.
            @param number  vAngle   Optional rotation angle (degrees).
            @param function|nil vWrap Optional wrapping function.
            @return number nX       Top-left X position of the rendered block.
            @return number nY       Top-left Y position of the rendered block.
            @return number nWidth   Total width of the rendered block.
            @return number nHeight  Total height of the rendered block.

            @ex
            -- Draw a description line with inline emphasis
            -- Note: there must exist a Style named "BOLD"
            Forge.DrawStyledText(
                "BODY",
                60, 820,
                "Deal <BOLD>3 damage</BOLD> to all enemy units.",
                false, false
            );
        !]]
        DrawStyledText = function(sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, ...)--TODO BUG FIX USe HTML parser, not this
            local eStyle        = _tStyles;

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
        --[[!
            @fqxn CFS.Classes.Forge.Methods.LoadStyles
            @desc Loads and initializes all FontStyle definitions for the active game.

            <p>
              Rebuilds the Forge style registry by loading FontStyle definitions from the
              game’s styles configuration. This method is invoked by the IDE during game
              or CardSet initialization and is <strong>not exposed to the UserEnv</strong>.
            </p>

            <h3>Behavior</h3>
            <ul>
              <li>Clears all previously loaded FontStyle entries.</li>
              <li>Enumerates style definitions from the styles configuration source.</li>
              <li>Creates and initializes FontStyle objects for each style.</li>
              <li>Performs an initial update pass to prepare fonts and metrics.</li>
              <li>Installs a controlled lookup table for style resolution at draw time.</li>
            </ul>

            <h3>Notes</h3>
            <ul>
              <li>This method is intended for IDE use only.</li>
              <li>It is not available to CardSet <code>Draw</code> scripts or other UserEnv code.</li>
              <li>Style lookup during drawing is performed via <code>Forge.STYLE</code>.</li>
            </ul>
        !]]
        PrepGame = function() --called when a game is loaded
            --purge the styles
            setmetatable(_tStyles, {});

            for k, v in pairs(_tStyles) do
                _tStyles[k] = nil;
            end

            --import the styles
            local pStyles = FS.Styles;

            --TODO check for file and other things...do error checsk later --THROW ERROR if not
            local tSections     = INIFile.GetSectionNames(pStyles);
            local tStyles       = {};

            table.sort(tSections);

            for nIndex, sStyleRaw in ipairs(tSections) do
                local sStyle = sStyleRaw:upper();
                tStyles[sStyle] = FontStyle.FromINI(pStyles, sStyle);
                --run the initial update --TODO BUG fix the FontStyle so it does this upon and creation so it doesn't need done here
                tStyles[sStyle]:Update();--TODO QUESTION WHY : and not . ?
            end

            --create and store the STYLE table
            local sErrorPrefix = "Error assigning new FontStyle in Forge.STYLE: ";

            local tStylesMeta = {
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
            };

            setmetatable(_tStyles, tStylesMeta);
        end,
        OnShow = function()

            --create the canvas
            if not (_bCanvasCreated) then
                local bCanvasCreated = Canvas.Create(_sCanvas);
                assert(bCanvasCreated, "Error in Forge, \"${game}\": Could not create canvas for object, \"${canvas}\"." % {game = "TODO GET GAME NAME", canvas = _sCanvas});
            end

            if not (_hWndCard) then
                _hWndCard = ProcSys.GetWindowHandle(PANE.MAIN);
            end

            --mouse event callback functions
            local function MouseUpdate(eEvent)

                if (eEvent.EventCode == CANVAS_MOUSE_MOVE) then
                    local nX     = floor(eEvent.Mouse.x * _CoVXW);
                    local nY     = floor(eEvent.Mouse.y * _CoVYH);
                    local nNegX  = floor(nX - _nCardWidth);
                    local nNegY  = floor(nY - _nCardHeight);
                    Paragraph.SetText(_sStatusMouseObject,      nX..", "..nY);
                    Paragraph.SetText(_sStatusMouseNegObject,   nNegX..", "..nNegY);

                elseif (eEvent.EventCode == CANVAS_MOUSE_LEFT_CLICK) then
                    Clipboard.CopyText(Paragraph.GetText(_sStatusMouseObject));

                elseif (eEvent.EventCode == CANVAS_MOUSE_RIGHT_CLICK) then
                    Clipboard.CopyText(Paragraph.GetText(_sStatusMouseNegObject));

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

            Page.StartTimer(_nRedrawTimerInterval,      _nRedrawTimerID);
        end,
        OnSize = function(nWindowWidth, nWindowHeight, nPageWidth, nPageHeight, nType)
            _nPageWidth     = nPageWidth;
            _nPageHeight    = nPageHeight;

            local tPos      = Window.GetPos(HWND_APP);
            local sSection  = "ForgeWindow";

            if not (_bForgeAutoSizing) then
                INIFile.SetValue(_pAppCFG, sSection, "Width", tostring(nWindowWidth));
                INIFile.SetValue(_pAppCFG, sSection, "Height", tostring(nWindowHeight));
                INIFile.SetValue(_pAppCFG, sSection, "X", tostring(tPos.X));
                INIFile.SetValue(_pAppCFG, sSection, "Y", tostring(tPos.Y));
            end

            local nStatusYStart = nPageHeight - _nStatusHeight;

            --build the rects
            local tStatusMouseRect = {
                x       = 0,
                y       = 0,
                width   = _nStatusMouseWidth,
                height  = _nStatusHeight,
            };

            local tStatusMouseNegRect = {
                x       = tStatusMouseRect.x + tStatusMouseRect.width,
                y       = 0,
                width   = _nStatusMouseWidth,
                height  = _nStatusHeight,
            };

            local tStatusRect = {
                x       = tStatusMouseNegRect.x + tStatusMouseNegRect.width,
                y       = 0,
                width   = nPageWidth - tStatusMouseRect.width - tStatusMouseNegRect.width,
                height  = _nStatusHeight,
            };

            local tOuter = {
                x       = 0,
                y       = _nStatusHeight,
                width   = nPageWidth,
                height  = nPageHeight - _nStatusHeight,
            };

            local tInner = {
                x       = 0,
                y       = 0,
                width   = _nCardWidth,
                height  = _nCardHeight,
            };

            local tRect = math.geometry.fitrect(tOuter, tInner, true);
            Input.SetSize(      _sCanvas,               tRect.width,                tRect.height);
            Input.SetPos(       _sCanvas,               tRect.x,                    tRect.y);
            Paragraph.SetSize(  _sStatusMouseObject,    tStatusMouseRect.width,     tStatusMouseRect.height);
            Paragraph.SetPos(   _sStatusMouseObject,    tStatusMouseRect.x,         tStatusMouseRect.y);
            Paragraph.SetSize(  _sStatusMouseNegObject, tStatusMouseNegRect.width,  tStatusMouseNegRect.height);
            Paragraph.SetPos(   _sStatusMouseNegObject, tStatusMouseNegRect.x,      tStatusMouseNegRect.y);
            Paragraph.SetSize(  _sStatusObject,         tStatusRect.width,          tStatusRect.height);
            Paragraph.SetPos(   _sStatusObject,         tStatusRect.x,              tStatusRect.y);

            --store (and locally update) the canvas size info
            local tSize     = Input.GetSize(_sCanvas);
            _nCanvasWidth   = tSize.Width;
            _nCanvasHeight  = tSize.Height;

            --update the CoVs
            _CoVXW = _nCardWidth    /   _nCanvasWidth;
            _CoVYH = _nCardHeight   /   _nCanvasHeight;

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
        SetDrawFunction = function(fDraw)

            if not (rawtype(fDraw) == "function") then
                error("Forge.SetDrawFunction: expected function at argument 1. Got "..rawtype(fDraw), 3);
            end

            _fDraw = fDraw;
        end,
        SetActiveCardSet = function(oCardSet)

            if not (type(oCardSet) == "CardSet") then
                --TODO THROW ERROR
            end

            _oActiveCardSet = oCardSet;
            _nCardWidth     = oCardSet.GetCardWidth();
            _nCardHeight    = oCardSet.GetCardHeight();
            _sCardSetName   = oCardSet.GetName();

            --(re)create the Forge images
            if (_hImage ~= null) then
                _hImage:Free();
            end

            if (_hImageExport ~= null) then
                _hImageExport:Free();
            end

            if (_hImageUtil ~= null) then
                _hImageUtil:Free();
            end

            _hImage,        _nImageID       = CreateImage(_hImage,         _nImageID);
            _hImageExport,  _nImageExportID = CreateImage(_hImageExport,   _nImageExportID);
            _hImageUtil,    _nImageUtilID   = CreateImage(_hImageUtil,     _nImageUtilID);
        end,
        UpdateStyles = function()

            for oStyle in pairs(_tStyles) do
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
