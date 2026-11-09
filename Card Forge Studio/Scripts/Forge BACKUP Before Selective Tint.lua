local function retainedAMSRenderer()
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
    isstring            = type.isstring;
local floor             = math.floor;
local clamp             = math.clamp;
local SanitizePath      = SanitizePath;

local File          = File;
    local FileDoesExist         = File.DoesExist;
local Color         = Color;
local Canvas        = Canvas;
local Clipboard     = Clipboard
    local ClipboardCopyText     = Clipboard.CopyText;
local Color         = Color;
    local ColorRGBA             = Color.RGBA;
local Drawing       = Drawing;
local DrawingFont   = DrawingFont;
local DrawingImage  = DrawingImage;
    local DrawingImageNew       = DrawingImage.New;
    local DrawingImageGetID     = DrawingImage.GetID
local FontStyle     = CFS.FontStyle
    local GetFontStyle          = FontStyle.Get;
local INIFile       = INIFile;
local Paragraph     = Paragraph;
    local ParagraphGetText      = Paragraph.GetText;
    local ParagraphSetText      = Paragraph.SetText;
local _pAppCFG      = FS.AppCFG;
--TODO FINISH
------------------------------------------------------------------- Colors
--TODO move all these settings to file AND add a LiveFileRepo...long after Beta, not critical
local _nColorWhite      = ColorRGBA(255, 255, 255, 255);
local _nColorBlack      = ColorRGBA(0, 0, 0, 255);
local _nColorClear      = ColorRGBA(0, 0, 0, 0)
local _nColorRuler      = ColorRGBA(240, 100, 100, 255);
local _nColorRulerBG    = ColorRGBA(255, 255, 255, 0)
local _nColorForgeBG    = ColorRGBA(51, 51, 51, 255)
------------------------------------------------------------------- Rulers
local _tHorRuler            = {--TODO static functions and variables to change these values
    Y           = 0,
    Width       = 825,
    MajorStep   = 100,
    MinorStep   = 25,
    MajorHeight = 16,
    MinorHeight = 10,
    Color       = _nColorRuler,
};
local _tVerRuler            = {--TODO static functions and variables to change these values
    X           = 0,
    HHeight     = 1125,
    MajorStep   = 100,
    MinorStep   = 25,
    MajorWidth  = 16,
    MinorWidth  = 10,
    Color       = _nColorRuler,
};
------------------------------------------------------------------- Lines and Guides
local _tCenterLines = {
    Color       = ColorRGBA(50, 50, 255, 255),
};
local _tHorGuide = {
    Color       = ColorRGBA(0, 255, 48, 255),
};
local _tVerGuide = {
    Color       = ColorRGBA(0, 255, 48, 255),
};
------------------------------------------------------------------- Deadcalls
local _fDraw        = function() end;      --NOTE: DO NOT REMOVE: dead functions in case initial user function is bad
local _fDrawBack    = function() end;
-------------------------------------------------------------------
local _nPageWidth           = -1;
local _nPageHeight          = -1;
-------------------------------------------------------------------
--set during Draw, used in DrawText, etc.
local _Object       = null;
local _D            = null;
local _InternalDC   = null;
-------------------------------------------------------------------
local _bAutoUpdateStyle = false;
------------------------------------------------------------------- Canvas Guides
local _nGuideHorY = -1; --start off canvas
local _nGuideVerX = -1; --start off canvas
------------------------------------------------------------------- Canvas Keyboard Modifiers
local _bIsAltDown       = false;
local _bIsControlDown   = false;
local _bIsShiftDown     = false;
------------------------------------------------------------------- Canvas Related
local _sCanvas              = FORGE_CANVAS_NAME;
local _bCanvasCreated       = false;
local _nCanvasWidth         = 100;
local _nCanvasHeight        = 100;
local _hWndCard             = false;
--local _bClearCanvasEachDraw = true; --TODO GET FROM INI OR MENU?!!!
------------------------------------------------------------------- Mouse & Status
local _sStatusObject            = FORGE_STATUS_NAME;
local _sStatusMouseObject       = FORGE_STATUS_MOUSE_NAME;
local _sStatusMouseNegObject    = FORGE_STATUS_MOUSE_NEG_NAME;
local _nStatusHeight            = 50;  --applies to all status par objects
local _nStatusMouseWidth        = 180; --applies to both mouse status par objects
local _sStatus                  = "";
------------------------------------------------------------------- CoV Values
local _CoVXW = 1;
local _CoVYH = 1;
------------------------------------------------------------------- Draw Plugin Images
local _hImage           = false;
local _nImageID         = false;
--local _hImageBack       = null;
--local _nImageBackID     = null;
local _hImageExport     = false;
local _nImageExportID   = false;
local _hImageUtil       = false;
local _nImageUtilID     = false;
------------------------------------------------------------------- user Images
local _tUserImageCache  = {};
------------------------------------------------------------------- Card Info
local _oActiveCardSet = false;
local _nCardWidth     = 100;
local _nCardHeight    = 100;
local _sCardSetName   = "";
------------------------------------------------------------------- Redraw & Filesync
local _bRedrawUtil              = true; --is set to true so the Util redraws on first pass by default
local _bRedrawCard              = true;
local _bDrawBack                = false;
local _bRedrawCanvas            = false;
local _bUtilVisible             = true;
local _tActiveRow               = false;
local _bIsResizing              = false;
local _bForgeAutoSizing         = false;
local _nTimeDelta               = 0;
local _bDrawBlocked             = false;
local _bDrawTimerBusy           = false;
local _nSizingDelta             = FORGE_REDRAW_SIZING_INTERVAL;
local _nRedrawTimerID           = FORGE_REDRAW_TIMER_ID;
local _nRedrawTimerInterval     = FORGE_REDRAW_TIMER_INTERVAL;
-------------------------------------------------------------------


local function Export(tExports)

end


local function ImageLoadError(sPath, sName, sMsg)
    error("Error in Forge.LoadImage:\r\nError loading card image at path: \""..sPath.."\" with name, \""..sName.."\"."..#sName.."\r\n"..sMsg, 4);
end

local function LoadImage(sPath, sName)
    --TODO assertions
    if not (FileDoesExist(sPath)) then
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

        local nID = DrawingImageGetID(hImage);

        if not (nID) then
            ImageLoadError(sPath, sName, "Image ID not retrieved DrawingImage.GetID().");
        end

        _tUserImageCache[sPath].ID = nID;
    end

    return _tUserImageCache[sPath].Handle, _tUserImageCache[sPath].ID;

end

local function ClearImage(D)
    D.SetFilteringMode(DRAW_BLEND_ALLCHANNELS);
    D.DrawRectangle(0, 0, _nCardWidth, _nCardHeight, _nColorClear);
    --D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
end

local function CreateImage(hImage, nImageID)
    local hRet          = hImage;
    local nRet          = nImageID;
    local sMessage;
    local sBaseError    = "Forge.CreateImage (private static): Could not";

    --create the image only if it's not already been created
    if not (hImage and nImageID) then
        --create, check, and store the image handle
        hRet        = DrawingImageNew(_nCardWidth, _nCardHeight, BIT_DEPTH_32, DRAW_IMAGE_TRANSPARENT);
        sMessage    = sBaseError.." create image for canvas object, \"${canvas}\".";
        assert(hRet, sMessage % {canvas = _sCanvas});

        --get, check, and store the image ID
        nRet        = DrawingImageGetID(hRet);
        sMessage    = sBaseError.." get image ID for canvas object, \"${canvas}\" having image handle, ${handle}.";
        assert(nRet, sMessage % {canvas = _sCanvas, handle = tostring(hRet) or "nil"});
    end

    return hRet, nRet;
end

--[[TODO add
Draw X
Draw Grid
Guides
]]

--TODO add Grid lines util

local function DrawGuideHor(sObject, D, hInternalDC)--TODO ALlowwidth changes for these (and all) lines
    D.DrawLineEx(0, _nGuideHorY, _nCardWidth, _nGuideHorY, _tHorGuide.Color);
end

local function DrawGuideVer(sObject, D, hInternalDC)
    D.DrawLineEx(_nGuideVerX, 0, _nGuideVerX, _nCardHeight, _tVerGuide.Color);
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
            GetFontStyle("RULER").Draw(sObject, D, hInternalDC, floor(Forge.CenterOnX(nX, nTextWidth)), floor(nTextY), sX);
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
    local oRulerFS       = GetFontStyle("RULER");

    local nYMax = _nCardHeight - 1;

    D.DrawLineEx(nX, 0, nX, nYMax, oColor);
    D.SetDrawingFont(oRulerFS.GetFont());--TODO FIX This must be gotten from the Forge...why?

    for nY = 0, nYMax, nMinorStep do
        local nWidth        = (nY % nMajorStep == 0) and nMajorWidth or nMinorWidth;
        local nLineLength   = nX + nWidth;

        --draw the line
        D.DrawLineEx(nX, nY, nLineLength, nY, oColor);

        --draw the position text
        if (nY > 0) then
            local sY = tostring(nY);
            local nTextHeight = D.GetTextHeight(sY);
            oRulerFS.Draw(sObject, D, hInternalDC, floor(nTextX), floor(Forge.CenterOnY(nY, nTextHeight)), sY);
        end

    end

end




local function DrawUtilObjects(sObject, D, hInternalDC)
    ClearImage(D);

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

    --TODO FINISH add options to turn these off and be sure to save them in INI when changed
    DrawGuideHor(sObject, D, hInternalDC);

    DrawGuideVer(sObject, D, hInternalDC);

end



--mouse event callback functions
local function CanvasInputCallback(tEvent)
    local nEventCode = tEvent.EventCode;

    --update basic info
    local nX     = floor(tEvent.Mouse.x * _CoVXW);
    local nY     = floor(tEvent.Mouse.y * _CoVYH);
    local nNegX  = floor(nX - _nCardWidth);
    local nNegY  = floor(nY - _nCardHeight);

    _bIsAltDown     = tEvent.Keyboard.Modifiers.Alt;
    _bIsControlDown = tEvent.Keyboard.Modifiers.Control;
    _bIsShiftDown   = tEvent.Keyboard.Modifiers.Shift;

    if (nEventCode == CANVAS_MOUSE_MOVE) then
        ParagraphSetText(_sStatusMouseObject,      nX..", "..nY);
        ParagraphSetText(_sStatusMouseNegObject,   nNegX..", "..nNegY);

    --[[!
        @fqxn CFS.Bindings.Left-Click
        @desc Left-clicking the canvas copies the X and Y coordinates to the clipboard as "X, Y".
    !]]
    elseif (nEventCode == CANVAS_MOUSE_LEFT_CLICK) then

        --[[!
            @fqxn CFS.Bindings.Left-Click_+_Control
            @desc Holding Control and Left-clicking the canvas places a horizontal guide at clicked location and copies the Y coordinate and -Y (Y − CardHeight) to the clipboard as "Y, -Y".
        !]]
        if _bIsControlDown and not _bIsShiftDown then
            _nGuideHorY         = floor(tEvent.Mouse.y * _CoVYH);
            _bRedrawUtil        = true;
            _bRedrawCanvas      = true;
            ClipboardCopyText(nY..", "..nNegY);

        --[[!
            @fqxn CFS.Bindings.Left-Click_+_Control_+_Shift
            @desc Holding Control and Shift and Left-clicking the canvas removes the horizontal guide and copies the X and Y coordinates to the clipboard as "X, Y".
        !]]
        elseif _bIsControlDown and _bIsShiftDown and _nGuideHorY > -1 then
            _nGuideHorY         = -100;
            _bRedrawUtil        = true;
            _bRedrawCanvas      = true;
            ClipboardCopyText(ParagraphGetText(_sStatusMouseObject));

        else
            ClipboardCopyText(ParagraphGetText(_sStatusMouseObject));
        end

    --[[!
        @fqxn CFS.Bindings.Right-Click
        @desc Left-clicking the canvas copies the -X (X - CardWidth) and -Y (Y - CardHeight) coordinates to the clipboard as "-X, -Y".
    !]]
    elseif (nEventCode == CANVAS_MOUSE_RIGHT_CLICK) then

        --[[!
            @fqxn CFS.Bindings.Right-Click_+_Control
            @desc Holding Control and Right-clicking the canvas places a vertical guide at clicked location and copies the X coordinate and -X (X − CardWidth) to the clipboard as "X, -X".
        !]]
        if _bIsControlDown and not _bIsShiftDown then
            _nGuideVerX         = floor(tEvent.Mouse.x * _CoVXW);
            _bRedrawUtil        = true;
            _bRedrawCanvas      = true;
            ClipboardCopyText(nX..", "..nNegX);

        --[[!
            @fqxn CFS.Bindings.Right-Click_+_Control_+_Shift
            @desc Holding Control and Shift and Right-clicking the canvas removes the vertical guide and copies the X and Y coordinates to the clipboard as "X, Y".
        !]]
        elseif _bIsControlDown and _bIsShiftDown and _nGuideVerX > -1 then
            _nGuideVerX         = -100;
            _bRedrawUtil        = true;
            _bRedrawCanvas      = true;
            ClipboardCopyText(ParagraphGetText(_sStatusMouseNegObject));

        else
            ClipboardCopyText(ParagraphGetText(_sStatusMouseNegObject));
        end

    --[[!
        @fqxn CFS.Bindings.Middle-Click
        @desc Middle-clicking the canvas copies the X and Y coordinates to the clipboard as "X, Y".
    !]]
    elseif (nEventCode == CANVAS_MOUSE_MIDDLE_DOWN) then

        --[[!
            @fqxn CFS.Bindings.Middle-Click_+_Control
            @desc Holding Control and Middle-clicking the canvas places a both a vertical and horizontal guide at clicked location and copies the X and Y coordinates to the clipboard as "X, Y".
        !]]
        if _bIsControlDown and not _bIsShiftDown then
            _nGuideVerX         = floor(tEvent.Mouse.x * _CoVXW);
            _nGuideHorY         = floor(tEvent.Mouse.y * _CoVYH);
            _bRedrawUtil        = true;
            _bRedrawCanvas      = true;
            ClipboardCopyText(nX..", "..nY);

        --[[!
            @fqxn CFS.Bindings.Middle-Click_+_Control_+_Shift
            @desc Holding Control and Shift and Middle-clicking the canvas removes both the vertical and horizontal guide and copies the X and Y coordinates to the clipboard as "X, Y".
        !]]
        elseif _bIsControlDown and _bIsShiftDown and (_nGuideVerX > -1 or _nGuideHorY > -1) then
            _nGuideVerX         = -100;
            _nGuideHorY         = -100;
            _bRedrawUtil        = true;
            _bRedrawCanvas      = true;
            ClipboardCopyText(nX..", "..nY);

        else
            ClipboardCopyText(ParagraphGetText(_sStatusMouseObject));
        end

    elseif (nEventCode == CANVAS_KEYBOARD_KEY_DOWN) then

        if (tEvent.Keyboard.Key == KEY_CODES.left.dec) then

            if (_bDrawBack) then
                _bDrawBack      = false;
                _bRedrawCard    = true;
                _bRedrawCanvas  = true;
            end

        elseif (tEvent.Keyboard.Key == KEY_CODES.right.dec) then

            if not (_bDrawBack) then
                _bDrawBack      = true;
                _bRedrawCard    = true;
                _bRedrawCanvas  = true;
            end

        end

    end

end
--TODO FINISH ADD Convas.Focus on mouse over window
--[[!
    @fqxn CFS.Classes.Forge.Methods.Draw
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
local function Draw()--, bExport, fExport) --TODO move this out to private static to be used here and in new export function
    --in case a resize happens
    --_tActiveRow  = tRow;
    if (_nImageID) then

        --draw the card
        local function ProcDraw(sObject, D, hInternalDC)
            ClearImage(D);

            D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);

            --update private vars for use in DrawText and other functions
            _Object      = sObject;
            _D           = D;
            _InternalDC  = hInternalDC;

            --execute the proc's draw method
            if (_bDrawBack) then
                _fDrawBack(sObject, D, hInternalDC);
            else
                _fDraw(sObject, D, hInternalDC);
            end

        end

        --reset the image size to its original size
        --hImage:Resize(nWidth, nHeight, DRAW_RESIZE_RAW);

        --clear the canvas
        --if (_bClearCanvasEachDraw) then
            Canvas.Clear(_sCanvas, _nColorClear); --TODO MOVE TO UTIL ON/OFF
        --end

        --draw on the card image
        if (_bRedrawCard) then
            _bRedrawCard = false;
            _hImage:Draw(ProcDraw);
        end

        --draw on the util image
        if (_bRedrawUtil) then
            _bRedrawUtil = false;
            _hImageUtil:Draw(DrawUtilObjects);
        end

        --draw the card and util images onto the canvas (since drawing directly on the canvas is no bueno)
        Canvas.Draw(_sCanvas,
            function(sObject, D, hInternalDC)
                D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
                D.DrawImage(_nImageID, 0, 0, _nCanvasWidth, _nCanvasHeight);

                if MainMenu.IsChecked("Options:>Draw:>Utility Overlay") then--TODO FINISH Break this OUt of here so util and card can be drawn seperately and composited in a nother function...this will fix having to redraw the card whenever the util changes
                    D.DrawImage(_nImageUtilID, 0, 0, _nCanvasWidth, _nCanvasHeight);
                end

            end
        );
        --Page.Redraw();
        --if (bExport and fExport and type(fExport) == "function") then --TODO DO NOT CALL THIS HERE>..each export should not be displayed first
        --    fExport(D, hImage, cProc, tRow); --TODO FINISH PCALL this and send erros to status
        --end

        --[[
        --saves the entire canvas!
        local hNew = Canvas.GrabImage(_sCanvas);
        if(hNew)then
            DrawingImage.Save(hNew, tRow.Name..".png", DRAW_FORMAT_PNG);
            DrawingImage.Free(hNew);
        end]]

    end

end



local function UpdatePageLayout()

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
        width   = _nPageWidth - tStatusMouseRect.width - tStatusMouseNegRect.width,
        height  = _nStatusHeight,
    };

    local tOuter = {
        x       = 0,
        y       = _nStatusHeight,
        width   = _nPageWidth,
        height  = _nPageHeight - _nStatusHeight,
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
end

local function XPCallError(vErr)
    return debug.traceback(tostring(vErr), 2);
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
    @fqxn CFS.Modules.Forge
    @desc
<section aria-label="Forge overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Forge</h2><p style="font-size:1.15rem;margin:0">Forge is the visual workbench that turns selected card data and drawing instructions into artwork.</p></div>
<h3>How it fits into your work</h3><p>Select a card and inspect its front or back. Adjust drawing scripts while guides and rulers help with placement. Canvas colors make the workspace comfortable.</p>
<figure style="margin:1.5rem 0"><figcaption style="font-weight:700;margin-bottom:.8rem">The big picture</figcaption><div role="img" aria-label="Selected card then Draw or DrawBack then Rendered bitmap then Preview or PNG" style="display:flex;flex-wrap:wrap;align-items:center;gap:.7rem"><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Selected card</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Draw or DrawBack</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Rendered bitmap</span><span aria-hidden="true" style="color:var(--accent)">→</span><span style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0">Preview or PNG</span></div></figure>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">ProcSys supplies the active set, selected row, and front/back drawing callbacks.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.UserEnv">User Environment</a></h3><p style="margin:0">User drawing scripts run with the game’s shared values and the exposed drawing functions.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.FontStyle">Font Style</a></h3><p style="margin:0">Styled text drawing looks up reusable game text styles.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Exporter.Exporters.ExporterPNG">PNG Export</a></h3><p style="margin:0">PNG export requests card images from Forge; preview guides are kept out of those images.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Options">Options</a></h3><p style="margin:0">Forge’s linked Options section controls surrounding Background, Card Canvas, Guides, and Preview preferences.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Guides and Card Canvas colors are preview aids, not exported artwork. Missing-image fallback runs only when a drawing call requests a missing image.</p></aside>
<h3>Artwork versus working aids</h3><p>The card’s drawing script decides what becomes artwork: images, shapes, and text. Guides, rulers, and preview canvas colors help you place and inspect that artwork. Keeping those jobs separate lets you make the workbench comfortable without accidentally changing the exported card.</p>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]
return class("Forge",
    {--METAMETHODS
    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Forge = function(cForge, sAuthCode) end, --static constructor (runs after class object creation)
        LoadImage = LoadImage,
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
        CenterOn = function(nX, nY) --TODO FINISH

        end,
        --[[!
            @fqxn CFS.Modules.Forge.Functions.DrawImage
            @pulsarlua function Forge.DrawImage
            @desc Draws an image onto the active card render target.

            <p>
              Loads (or retrieves from cache) an image from the active game directory and draws it
              into the current card draw context. This function is primarily intended for use by
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
              <li>This function must be called from within an active card draw pass.</li>
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
        DrawImage = function(pImage, nX, nY, nWidth, nHeight, sName)--TODO REMOVE THIS....user can load image as needed this is merely a shortcut and a problematic
            --TODO assertions
            local hImage, nImage = LoadImage(FS.Game.Root.."\\"..SanitizePath(pImage, pImage), sName);
            --_D.SetFilteringMode(DRAW_BLEND_ALPHABLEND);
            _D.DrawImage(nImage, nX, nY, nWidth, nHeight);
        end,
        --[[!
            @fqxn CFS.Modules.Forge.Functions.DrawText
            @pulsarlua function Forge.DrawText
            @desc Draws plain text onto the active card render target using a single style.

            <p>
              Renders text using the specified FontStyle during the active card draw pass.
              This function is intended for use by CardSet <code>Draw</code> scripts and supports
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
            local fWrap         = rawtype(vWrap)        == "function"   and vWrap       or false;
            local bCenterX      = rawtype(vCenterX)     == "boolean"    and vCenterX    or false;
            local bCenterY      = rawtype(vCenterY)     == "boolean"    and vCenterY    or false;
            local oStyle        = GetFontStyle(sStyle); --TODO add default style as fallback???
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
            @fqxn CFS.Modules.Forge.Functions.DrawStyledText
            @pulsarlua function Forge.DrawStyledText
            @desc Draws text containing inline style markup onto the active card render target.

            <p>
              Renders text that includes inline style tags (e.g. <code>&lt;BOLD&gt;</code>,
              <code>&lt;ITALIC&gt;</code>) using multiple FontStyles in a single draw call.
              This function is intended for CardSet <code>Draw</code> scripts that require
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
            local fWrap         = rawtype(vWrap)        == "function"   and vWrap       or false;
            local bCenterX      = rawtype(vCenterX)     == "boolean"    and vCenterX    or false;
            local bCenterY      = rawtype(vCenterY)     == "boolean"    and vCenterY    or false;

            --------------------------------------------------------------------
            -- PARSE HELPERS
            --------------------------------------------------------------------
            --[[!
            @fqxn CFS.Modules.Forge.Private.Functions.BuildRuns
            @desc Splits styled text into drawing runs and accumulated plain text.
            @param any sIn Value supplied as sIn.
            @vis private
            !]]
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
                    local use = GetFontStyle(tag) and tag or sStyle;

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
                local oDef = GetFontStyle(sStyle);
                if (oDef and oDef.Update) then
                    oDef.Update();
                end

                for _, r in ipairs(tRunsSrc) do
                    local o = GetFontStyle(r.Style);
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
                local oDef = GetFontStyle(sStyle);
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
                    local oStyle = GetFontStyle(seg.Style) or GetFontStyle(sStyle);
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
                    local oStyle = GetFontStyle(seg.Style) or GetFontStyle(sStyle);
                    local sPart  = seg.Text;

                    oStyle.Prep(_D, sPart, false);

                    local nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(_D, sPart, true);

                    -- KEY FIX:
                    -- draw so that the ink-box starts at nX (neutralizes negative bearings / kerning tuck)
                    local nDrawX = nX - (nMinX or 0);
                    local nDrawY = nLineY;

                    --TEST (keep it, but make it match the real ink-box)
                    --local R = math.random;
                    --D.DrawRectangle(floor(nX), floor(nY), floor(nTotalW), floor(nTotalH), ColorRGBA(R(1, 255),R(1, 255),R(1, 255),60));
                    --TEST

                    oStyle.Draw(_Object, _D, _InternalDC, floor(nDrawX), floor(nDrawY), sPart, vAngle);

                    nX = nX + nTotalW + nPadX;
                end

                nY = nY + (tInfo.H or 0);
            end

            return nBaseX, nBaseY, nBlockW, nBlockH;
        end,
        OnShow = function()
            --local nV = KEY_CODES.v.dec;
            --local nH = KEY_CODES.h.dec;

            --create the canvas
            if not (_bCanvasCreated) then
                local bCanvasCreated = Canvas.Create(_sCanvas, {Keyboard = true});
                assert(bCanvasCreated, "Error in Forge, \"${game}\": Could not create canvas for object, \"${canvas}\"." % {game = "TODO GET GAME NAME", canvas = _sCanvas});
                _bCanvasCreated = true; --TODO QUESTION does the canvas need created everytime the page loads? If os, remove this flag entirely.
            end

            if not (_hWndCard) then
                _hWndCard = ProcSys.GetWindowHandle(PANE.MAIN);
            end

            Canvas.SetCallback(_sCanvas, CanvasInputCallback);

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

            Page.StartTimer(_nRedrawTimerInterval, _nRedrawTimerID);
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

            --local nStatusYStart = nPageHeight - _nStatusHeight;

            UpdatePageLayout();

            if (_tActiveRow) then
                _bRedrawCanvas = true;
                _bIsResizing   = true;
            end

        end,
        --STYLE = null, --public enum --TODO Does it need to be public still? It gets injected into the userenv so why make it public?
        OnTimer = function(nID)

            if (nID ~= _nRedrawTimerID or _bDrawBlocked or _bDrawTimerBusy) then
                return;
            end

            _bDrawTimerBusy = true;

            local bOK, sErr = xpcall(function()
                --increment the delta time
                _nTimeDelta = _nTimeDelta + _nRedrawTimerInterval;

                --check if a redraw request was made and that we're done resizing
                if (_bRedrawCanvas and not _bIsResizing) then
                    --Log.Note("Redraw")
                    --redraw the card
                    Draw();
                    --fulfill the request
                    _bRedrawCanvas = false;--TODO QUESTION should this be above?
                end

                --if enough time has passed...
                if (_nTimeDelta >= _nSizingDelta) then
                    --...indicate resizing has stopped
                    _bIsResizing = false;
                    --...and reset the time delta
                    _nTimeDelta = 0;
                end
            end, XPCallError);

            _bDrawTimerBusy = false;

            if not (bOK) then
                error(sErr, 0);
            end

        end,
        RequestCardRedraw = function()
            _bRedrawCard    = true;
            _bRedrawCanvas  = true;
        end,
        RequestUtilRedraw = function()
            _bRedrawUtil    = true;
            _bRedrawCanvas  = _bUtilVisible;
        end,
        SetDrawFunction = function(fDraw)

            if not (rawtype(fDraw) == "function") then
                error("Forge.SetDrawFunction: expected function at argument 1. Got "..rawtype(fDraw), 3);
            end

            _fDraw = fDraw;
        end,
            SetDrawBackFunction = function(fDrawBack)

            if not (rawtype(fDrawBack) == "function") then
                error("Forge.SetDrawBackFunction: expected function at argument 1. Got "..rawtype(fDrawBack), 3);
            end

            _fDrawBack = fDrawBack;
        end,
        SetActiveRow = function(tRow)
            --TODO ASSERTIONS
            if (type(tRow) == "FinalRow") then
                _tActiveRow = tRow;
            end

        end,
        SetActiveCardSet = function(oCardSet)

            if not (type(oCardSet) == "CardSet") then
                error("Forge.SetActiveCardSet: Expected type CardSet. Got "..type(oCardSet)..'.');
            end

            _oActiveCardSet = oCardSet;
            _nCardWidth     = oCardSet.GetCardWidth();
            _nCardHeight    = oCardSet.GetCardHeight();
            _sCardSetName   = oCardSet.GetName();

            --(re)create the Forge images
            if (_hImage) then
                _hImage:Free();
                _hImage     = false;
                _nImageID   = false;
            end

            if (_hImageExport) then
                _hImageExport:Free();
                _hImageExport   = false;
                _nImageExportID = false;
            end

            if (_hImageUtil) then
                _hImageUtil:Free();
                _hImageUtil     = false;
                _nImageUtilID   = false;
            end

            _hImage,        _nImageID       = CreateImage(_hImage,         _nImageID);
            _hImageExport,  _nImageExportID = CreateImage(_hImageExport,   _nImageExportID);
            _hImageUtil,    _nImageUtilID   = CreateImage(_hImageUtil,     _nImageUtilID);

            UpdatePageLayout();
        end,
        --[[SetClearCanvasEachDraw = function(vFlag)
            _bClearCanvasEachDraw = rawtype(vFlag) == "boolean" and vFlag or false;
        end,]]
        SetDrawEnabled = function(vFlag)
            _bDrawBlocked = not (rawtype(vFlag) == "boolean" and vFlag or false);
        end,
        --[[SetDrawSide = function(nDrawside)
            type.assert.number(nDrawside, true, false, false, true, false, 0, 1);
            _bDrawBack = #nDrawside; --draws front on 0, back on 1
        end,]]
        SetUtilVisible = function(vFlag)
            _bUtilVisible = rawtype(vFlag) == "boolean" and vFlag or false;
            _bRedrawCanvas  = true;
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

end
-- Live WX renderer. Card pixels are rebuilt only when their dirty flag is set.
-- The retained AMS implementation below documents the original UI and export paths.
-- TODO Port export targets and ruler settings from the retained implementation.
local wx            = require("wx");
local FontStyle     = CFS.FontStyle;
local GetFontStyle  = FontStyle.Get;
local floor         = math.floor;
local Forge         = {};
--Native graphics surfaces follow their source bitmap lifetimes.
local _tGraphicsBitmaps = setmetatable({}, {__mode = "k"});
local _tImages      = {};
local _tActiveRow;
local _oBitmap;
local _D, _Object, _InternalDC;
local _fDraw, _fDrawBack;
local _bAutoUpdateStyle = false;
local _bRedrawCard   = false;
local _bRedrawUtil   = false;
local _bRedrawCanvas = false;
local _bDrawBlocked  = false;
local _bDrawBusy     = false;
local _bDrawBack     = false;
local _nWidth       = 1;
local _nHeight      = 1;
local _nRevision    = 0;
local _oAssetClock  = wx.wxStopWatch();

--[[!
@fqxn CFS.Modules.Forge.Private.Functions.nativeColour
@desc Converts a packed RGBA number to a native color or passes through an existing native color value.
@param any vColour Value supplied as vColour.
@vis private
!]]
local function nativeColour(vColour)
    if (rawtype(vColour) == "number") then
        return wx.wxColour((vColour >> 24) & 255, (vColour >> 16) & 255, (vColour >> 8) & 255, vColour & 255);
    end
    return vColour;
end

--[[!
@fqxn CFS.Modules.Forge.Private.Functions.drawingContext
@desc Adapts graphics and device contexts to the drawing callbacks used by card scripts.
@param any oGC Value supplied as oGC.
@param any oDC Value supplied as oDC.
@vis private
!]]
local function drawingContext(oGC, oDC)
    local tContext = {};
    local oFont    = wx.wxNORMAL_FONT;
    local oColour  = wx.wxBLACK;

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_SetDrawingFont
    @desc Installs the drawing font in both native contexts.
    @param any oNewFont Value supplied as oNewFont.
    @vis private
    !]]
    function tContext.SetDrawingFont(oNewFont)
        oFont = oNewFont;
        oGC:SetFont(oFont, oColour);
        oDC:SetFont(oFont);
    end

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_SetFilteringMode
    @desc Compatibility hook; native alpha composition is already configured.
    @vis private
    !]]
    function tContext.SetFilteringMode()
        -- WX graphics context uses alpha composition for the card layer.
    end

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_GetTextWidth
    @desc Returns the native measured width of text converted to a string.
    @param any sText Value supplied as sText.
    @vis private
    !]]
    function tContext.GetTextWidth(sText)
        local nWidth = oGC:GetTextExtent(tostring(sText));
        return nWidth;
    end

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_GetTextHeight
    @desc Returns the native measured height of text converted to a string.
    @param any sText Value supplied as sText.
    @vis private
    !]]
    function tContext.GetTextHeight(sText)
        local nWidth, nHeight = oGC:GetTextExtent(tostring(sText));
        return nHeight;
    end

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_DrawText
    @desc Sets the supplied text color and draws an unrotated text string.
    @param any nX Value supplied as nX.
    @param any nY Value supplied as nY.
    @param any sText Value supplied as sText.
    @param any oTextColour Value supplied as oTextColour.
    @vis private
    !]]
    function tContext.DrawText(nX, nY, sText, oTextColour)
        oColour = nativeColour(oTextColour) or oColour;
        oGC:SetFont(oFont, oColour);
        oGC:DrawText(tostring(sText), nX, nY);
    end

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_DrawAngledText
    @desc Sets the supplied text color and draws text rotated by the supplied angle in degrees.
    @param any nX Value supplied as nX.
    @param any nY Value supplied as nY.
    @param any sText Value supplied as sText.
    @param any nAngle Value supplied as nAngle.
    @param any oTextColour Value supplied as oTextColour.
    @vis private
    !]]
    function tContext.DrawAngledText(nX, nY, sText, nAngle, oTextColour)
        oColour = nativeColour(oTextColour) or oColour;
        oGC:SetFont(oFont, oColour);
        oGC:DrawText(tostring(sText), nX, nY, math.rad(nAngle or 0));
    end

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_DrawRectangle
    @desc Draws a filled rectangle without an outline.
    @param any nX Value supplied as nX.
    @param any nY Value supplied as nY.
    @param any nWidth Value supplied as nWidth.
    @param any nHeight Value supplied as nHeight.
    @param any oFill Value supplied as oFill.
    @vis private
    !]]
    function tContext.DrawRectangle(nX, nY, nWidth, nHeight, oFill)
        oGC:SetPen(wx.wxTRANSPARENT_PEN);
        oGC:SetBrush(wx.wxBrush(nativeColour(oFill)));
        oGC:DrawRectangle(nX, nY, nWidth, nHeight);
    end

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_DrawTextBackground
    @desc Draws a padded text background in a temporarily translated and rotated graphics state.
    @param any nX Value supplied as nX.
    @param any nY Value supplied as nY.
    @param any nWidth Value supplied as nWidth.
    @param any nHeight Value supplied as nHeight.
    @param any nPadding Value supplied as nPadding.
    @param any oFill Value supplied as oFill.
    @param any nAngle Value supplied as nAngle.
    @vis private
    !]]
    function tContext.DrawTextBackground(nX, nY, nWidth, nHeight, nPadding, oFill, nAngle)
        oGC:PushState();
        oGC:Translate(nX, nY);
        oGC:Rotate(-math.rad(nAngle));
        tContext.DrawRectangle(-nPadding, -nPadding, nWidth + 2 * nPadding, nHeight + 2 * nPadding, oFill);
        oGC:PopState();
    end
    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_WithScale
    @desc Draws one fitted line in a temporary graphics transform and restores it after errors.
    @vis private
    !]]
    function tContext.WithScale(nX, nY, nScale, fDraw)
        oGC:PushState();
        oGC:Translate(nX, nY);
        oGC:Scale(nScale, nScale);
        local bOK, vError = pcall(fDraw);
        oGC:PopState();
        if (not bOK) then error(vError, 0); end
    end

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_GetOutputInfo
    @desc Returns native card width and height to drawing scripts.
    @vis private
    !]]
    function tContext.GetOutputInfo()
        return {Width = _nWidth, Height = _nHeight,};
    end

    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.tContext_DrawImage
    @desc Draws a bitmap using supplied dimensions or its native dimensions.
    @param any oImage Value supplied as oImage.
    @param any nX Value supplied as nX.
    @param any nY Value supplied as nY.
    @param any nWidth Value supplied as nWidth.
    @param any nHeight Value supplied as nHeight.
    @vis private
    !]]
    function tContext.DrawImage(oImage, nX, nY, nWidth, nHeight, bCacheSurface)
        --Direct callers may mutate their wxBitmap. Only Forge-owned immutable images opt in.
        if (not bCacheSurface) then
            oGC:DrawBitmap(oImage, nX, nY, nWidth or oImage:GetWidth(), nHeight or oImage:GetHeight());
            return;
        end
        local oSurface = _tGraphicsBitmaps[oImage];
        if (not oSurface) then
            oSurface = oGC:CreateBitmap(oImage);
            _tGraphicsBitmaps[oImage] = oSurface;
        end
        oGC:DrawBitmap(oSurface, nX, nY, nWidth or oImage:GetWidth(), nHeight or oImage:GetHeight());
    end

    return tContext;
end

--[[!
@fqxn CFS.Modules.Forge.Private.Functions.resolveImage
@desc Validates a game-relative image path and selects the bundled missing-image fallback when needed.
@param any sRelative Value supplied as sRelative.
@vis private
!]]
local function resolveImage(sRelative)
    assert(rawtype(sRelative) == "string", "Image path must be a string.");
    local sPath = sRelative:gsub("\\", "/");
    assert(not sPath:match("^/") and not sPath:find(":", 1, true), "Image path must be relative to the game.");
    local tParts = {};

    for sPart in sPath:gmatch("[^/]+") do
        if (sPart == "..") then
            assert(#tParts > 0, "Image path leaves the game folder.");
            tParts[#tParts] = nil;
        elseif (sPart ~= ".") then
            tParts[#tParts + 1] = sPart;
        end
    end

    return io.normalizepath(FS.GetResourceRoot().."/"..table.concat(tParts, "/"));
end

--[[!
@fqxn CFS.Modules.Forge.Private.Functions.imageStamp
@desc Builds an image modification signature or returns the missing-file marker.
@param any pFile Value supplied as pFile.
@vis private
!]]
local function imageStamp(pFile)
    local oFile = wx.wxFileName(pFile);
    local oTime = oFile:GetModificationTime();
    if (not oTime:IsValid()) then return "missing" end
    return tostring(oTime:GetTicks())..":"..tostring(oTime:GetMillisecond())..":"..oFile:GetSize():ToString();
end

--[[!
@fqxn CFS.Modules.Forge.Private.Functions.checkImages
@desc Checks cached image signatures at the monitoring interval and requests redraw when artwork changes.
@vis private
!]]
local function checkImages()
    if (_oAssetClock:Time() < PROCSYS_LIVE_FILE_REPO_TIMER_INTERVAL) then return end
    _oAssetClock:Start();
    for pFile, tImage in pairs(_tImages) do
        if (imageStamp(pFile) ~= tImage.stamp) then
            _tImages[pFile] = nil;
            Forge.RequestCardRedraw();
        end
    end
end

--[[!
@fqxn CFS.Modules.Forge.Functions.DrawImage
@pulsarlua function Forge.DrawImage
@desc Draws an image onto the active card render target.

<p>
  Loads (or retrieves from cache) an image from the active resource root and draws it
  into the current card draw context. This function is primarily intended for use by
  CardSet <code>Draw</code> scripts, but may also be used internally by the Forge.
</p>

<h3>Behavior</h3>
<ul>
  <li>Resolves the image path relative to the active resource root.</li>
  <li>Sanitizes the provided path to prevent invalid or unsafe access.</li>
  <li>Caches image handles to avoid redundant loads across draw calls.</li>
  <li>Draws the image using alpha blending.</li>
</ul>

<h3>Notes</h3>
<ul>
  <li>This function must be called from within an active card draw pass.</li>
  <li>Images are drawn into the card image layer, not the utility overlay layer.</li>
  <li>Repeated calls with the same image path reuse cached image handles.</li>
</ul>

@param string sPath Image path relative to the active resource root.
@param number nX Horizontal card-space position.
@param number nY Vertical card-space position.
@param number nWidth Optional draw width; defaults to the native image width.
@param number nHeight Optional draw height; defaults to the native image height.
@ret void none No values returned.

@ex
-- Draw an image asset onto the card at a fixed position
local pOgre = "Images/Ogre.png";
Forge.DrawImage(pOgre, 100, 100, 32, 32);
        !]]
function Forge.DrawImage(sPath, nX, nY, nWidth, nHeight)
    assert(_D, "Forge drawing is only available during a render pass.");
    local pImage = resolveImage(sPath);

    -- Missing artwork uses the application placeholder in preview and export.
    -- Resolve the requested path first so invalid paths retain their validation.
    if (not wx.wxFileExists(pImage)) then
        pImage = io.normalizepath(APP_PATH.."/Images/Missing.png");
    end

    local tImage = _tImages[pImage];
    local oImage = tImage and tImage.bitmap;

    if (not oImage) then
        assert(wx.wxFileExists(pImage), "Card image does not exist: "..pImage);
        oImage = wx.wxBitmap(pImage, wx.wxBITMAP_TYPE_ANY);
        assert(oImage:IsOk(), "Could not decode card image: "..pImage);
        _tImages[pImage] = {bitmap = oImage, stamp = imageStamp(pImage),};
    end

    _D.DrawImage(oImage, nX, nY, nWidth, nHeight, true);
end

-- Circular variants follow the source cache lifetime and never alter source artwork.
local _tCircularImages = setmetatable({}, {__mode = "k"});

--[[!
@fqxn CFS.Modules.Forge.Functions.DrawImageCircular
@pulsarlua function Forge.DrawImageCircular
@desc Draws a centered circular portrait during an active render pass. Resolves paths, missing artwork and source bitmaps using the existing image cache. Center-crops the source to a square, preserves its alpha and applies a softly antialiased circular edge. X/Y identify the circle center; diameter changes do not move that center. The optional diameter defaults to the smaller source dimension. One masked bitmap is cached per source record and reused at every draw size; source invalidation also releases its circular variant. Source files and other drawing calls are unchanged. Preview and PNG export use the same bitmap.
@param string sPath Image path relative to the active resource root.
@param number nX Horizontal center of the circle in card-space coordinates.
@param number nY Vertical center of the circle in card-space coordinates.
@param number nDiameter Optional positive finite circle diameter; defaults to the smaller source dimension.
@ret void none No values returned.
@error Requires an active render pass, a valid game-relative path and a positive finite diameter when supplied. Raises an error if image decoding or circular bitmap creation fails.
@ex
-- Keep the portrait centered while changing its size.
Forge.DrawImageCircular("Cards/Portrait.png", 412.5, 350, 500);
!]]
function Forge.DrawImageCircular(sPath, nX, nY, nDiameter)
    assert(_D, "Forge drawing is only available during a render pass.");
    assert(nDiameter == nil or rawtype(nDiameter) == "number" and nDiameter > 0 and nDiameter < math.huge, "Circle diameter must be a positive finite number.");
    local pImage = resolveImage(sPath);

    -- 1. Reuse the same path validation, missing-art fallback and source cache.
    if (not wx.wxFileExists(pImage)) then
        pImage = io.normalizepath(APP_PATH.."/Images/Missing.png");
    end

    local tImage = _tImages[pImage];

    if (not tImage) then
        assert(wx.wxFileExists(pImage), "Card image does not exist: "..pImage);
        local oBitmap = wx.wxBitmap(pImage, wx.wxBITMAP_TYPE_ANY);
        assert(oBitmap:IsOk(), "Could not decode card image: "..pImage);
        tImage = {bitmap = oBitmap, stamp = imageStamp(pImage),};
        _tImages[pImage] = tImage;
    end

    local oBitmap = _tCircularImages[tImage];

    if (not oBitmap) then
        local oImage = tImage.bitmap:ConvertToImage();
        local oSquare;
        local bOK, vError = xpcall(function()
            -- 2. Crop equally from opposite sides instead of stretching the portrait.
            local nSize = math.min(oImage:GetWidth(), oImage:GetHeight());
            oSquare = oImage:GetSubImage(wx.wxRect(floor((oImage:GetWidth() - nSize) / 2), floor((oImage:GetHeight() - nSize) / 2), nSize, nSize));
            if (not oSquare:HasAlpha()) then oSquare:InitAlpha(); end

            -- 3. Multiply existing alpha by circular coverage, retaining source holes.
            local sAlpha    = oSquare:GetAlpha();
            local nRadius   = nSize / 2;
            local tRows     = {};

            for nY = 0, nSize - 1 do
                local tAlpha = {};
                local nDY    = nY + 0.5 - nRadius;

                for nX = 0, nSize - 1 do
                    local nDX       = nX + 0.5 - nRadius;
                    local nCoverage = math.max(0, math.min(1, nRadius + 0.5 - math.sqrt(nDX * nDX + nDY * nDY)));
                    tAlpha[nX + 1]  = string.char(floor(sAlpha:byte(nY * nSize + nX + 1) * nCoverage + 0.5));
                end

                tRows[nY + 1] = table.concat(tAlpha);
            end

            oSquare:SetAlpha(table.concat(tRows));
            oBitmap = wx.wxBitmap(oSquare);
            assert(oBitmap:IsOk(), "Could not create circular card image: "..pImage);
        end, debug.traceback);
        if (oSquare) then oSquare:delete(); end
        oImage:delete();
        assert(bOK, vError);
        _tCircularImages[tImage] = oBitmap;
    end

    -- 4. Translate the shared center only at the final bitmap draw.
    local nSize = nDiameter or oBitmap:GetWidth();
    _D.DrawImage(oBitmap, nX - nSize / 2, nY - nSize / 2, nSize, nSize, true);
end


-- Oval variants share source-cache lifetime; each source keeps at most 16 crop ratios.
local _tOvalImages = setmetatable({}, {__mode = "k"});

--[[!
@fqxn CFS.Modules.Forge.Functions.DrawImageOval
@pulsarlua function Forge.DrawImageOval
@desc Draws a centered oval portrait during an active render pass. Center-crops the source to the requested width-to-height ratio, rounded to whole source pixels, instead of stretching its contents. Multiplies existing alpha by an antialiased ellipse mask without altering source files. X/Y identify the oval center. Uses existing game-relative path validation, source caching, missing-art fallback and file invalidation. Masked bitmaps are cached by source crop dimensions, with at most 16 ratios per source; repeated sizes with the same crop reuse a bitmap. Preview and PNG export use the same draw path. Existing rectangular and circular drawing functions are unchanged.
@param string sPath Image path relative to the active resource root.
@param number nX Horizontal center in card-space coordinates.
@param number nY Vertical center in card-space coordinates.
@param number nWidth Positive finite oval width in card-space coordinates.
@param number nHeight Positive finite oval height in card-space coordinates.
@ret void none No values returned.
@error Requires an active render pass, a valid game-relative path and positive finite dimensions. Image decoding or oval bitmap creation failures raise an error.
@ex
-- Width and height change independently while the portrait stays centered.
Forge.DrawImageOval("Cards/Portrait.png", 412.5, 350, 320, 400);
!]]
function Forge.DrawImageOval(sPath, nX, nY, nWidth, nHeight)
    assert(_D, "Forge drawing is only available during a render pass.");
    assert(rawtype(nWidth) == "number" and nWidth > 0 and nWidth < math.huge, "Oval width must be a positive finite number.");
    assert(rawtype(nHeight) == "number" and nHeight > 0 and nHeight < math.huge, "Oval height must be a positive finite number.");
    local pImage = resolveImage(sPath);

    -- 1. Share source bitmaps and the normal missing-art behavior with DrawImage.
    if (not wx.wxFileExists(pImage)) then
        pImage = io.normalizepath(APP_PATH.."/Images/Missing.png");
    end

    local tImage = _tImages[pImage];

    if (not tImage) then
        assert(wx.wxFileExists(pImage), "Card image does not exist: "..pImage);
        local oBitmap = wx.wxBitmap(pImage, wx.wxBITMAP_TYPE_ANY);
        assert(oBitmap:IsOk(), "Could not decode card image: "..pImage);
        tImage = {bitmap = oBitmap, stamp = imageStamp(pImage),};
        _tImages[pImage] = tImage;
    end

    -- 2. Compute the largest centered source crop matching the requested ratio.
    local nSourceWidth  = tImage.bitmap:GetWidth();
    local nSourceHeight = tImage.bitmap:GetHeight();
    local nRatio        = nWidth / nHeight;
    local nCropWidth    = math.max(1, math.min(nSourceWidth, floor(nSourceHeight * nRatio + 0.5)));
    local nCropHeight   = math.max(1, math.min(nSourceHeight, floor(nSourceWidth / nRatio + 0.5)));
    local sKey          = tostring(nCropWidth)..":"..tostring(nCropHeight);
    local tVariants     = _tOvalImages[tImage];

    if (not tVariants or tVariants.count >= 16 and not tVariants[sKey]) then
        tVariants = {count = 0};
        _tOvalImages[tImage] = tVariants;
    end

    local oBitmap = tVariants[sKey];

    if (not oBitmap) then
        local oImage = tImage.bitmap:ConvertToImage();
        local oCrop;
        local bOK, vError = xpcall(function()
            oCrop = oImage:GetSubImage(wx.wxRect(floor((nSourceWidth - nCropWidth) / 2), floor((nSourceHeight - nCropHeight) / 2), nCropWidth, nCropHeight));
            if (not oCrop:HasAlpha()) then oCrop:InitAlpha(); end

            -- 3. Preserve source transparency inside the ellipse and soften its edge.
            local sAlpha    = oCrop:GetAlpha();
            local nRadiusX  = nCropWidth / 2;
            local nRadiusY  = nCropHeight / 2;
            local nEdge     = math.min(nRadiusX, nRadiusY);
            local tRows     = {};

            for nY = 0, nCropHeight - 1 do
                local tAlpha = {};
                local nDY    = (nY + 0.5 - nRadiusY) / nRadiusY;

                for nX = 0, nCropWidth - 1 do
                    local nDX       = (nX + 0.5 - nRadiusX) / nRadiusX;
                    local nCoverage = math.max(0, math.min(1, 0.5 + (1 - math.sqrt(nDX * nDX + nDY * nDY)) * nEdge));
                    tAlpha[nX + 1]  = string.char(floor(sAlpha:byte(nY * nCropWidth + nX + 1) * nCoverage + 0.5));
                end

                tRows[nY + 1] = table.concat(tAlpha);
            end

            oCrop:SetAlpha(table.concat(tRows));
            oBitmap = wx.wxBitmap(oCrop);
            assert(oBitmap:IsOk(), "Could not create oval card image: "..pImage);
        end, debug.traceback);
        if (oCrop) then oCrop:delete(); end
        oImage:delete();
        assert(bOK, vError);
        tVariants[sKey] = oBitmap;
        tVariants.count = tVariants.count + 1;
    end

    -- 4. Draw around the shared center; source cropping keeps portrait proportions.
    _D.DrawImage(oBitmap, nX - nWidth / 2, nY - nHeight / 2, nWidth, nHeight, true);
end


-- Rectangular cover crops follow source-cache lifetime; each source retains 16 ratios.
local _tCroppedImages = setmetatable({}, {__mode = "k"});

--[[!
@fqxn CFS.Modules.Forge.Functions.DrawImageCropped
@pulsarlua function Forge.DrawImageCropped
@desc Draws an image centered in a rectangular window without stretching its contents. Center-crops the source to the requested width-to-height ratio, rounded to whole source pixels, then draws that crop at the supplied size. X/Y locate the destination center. Source transparency is retained; this function does not add rounded corners or a frame mask. Uses existing game-relative path checks, source caching, missing-art fallback and file invalidation. Crop bitmaps are reused by source crop dimensions, with at most 16 ratios per source. Preview and PNG export share this draw path. Source artwork and other drawing functions are unchanged.
@param string sPath Image path relative to the active resource root.
@param number nX Horizontal center of the destination window in card-space coordinates.
@param number nY Vertical center of the destination window in card-space coordinates.
@param number nWidth Positive finite destination width.
@param number nHeight Positive finite destination height.
@ret void none No values returned.
@error Requires an active render pass, a valid game-relative path and positive finite dimensions. Image decoding or crop bitmap creation failures raise an error.
@ex
Forge.DrawImageCropped("Cards/Structure/Base/Land/Ashpoint.png", 485, 330, 460, 300);
!]]
function Forge.DrawImageCropped(sPath, nX, nY, nWidth, nHeight)
    assert(_D, "Forge drawing is only available during a render pass.");
    assert(rawtype(nWidth) == "number" and nWidth > 0 and nWidth < math.huge, "Cropped image width must be a positive finite number.");
    assert(rawtype(nHeight) == "number" and nHeight > 0 and nHeight < math.huge, "Cropped image height must be a positive finite number.");
    local pImage = resolveImage(sPath);

    -- 1. Share normal source loading and missing-art behavior with DrawImage.
    if (not wx.wxFileExists(pImage)) then
        pImage = io.normalizepath(APP_PATH.."/Images/Missing.png");
    end
    local tImage = _tImages[pImage];

    if (not tImage) then
        assert(wx.wxFileExists(pImage), "Card image does not exist: "..pImage);
        local oBitmap = wx.wxBitmap(pImage, wx.wxBITMAP_TYPE_ANY);
        assert(oBitmap:IsOk(), "Could not decode card image: "..pImage);
        tImage = {bitmap = oBitmap, stamp = imageStamp(pImage),};
        _tImages[pImage] = tImage;
    end

    -- 2. Keep the largest centered crop matching the destination proportions.
    local nSourceWidth  = tImage.bitmap:GetWidth();
    local nSourceHeight = tImage.bitmap:GetHeight();
    local nRatio        = nWidth / nHeight;
    local nCropWidth    = math.max(1, math.min(nSourceWidth, floor(nSourceHeight * nRatio + 0.5)));
    local nCropHeight   = math.max(1, math.min(nSourceHeight, floor(nSourceWidth / nRatio + 0.5)));
    local sKey          = tostring(nCropWidth)..":"..tostring(nCropHeight);
    local tVariants     = _tCroppedImages[tImage];

    if (not tVariants or tVariants.count >= 16 and not tVariants[sKey]) then
        tVariants = {count = 0};
        _tCroppedImages[tImage] = tVariants;
    end
    local oBitmap = tVariants[sKey];

    if (not oBitmap) then
        local oImage = tImage.bitmap:ConvertToImage();
        local oCrop;
        local bOK, vError = xpcall(function()
            -- 3. Cropping preserves original pixel data and existing transparency.
            oCrop = oImage:GetSubImage(wx.wxRect(floor((nSourceWidth - nCropWidth) / 2), floor((nSourceHeight - nCropHeight) / 2), nCropWidth, nCropHeight));
            oBitmap = wx.wxBitmap(oCrop);
            assert(oBitmap:IsOk(), "Could not create cropped card image: "..pImage);
        end, debug.traceback);
        if (oCrop) then oCrop:delete(); end
        oImage:delete();
        assert(bOK, vError);
        tVariants[sKey] = oBitmap;
        tVariants.count = tVariants.count + 1;
    end

    -- 4. Translate the shared center only at the final bitmap draw.
    _D.DrawImage(oBitmap, nX - nWidth / 2, nY - nHeight / 2, nWidth, nHeight, true);
end


-- Experimental image tinting is isolated here; existing DrawImage calls are unchanged.
-- Weak source keys release variants after normal image invalidation or game/set changes.
local _tTintedImages = setmetatable({}, {__mode = "k"});

--[[!
@fqxn CFS.Modules.Forge.Functions.DrawImageTinted
@pulsarlua function Forge.DrawImageTinted
@desc Draws an image with multiplicative RGBA tinting during an active render pass. Each source RGB channel is multiplied by the matching tint channel divided by 255; source alpha is multiplied by tint alpha. White with full opacity preserves the image. Uses the same relative path checks and missing-art fallback as DrawImage. Source artwork is never modified. Tinted bitmaps are cached separately, with at most 64 variants per cached source; normal source invalidation discards its variants. Preview and PNG export use the same draw function.
@param string sPath Image path relative to the active resource root.
@param number nX Horizontal card-space position.
@param number nY Vertical card-space position.
@param number nWidth Draw width, or nil for native width.
@param number nHeight Draw height, or nil for native height.
@param wxColour oTint Native color, such as Color.RGBA(255, 80, 80, 255).
@ret void none No values returned.

@example
Forge.DrawImageTinted("Images/Icon.png", 10, 10, 64, 64, Color.RGBA(255, 80, 80, 255));
!]]
function Forge.DrawImageTinted(sPath, nX, nY, nWidth, nHeight, oTint)
    assert(_D, "Forge drawing is only available during a render pass.");
    assert(wxlua.type(oTint) == "wxColour" and oTint:IsOk(), "Image tint must be a valid native color.");
    local pImage = resolveImage(sPath);

    if (not wx.wxFileExists(pImage)) then
        pImage = io.normalizepath(APP_PATH.."/Images/Missing.png");
    end

    local tImage = _tImages[pImage];

    if (not tImage) then
        assert(wx.wxFileExists(pImage), "Card image does not exist: "..pImage);
        local oBitmap = wx.wxBitmap(pImage, wx.wxBITMAP_TYPE_ANY);
        assert(oBitmap:IsOk(), "Could not decode card image: "..pImage);
        tImage = {bitmap = oBitmap, stamp = imageStamp(pImage),};
        _tImages[pImage] = tImage;
    end

    local nRed, nGreen, nBlue, nAlpha = oTint:Red(), oTint:Green(), oTint:Blue(), oTint:Alpha();
    local sKey = string.char(nRed, nGreen, nBlue, nAlpha);
    local tVariants = _tTintedImages[tImage];

    if (not tVariants or tVariants.count >= 64 and not tVariants[sKey]) then
        tVariants = {count = 0};
        _tTintedImages[tImage] = tVariants;
    end

    local oBitmap = tVariants[sKey];

    if (not oBitmap) then
        local oImage = tImage.bitmap:ConvertToImage();
        local bOK, vError = xpcall(function()
            -- InitAlpha also converts a color-key mask to alpha before RGB changes.
            if (not oImage:HasAlpha()) then oImage:InitAlpha(); end
            local tRed, tGreen, tBlue, tAlpha = {}, {}, {}, {};

            for nByte = 0, 255 do
                local sByte = string.char(nByte);
                tRed[sByte] = string.char(floor(nByte * nRed / 255));
                tGreen[sByte] = string.char(floor(nByte * nGreen / 255));
                tBlue[sByte] = string.char(floor(nByte * nBlue / 255));
                tAlpha[sByte] = string.char(floor(nByte * nAlpha / 255));
            end

            --PNG icons reuse many RGB triplets. Table substitution avoids a Lua callback
            --and three concatenations for every repeated pixel. Bound the per-tint lookup.
            local nColors = 0;
            local tColors = setmetatable({}, {
                __index = function(t, sRGB)
                    local sTint = tRed[sRGB:sub(1, 1)]..tGreen[sRGB:sub(2, 2)]..tBlue[sRGB:sub(3, 3)];
                    if (nColors < 4096) then
                        rawset(t, sRGB, sTint);
                        nColors = nColors + 1;
                    end
                    return sTint;
                end,
            });
            local sRGB = oImage:GetData():gsub("...", tColors);
            local sAlpha = oImage:GetAlpha():gsub(".", tAlpha);
            oImage:SetData(sRGB);
            oImage:SetAlpha(sAlpha);
            oBitmap = wx.wxBitmap(oImage);
            assert(oBitmap:IsOk(), "Could not create tinted card image: "..pImage);
        end, debug.traceback);
        oImage:delete();
        assert(bOK, vError);
        tVariants[sKey] = oBitmap;
        tVariants.count = tVariants.count + 1;
    end

    _D.DrawImage(oBitmap, nX, nY, nWidth, nHeight, true);
end

--[[!
@fqxn CFS.Modules.Forge.Functions.DrawRectangle
@pulsarlua function Forge.DrawRectangle
@desc Draws a rectangle through the current native drawing context; requires an active render pass.
@param number nX Left position in card-space coordinates.
@param number nY Top position in card-space coordinates.
@param number nWidth Rectangle width.
@param number nHeight Rectangle height.
@param wxColour|number oFill Native fill color or packed RGBA value.
@ret void none No values returned.

!]]
function Forge.DrawRectangle(...)
    assert(_D, "Forge drawing is only available during a render pass.");
    return _D.DrawRectangle(...);
end

--[[!
@fqxn CFS.Modules.Forge.Functions.GetOutputInfo
@pulsarlua function Forge.GetOutputInfo
@desc Returns native card width and height.
@ret table tInfo Native card dimensions in the numeric Width and Height fields.

!]]
function Forge.GetOutputInfo()
    return {Width = _nWidth, Height = _nHeight,};
end

--[[!
@fqxn CFS.Modules.Forge.Functions.SetDrawFunction
@pulsarlua function Forge.SetDrawFunction
@desc Installs the front drawing callback and marks the card for redraw.
@param function fDraw Front callback called with the object name, drawing context, and native device context.
@ret void none No values returned.

!]]
function Forge.SetDrawFunction(fDraw)
    assert(rawtype(fDraw) == "function", "Draw must return a function.");
    _fDraw = fDraw;
    Forge.RequestCardRedraw();
end

--[[!
@fqxn CFS.Modules.Forge.Functions.SetDrawBackFunction
@pulsarlua function Forge.SetDrawBackFunction
@desc Installs the back drawing callback and marks the card for redraw.
@param function fDraw Back callback called with the object name, drawing context, and native device context.
@ret void none No values returned.

!]]
function Forge.SetDrawBackFunction(fDraw)
    assert(rawtype(fDraw) == "function", "DrawBack must return a function.");
    _fDrawBack = fDraw;
    Forge.RequestCardRedraw();
end

--[[!
@fqxn CFS.Modules.Forge.Functions.SetActiveRow
@pulsarlua function Forge.SetActiveRow
@desc Sets the active render row and requests a card redraw.
@param table tRow Row data to use for subsequent rendering.
@ret void none No values returned.

!]]
function Forge.SetActiveRow(tRow)
    _tActiveRow = tRow;
    Forge.RequestCardRedraw();
end

--[[!
@fqxn CFS.Modules.Forge.Functions.SetActiveCardSet
@pulsarlua function Forge.SetActiveCardSet
@desc Loads card dimensions, clears image and bitmap caches, selects the front, and requests redraw.
@param CardSet oCardSet Card set supplying the native card width and height.
@ret void none No values returned.

!]]
function Forge.SetActiveCardSet(oCardSet)
    _nWidth, _nHeight = oCardSet.GetCardWidth(), oCardSet.GetCardHeight();
    assert(_nWidth > 0 and _nHeight > 0, "Invalid card dimensions.");
    _tImages = {};
    _oBitmap = nil;
    _bDrawBack = false;
    Forge.RequestCardRedraw();
end

--[[!
@fqxn CFS.Modules.Forge.Functions.SetFace
@pulsarlua function Forge.SetFace
@desc Selects front or back and requests redraw when the face changes.
@param string sFace Card face: "front" or "back".
@ret void none No values returned.

!]]
function Forge.SetFace(sFace)
    assert(sFace == "front" or sFace == "back", "Unknown card face.");
    local bBack = sFace == "back";
    if (_bDrawBack ~= bBack) then
        _bDrawBack = bBack;
        Forge.RequestCardRedraw();
    end
end

--[[!
@fqxn CFS.Modules.Forge.Functions.SetDrawEnabled
@pulsarlua function Forge.SetDrawEnabled
@desc Blocks or permits timer-driven preview drawing.
@param boolean bEnabled True permits timer-driven preview drawing; false blocks it.
@ret void none No values returned.

!]]
function Forge.SetDrawEnabled(bEnabled)
    _bDrawBlocked = not bEnabled;
end

--[[!
@fqxn CFS.Modules.Forge.Functions.RequestCardRedraw
@pulsarlua function Forge.RequestCardRedraw
@desc Marks card pixels and the surrounding canvas dirty.
@ret void none No values returned.

!]]
function Forge.RequestCardRedraw()
    _bRedrawCard, _bRedrawCanvas = true, true;
end

--[[!
@fqxn CFS.Modules.Forge.Functions.RequestUtilRedraw
@pulsarlua function Forge.RequestUtilRedraw
@desc Marks utility guides and the surrounding canvas dirty.
@ret void none No values returned.

!]]
function Forge.RequestUtilRedraw()
    _bRedrawUtil, _bRedrawCanvas = true, true;
end

--[[!
@fqxn CFS.Modules.Forge.Functions.GetBitmap
@pulsarlua function Forge.GetBitmap
@desc Returns the current preview bitmap and its revision number.
@ret wxBitmap|nil oBitmap Current preview bitmap, or nil before a preview exists.
@ret number nRevision Preview revision counter.

!]]
function Forge.GetBitmap()
    return _oBitmap, _nRevision;
end

--[[!
@fqxn CFS.Modules.Forge.Functions.OnTimer
@pulsarlua function Forge.OnTimer
@desc Checks image changes and renders dirty preview pixels when ready. Releases drawing resources and propagates rendering failures.
@ret boolean bRendered True when a pending canvas update was handled; false when drawing was skipped.

!]]
function Forge.OnTimer()
    checkImages();
    if (_bDrawBusy or _bDrawBlocked or not _bRedrawCanvas) then return false end
    if (not _tActiveRow or not _fDraw) then return false end
    _bDrawBusy = true;
    local oDC, oGC;
    local bOK, sError = xpcall(function()
        if (_bRedrawCard) then
            local oBitmap = wx.wxBitmap(_nWidth, _nHeight, 32);
            oDC = wx.wxMemoryDC();
            oDC:SelectObject(oBitmap);
            -- Card Canvas is a preview-only clear color; export retains its own background.
            local sCanvasColor = INIFile.GetValue(FS.AppCFG, "Settings", "ForgeCanvasColor");

            if (not sCanvasColor:match("^#%x%x%x%x%x%x$")) then sCanvasColor = "#FFFFFF"; end
            oDC:SetBackground(wx.wxBrush(wx.wxColour(sCanvasColor)));
            oDC:Clear();
            oGC = assert(wx.wxGraphicsContext.Create(oDC), "Could not create WX graphics context.");
            _D, _Object, _InternalDC = drawingContext(oGC, oDC), "Card", oDC;
            local fDraw = _bDrawBack and _fDrawBack or _fDraw;
            assert(fDraw, "No draw function for this card face.")(_Object, _D, _InternalDC);
            oGC:delete();
            oGC = nil;
            oDC:SelectObject(wx.wxNullBitmap);
            oDC:delete();
            oDC = nil;
            _oBitmap = oBitmap;
            _nRevision = _nRevision + 1;
        end
    end, debug.traceback);
    _D, _Object, _InternalDC = nil, nil, nil;
    if (oGC) then oGC:delete(); end
    if (oDC) then oDC:SelectObject(wx.wxNullBitmap); oDC:delete(); end
    _bDrawBusy = false;
    _bRedrawCard, _bRedrawUtil, _bRedrawCanvas = false, false, false;
    assert(bOK, sError);
    return true;
end

-- Export uses the same draw callbacks without replacing the preview bitmap or face.
--[[!
@fqxn CFS.Modules.Forge.Functions.ExportPNG
@pulsarlua function Forge.ExportPNG
@desc Renders a selected face at the requested percentage and writes PNG without replacing preview state; restores drawing context after success or failure.
@param string sFace Card face to render: "front" or "back".
@param string pFile Destination PNG filesystem path.
@param number nPercent Optional export scale percentage; defaults to 100.
@ret void none No values returned.

!]]
function Forge.ExportPNG(sFace, pFile, nPercent)
    assert(sFace == "front" or sFace == "back", "Unknown export face.");
    assert(_tActiveRow and not _bDrawBusy, "No card is ready to export.");
    local fDraw;
    if (sFace == "back") then fDraw = _fDrawBack; else fDraw = _fDraw; end
    assert(fDraw, "No draw function for export face.");
    local oDC, oGC;
    local nWidth, nHeight = require("Exporter").get("PNG").dimensions(_nWidth, _nHeight, nPercent or 100);
    local tContext = {_D, _Object, _InternalDC};
    _bDrawBusy = true;
    local bOK, sError = xpcall(function()
        local oBitmap = wx.wxBitmap(nWidth, nHeight, 32);
        oDC = wx.wxMemoryDC(); oDC:SelectObject(oBitmap); oDC:SetBackground(wx.wxWHITE_BRUSH); oDC:Clear();
        oGC = assert(wx.wxGraphicsContext.Create(oDC), "Could not create export graphics context.");
        oGC:Scale(nWidth / _nWidth, nHeight / _nHeight);
        _D, _Object, _InternalDC = drawingContext(oGC, oDC), "Card", oDC;
        fDraw(_Object, _D, _InternalDC);
        oGC:delete(); oGC = nil; oDC:SelectObject(wx.wxNullBitmap); oDC:delete(); oDC = nil;
        local oImage = oBitmap:ConvertToImage();
        local bSaved = oImage:SaveFile(pFile, wx.wxBITMAP_TYPE_PNG); oImage:delete();
        assert(bSaved, "Could not save PNG image.");
    end, debug.traceback);
    if (oGC) then oGC:delete(); end
    if (oDC) then oDC:SelectObject(wx.wxNullBitmap); oDC:delete(); end
    _D, _Object, _InternalDC = table.unpack(tContext, 1, 3); _bDrawBusy = false;
    assert(bOK, sError);
end

--[[!
@fqxn CFS.Modules.Forge.Functions.Release
@pulsarlua function Forge.Release
@desc Clears image, row, and bitmap state and resets pending redraw flags.
@ret void none No values returned.

!]]
function Forge.Release()
    _tImages, _tActiveRow, _oBitmap = {}, nil, nil;
    _tGraphicsBitmaps = setmetatable({}, {__mode = "k"});
    require("TextEffects").Clear();
    _bRedrawCard, _bRedrawUtil, _bRedrawCanvas = false, false, false;
end
--[[!
@fqxn CFS.Modules.Forge.Functions.DrawText
@pulsarlua function Forge.DrawText
@desc Draws plain text onto the active card render target using a single style.

<p>
  Renders text using the specified FontStyle during the active card draw pass.
  This function is intended for use by CardSet <code>Draw</code> scripts and supports
  optional centering, rotation, and custom wrapping behavior.
</p>

<h3>Behavior</h3>
<ul>
  <li>Uses the specified style from <code>STYLE</code>.</li>
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
@param boolean|nil vCenterX Optional horizontal centering flag.
@param boolean|nil vCenterY Optional vertical centering flag.
@param number|nil vAngle   Optional rotation angle (degrees).
@param function|nil vWrap Optional wrapping function.
@param any ... Extra arguments passed as a table to the optional wrapping callback.
@ret number|nil nX Final X position of the last line, or nil when the wrapper supplies no lines.
@ret number|nil nY Final Y position of the last line, or nil when no lines are drawn.
@ret number|nil nWidth Measured width of the last line, or nil when no lines are drawn.
@ret number|nil nHeight Measured height of the last line, or nil when no lines are drawn.

@ex
-- Draw centered title text near the top of the card
Forge.DrawText(
    "TITLE",
    412, 60,
    "Example Card",
    true, true
);
        !]]
Forge.DrawText = function(sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, ...)
    local fWrap         = rawtype(vWrap)        == "function"   and vWrap       or false;
    local bCenterX      = rawtype(vCenterX)     == "boolean"    and vCenterX    or false;
    local bCenterY      = rawtype(vCenterY)     == "boolean"    and vCenterY    or false;
    local oStyle        = GetFontStyle(sStyle); --TODO add default style as fallback???
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
end
--Named material processors share native font layout and a bounded bitmap cache.
local TextEffects = require("TextEffects");

--[[!
@fqxn CFS.Modules.Forge.Functions.DrawTextEffect
@pulsarlua function Forge.DrawTextEffect
@desc Draws a native UTF-8 font run with a named material effect. Font family, size, weight, italic and letter spacing come from the Style as-is; there is no fitting, shrinking or glyph normalization. Zero letter spacing uses native run shaping; nonzero spacing follows FontStyle's code-point layout. Material replaces Style color, shadow, outline, glow and background. Built-in Stamped adds steel shading, edge bevels and a dark extrusion. Game processors are loaded from FS.Game.Effects in UserEnv and take precedence over built-ins. Changed game source reloads on the next draw. Centering uses the complete run raster including processor padding. Completed runs are cached; effects must be deterministic.
@param string sStyle Existing Style using any installed font.
@param number nX Left edge, or horizontal center when bCenterX is true.
@param number nY Top edge, or vertical center when bCenterY is true.
@param string sText Single-line valid UTF-8 text, at most 4096 bytes.
@param string sEffect Case-sensitive effect name, such as Stamped or a name returned by Scripts/Effects.lua.
@param boolean bCenterX Optional horizontal centering; defaults to false.
@param boolean bCenterY Optional vertical centering; defaults to false.
@ret number nLeft Left edge of the rendered raster.
@ret number nTop Top edge of the rendered raster.
@ret number nWidth Rendered raster width including effect padding.
@ret number nHeight Rendered raster height including effect padding.
@error Requires an active render pass, valid Style/effect, finite coordinates and valid UTF-8 without line breaks. Invalid processors and rasters larger than two million pixels are rejected. No wrapping or rotation is performed.
@ex Forge.DrawTextEffect("NAME", 412.5, 100, "Example", "Stamped", true, true);
!]]
function Forge.DrawTextEffect(sStyle, nX, nY, sText, sEffect, bCenterX, bCenterY)
    assert(_D, "Forge drawing is only available during a render pass.");
    assert(rawtype(sText) == "string" and #sText <= 4096 and utf8.len(sText) and not sText:find("[%z\r\n]"), "Text effects require valid single-line UTF-8 text of at most 4096 bytes.");
    assert(rawtype(sEffect) == "string" and sEffect ~= "", "A named text effect is required.");
    assert(rawtype(nX) == "number" and math.abs(nX) < math.huge and rawtype(nY) == "number" and math.abs(nY) < math.huge, "Text effect coordinates must be finite.");
    if (sText == "" or not sText:find("%S")) then return nX, nY, 0, 0; end
    local oStyle = assert(GetFontStyle(sStyle), "Text effects require an existing Style.");
    if (_bAutoUpdateStyle) then oStyle.Update(); end
    local pEffects = FS.Game.Effects;
    if (pEffects == "") then pEffects = nil; end
    local sStamp = pEffects and imageStamp(pEffects) or "missing";
    local tEffect = TextEffects.Get(sEffect, pEffects, sStamp, UserEnv.Get());
    local tMeasure = {SetDrawingFont = function() end, SetFilteringMode = function() end, GetTextWidth = function() return 0; end, GetTextHeight = function() return 0; end};
    local nSpacing = oStyle.Prep(tMeasure, "AA") - oStyle.Prep(tMeasure, "");
    local oBitmap, nWidth, nHeight = TextEffects.Render(oStyle.GetFont(), nSpacing, sText, sEffect, tEffect);
    local nLeft = bCenterX == true and nX - nWidth / 2 or nX;
    local nTop = bCenterY == true and nY - nHeight / 2 or nY;
    if (oBitmap) then _D.DrawImage(oBitmap, nLeft, nTop, nWidth, nHeight, true); end
    return nLeft, nTop, nWidth, nHeight;
end

--[[!
@fqxn CFS.Modules.Forge.Functions.DrawTextCurved
@pulsarlua function Forge.DrawTextCurved
@desc Draws one plain UTF-8 text line centered on a circular arc using an existing Style at its configured size. X/Y identify the midpoint of the text line, not the circle's center. With bBelow false or omitted, the middle arches upward and the ends sit lower; true reverses the arc while keeping letters upright. Measures prefix advances through Style.Prep so configured letter spacing and native pair spacing contribute to placement. Each code point is rotated tangent to the arc and drawn through the normal Style.Draw path, retaining its effects; this does not perform joined-script or combining-character shaping across glyphs. No text is shrunk, wrapped or stretched. Existing text calls are unchanged.
@param string sStyle Existing Style name.
@param number nX Horizontal midpoint of the text arc in card-space coordinates.
@param number nY Vertical position of the middle of the text line in card-space coordinates.
@param string sText Plain, valid UTF-8 single-line text; an empty string draws nothing.
@param number nRadius Positive finite arc radius in card-space coordinates; larger radii produce flatter text.
@param boolean bBelow Optional lower-arc direction; defaults to false.
@ret number nWidth Measured straight-line advance in pixels, not the curved bounding-box width.
@ret number nHeight Native font line height, not the curved bounding-box height.
@error Requires an active render pass, an existing Style, single-line UTF-8 text and a positive finite radius. Text must occupy at most a semicircle; change the radius or Style if it is too long.
@ex
Forge.DrawTextCurved("NAME", 412.5, 175, "Eternal Warden", 650);
Forge.DrawTextCurved("NAME", 412.5, 730, "Arden Raxor", 650, true);
!]]
function Forge.DrawTextCurved(sStyle, nX, nY, sText, nRadius, bBelow)
    assert(_D, "Forge drawing is only available during a render pass.");
    assert(rawtype(sText) == "string" and not sText:find("[\r\n]"), "Curved text requires a single text line.");
    assert(rawtype(nRadius) == "number" and nRadius > 0 and nRadius < math.huge, "Text arc radius must be a positive finite number.");
    assert(bBelow == nil or rawtype(bBelow) == "boolean", "Lower text arc flag must be boolean.");
    local oStyle = assert(GetFontStyle(sStyle), "Curved text requires an existing Style.");

    if (_bAutoUpdateStyle) then oStyle.Update(); end

    -- 1. Remove fixed effect padding from advances, without changing the Style.
    local nEffectWidth  = oStyle.Prep(_D, "");
    local nWidth        = oStyle.Prep(_D, sText) - nEffectWidth;
    local nHeight       = _D.GetTextHeight(sText);
    local nDirection    = bBelow and -1 or 1;
    local sPrefix       = "";
    local tGlyphs       = {};
    assert(nWidth <= math.pi * nRadius, "Curved text exceeds a semicircle; increase the radius or adjust its Style.");

    -- 2. Validate and measure the whole line before drawing any of its glyphs.
    for _, nCodePoint in utf8.codes(sText) do
        local sGlyph    = utf8.char(nCodePoint);
        local nGlyphW   = _D.GetTextWidth(sGlyph);
        sPrefix = sPrefix..sGlyph;
        local nAdvance  = oStyle.Prep(_D, sPrefix) - nEffectWidth;
        tGlyphs[#tGlyphs + 1] = {Text = sGlyph, Width = nGlyphW, Offset = nAdvance - nGlyphW / 2 - nWidth / 2};
    end

    -- 3. Keep each glyph upright and tangent to the requested upper or lower arc.
    for _, tGlyph in ipairs(tGlyphs) do
        local nTheta    = tGlyph.Offset / nRadius;
        local nPointX   = nX + nRadius * math.sin(nTheta);
        local nPointY   = nY + nDirection * nRadius * (1 - math.cos(nTheta));
        local nAngle    = floor((-nDirection * math.deg(nTheta)) % 360);
        local nRadians  = math.rad(nAngle);
        local nDrawX    = nPointX - math.cos(nRadians) * tGlyph.Width / 2 - math.sin(nRadians) * nHeight / 2;
        local nDrawY    = nPointY + math.sin(nRadians) * tGlyph.Width / 2 - math.cos(nRadians) * nHeight / 2;
        oStyle.Draw(_Object, _D, _InternalDC, floor(nDrawX), floor(nDrawY), tGlyph.Text, nAngle);
    end

    return nWidth, nHeight;
end


--[[!
@fqxn CFS.Modules.Forge.Private.Functions.drawStyledText
@desc Shared styled-run parsing, measurement and drawing for both styled-text calls.
@vis private
!]]
local function drawStyledText(sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, tArguments, nWidth, tModes)
    local fWrap         = rawtype(vWrap)        == "function"   and vWrap       or false;
    local bCenterX      = rawtype(vCenterX)     == "boolean"    and vCenterX    or false;
    local bCenterY      = rawtype(vCenterY)     == "boolean"    and vCenterY    or false;

    --------------------------------------------------------------------
    -- PARSE HELPERS
    --------------------------------------------------------------------
    --[[!
    @fqxn CFS.Modules.Forge.Private.Functions.BuildRuns2
    @desc Splits styled text into drawing runs and accumulated plain text.
    @param any sIn Value supplied as sIn.
    @vis private
    !]]
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
            local use = GetFontStyle(tag) and tag or sStyle;

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
        local oDef = GetFontStyle(sStyle);
        if (oDef and oDef.Update) then
            oDef.Update();
        end

        for _, r in ipairs(tRunsSrc) do
            local o = GetFontStyle(r.Style);
            if (o and o.Update) then
                o.Update();
            end
        end
    end

    local nPadX = 1; -- preserve the existing spacing between style runs

    -- Both public calls measure the same styled runs, including effect bounds.
    local function MeasureLine(tSegs)
        local nX = 0;

        local nLineMinX = 0;
        local nLineMaxX = 0;
        local nLineMinY = 0;
        local nLineMaxY = 0;

        for _, seg in ipairs(tSegs) do
            local oStyle = GetFontStyle(seg.Style) or GetFontStyle(sStyle);
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
        return {MinX = nLineMinX, MinY = nLineMinY, W = nLineW, H = nLineH};
    end

    -- Byte ranges come from UTF-8 character boundaries and retain style ownership.
    local function SliceRuns(nFirst, nLast)
        local tSegs = {};
        local nOffset = 1;
        for _, tRun in ipairs(tRunsSrc) do
            local nEnd = nOffset + #tRun.Text - 1;
            local nStart = math.max(nFirst, nOffset);
            local nStop = math.min(nLast, nEnd);
            if (nStart <= nStop) then
                tSegs[#tSegs + 1] = {Style = tRun.Style, Text = tRun.Text:sub(nStart - nOffset + 1, nStop - nOffset + 1)};
            end
            nOffset = nEnd + 1;
            if (nOffset > nLast) then break; end
        end
        return tSegs;
    end

    --------------------------------------------------------------------
    -- WRAP (wrapper contract is plain string)
    --------------------------------------------------------------------
    local tLines        = {};
    local nStartOffsetX = 0;
    local nStartOffsetY = 0;

    if (fWrap) then
        local oDef = GetFontStyle(sStyle);
        local nW, nH = oDef.Prep(_D, sPlain);
        tLines, nStartOffsetX, nStartOffsetY = fWrap(nW, nH, sPlain, vAngle, tArguments);
    elseif (not nWidth) then
        tLines[1] = sPlain;
    end

    --------------------------------------------------------------------
    -- BUILD PER-LINE SEGMENTS (preserves style runs across wrapped lines)
    --------------------------------------------------------------------
    local tLineSegs = {};
    local tLineScales = {};
    local tEmptyHeights = {};
    if (nWidth) then
        local tEntries = {};
        local nFirst = 1;
        repeat
            local nBreak = sPlain:find("\n", nFirst, true);
            tEntries[#tEntries + 1] = {First = nFirst, Last = nBreak and nBreak - 1 or #sPlain};
            if (not nBreak) then break; end
            nFirst = nBreak + 1;
        until false;
        assert(#tModes == #tEntries, "DrawStyledTextFit requires one mode per newline-separated entry.");
        for nEntry in ipairs(tEntries) do
            assert(tModes[nEntry] == "Wrap" or tModes[nEntry] == "Shrink", "DrawStyledTextFit modes must be Wrap or Shrink.");
        end

        local function AddLine(nStart, nEnd, bShrink)
            local tSegs = SliceRuns(nStart, nEnd);
            local tInfo = MeasureLine(tSegs);
            local nLine = #tLineSegs + 1;
            tLineSegs[nLine] = tSegs;
            tLineScales[nLine] = bShrink and tInfo.W > nWidth and nWidth / tInfo.W or 1;
            if (#tSegs == 0) then
                local _, nHeight = GetFontStyle(sStyle).Prep(_D, " ");
                tEmptyHeights[nLine] = nHeight;
            end
        end

        for nEntry, tEntry in ipairs(tEntries) do
            if (tModes[nEntry] == "Shrink" or tEntry.First > tEntry.Last) then
                AddLine(tEntry.First, tEntry.Last, tModes[nEntry] == "Shrink");
            else
                local tCharacters = {};
                for nByte, nCodePoint in utf8.codes(sPlain:sub(tEntry.First, tEntry.Last)) do
                    local nStart = tEntry.First + nByte - 1;
                    tCharacters[#tCharacters + 1] = {First = nStart, Last = nStart + #utf8.char(nCodePoint) - 1,
                        Space = nCodePoint == 32 or nCodePoint == 9};
                end
                local nStart = 1;
                while (nStart <= #tCharacters) do
                    local nFit = nStart - 1;
                    local nSpace;
                    for nCharacter = nStart, #tCharacters do
                        local tInfo = MeasureLine(SliceRuns(tCharacters[nStart].First, tCharacters[nCharacter].Last));
                        if (tInfo.W > nWidth) then break; end
                        nFit = nCharacter;
                        if (tCharacters[nCharacter].Space and nCharacter > nStart) then nSpace = nCharacter; end
                    end
                    -- A character wider than the limit remains at its original size in Wrap mode.
                    if (nFit < nStart) then nFit = nStart; end
                    local nEnd = nFit;
                    if (nFit < #tCharacters and nSpace) then
                        nEnd = nSpace - 1;
                        while (nEnd > nStart and tCharacters[nEnd].Space) do nEnd = nEnd - 1; end
                    end
                    AddLine(tCharacters[nStart].First, tCharacters[nEnd].Last, false);
                    nStart = nEnd + 1;
                    if (nStart <= #tCharacters) then
                        while (nStart <= #tCharacters and tCharacters[nStart].Space) do nStart = nStart + 1; end
                    end
                end
            end
        end
    else
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
    end

    --------------------------------------------------------------------
    -- MEASURE BLOCK (INK-BOX LAYOUT: neutralize negative bearings)
    --------------------------------------------------------------------
    local tLineInfo = {};
    local nBlockW = 0;
    local nBlockH = 0;
    for iLine, tSegs in ipairs(tLineSegs) do
        local tInfo = MeasureLine(tSegs);
        tInfo.H = tEmptyHeights[iLine] or tInfo.H;
        tLineInfo[iLine] = tInfo;
        local nScale = tLineScales[iLine] or 1;
        nBlockW = math.max(nBlockW, tInfo.W * nScale);
        nBlockH = nBlockH + tInfo.H * nScale;
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

    local function DrawLine(tSegs, nX, nLineY)
        for _, seg in ipairs(tSegs) do
            local oStyle = GetFontStyle(seg.Style) or GetFontStyle(sStyle);
            local sPart  = seg.Text;

            oStyle.Prep(_D, sPart, false);

            local nTotalW, nTotalH, nMinX, nMinY = oStyle.Prep(_D, sPart, true);

            -- KEY FIX:
            -- draw so that the ink-box starts at nX (neutralizes negative bearings / kerning tuck)
            local nDrawX = nX - (nMinX or 0);
            local nDrawY = nLineY;

            --TEST (keep it, but make it match the real ink-box)
            --local R = math.random;
            --D.DrawRectangle(floor(nX), floor(nY), floor(nTotalW), floor(nTotalH), ColorRGBA(R(1, 255),R(1, 255),R(1, 255),60));
            --TEST

            oStyle.Draw(_Object, _D, _InternalDC, floor(nDrawX), floor(nDrawY), sPart, vAngle);

            nX = nX + nTotalW + nPadX;
        end
    end

    for iLine, tSegs in ipairs(tLineSegs) do
        local tInfo = tLineInfo[iLine];
        local nScale = tLineScales[iLine] or 1;
        if (nScale < 1) then
            _D.WithScale(nBaseX, nY, nScale, function()
                DrawLine(tSegs, 0, -(tInfo.MinY or 0));
            end);
        else
            DrawLine(tSegs, nBaseX, nY - (tInfo.MinY or 0));
        end
        nY = nY + tInfo.H * nScale;
    end

    return nBaseX, nBaseY, nBlockW, nBlockH;
end
--[[!
@fqxn CFS.Modules.Forge.Functions.DrawStyledText
@pulsarlua function Forge.DrawStyledText
@desc Draws text containing inline style markup onto the active card render target.

<p>
  Renders text that includes inline style tags (e.g. <code>&lt;BOLD&gt;</code>,
  <code>&lt;ITALIC&gt;</code>) using multiple FontStyles in a single draw call.
  This function is intended for CardSet <code>Draw</code> scripts that require
  rich text composition.
</p>

<h3>Behavior</h3>
<ul>
  <li>Parses inline style tags and resolves them against <code>STYLE</code>.</li>
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
@param boolean|nil vCenterX Optional horizontal centering flag.
@param boolean|nil vCenterY Optional vertical centering flag.
@param number|nil vAngle   Optional rotation angle (degrees).
@param function|nil vWrap Optional wrapping function.
@param any ... Extra arguments passed as a table to the optional wrapping callback.
@ret number nX       Top-left X position of the rendered block.
@ret number nY       Top-left Y position of the rendered block.
@ret number nWidth   Total width of the rendered block.
@ret number nHeight  Total height of the rendered block.

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
Forge.DrawStyledText = function(sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, ...)
    return drawStyledText(sStyle, nRawX, nRawY, sText, vCenterX, vCenterY, vAngle, vWrap, {...});
end

--[[!
@fqxn CFS.Modules.Forge.Functions.DrawStyledTextFit
@pulsarlua function Forge.DrawStyledTextFit
@desc Draws styled text to a pixel width, with one Wrap or Shrink mode per newline-separated entry.
    Wrap retains font sizes and breaks long words at UTF-8 character boundaries. A single character
    wider than the limit remains at its original size. Shrink uniformly scales an entry and its
    effects onto one line when needed; it never enlarges text or changes saved styles. Wrapped
    continuations inherit their entry's mode. Entries stack vertically without a height limit.
    Blank entries reserve a base-style line. Existing inline-style parsing is shared with DrawStyledText.
@param string sStyle Base FontStyle name.
@param number nX Left position in card pixels.
@param number nY Top position in card pixels.
@param string sText Styled text with newline-separated entries.
@param number nWidth Positive finite maximum line width in pixels.
@param table tModes One "Wrap" or "Shrink" string for each entry, including blank entries.
@ret number nX Left position of the rendered block.
@ret number nY Top position of the rendered block.
@ret number nWidth Measured block width.
@ret number nHeight Measured block height, including wrapped lines.

@ex -- Requires an existing style named BODY.
local sAbilities =
    "Deal 3 damage to each enemy within range.\n" ..
    "Draw two cards, then discard one card.\n" ..
    "Gain 1 armor until your next turn.";

Forge.DrawStyledTextFit(
    "BODY",
    60, 100,
    sAbilities,
    240,
    {
        "Wrap",   -- First ability wraps at its original size.
        "Shrink", -- Second stays on one line, shrinking if needed.
        "Wrap",   -- Third wraps at its original size.
    }
);
!]]
Forge.DrawStyledTextFit = function(sStyle, nX, nY, sText, nWidth, tModes)
    assert(rawtype(sText) == "string", "DrawStyledTextFit requires a text string.");
    assert(rawtype(nWidth) == "number" and nWidth > 0 and nWidth < math.huge, "DrawStyledTextFit requires a positive finite pixel width.");
    assert(rawtype(tModes) == "table", "DrawStyledTextFit requires a table of entry modes.");
    assert(GetFontStyle(sStyle), "DrawStyledTextFit requires an existing base style.");
    sText = sText:gsub("\r\n", "\n"):gsub("\r", "\n");
    return drawStyledText(sStyle, nX, nY, sText, false, false, nil, nil, {}, nWidth, tModes);
end

return Forge;
