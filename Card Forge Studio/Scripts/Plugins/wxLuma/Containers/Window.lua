local _Containment = require("wxLuma.Core.ControlContainment");
local _ControlObject = require("wxLuma.Core.ControlObject");
local _Events = require("wxLuma.Core.ControlEvents");

--[[!
@fqxn wxLuma.UI.Window
@desc Reusable dark window surface. Four-pixel border strips stretch only along
      their length; structural corners and separate ornaments keep fixed sizes.
      This component owns its artwork and drawing resources. It paints its own
      native panel and leaves application-level window policy to its owner.
!]]
local _wx                            = require("wx");
local Window                         = {};
local _nMargin, _nBorder, _nOrnament = 12, 18, 32;
local _tCorners                      = {
    "Upper Left",
    "Upper Right",
    "Lower Left",
    "Lower Right"
};
local _tEdges = {
    "Top",
    "Bottom",
    "Left",
    "Right"
};

--[[!
@fqxn wxLuma.UI.Window.geometry
@desc Computes client-pixel rectangles. Resizing changes edge lengths and anchor
      positions, never corner/ornament dimensions. Use at least 320 by 240 pixels.
@param number nWidth Surface client width.
@param number nHeight Surface client height.
@ret table tLayout Outer, Content, Corners, Edges and Ornaments rectangles.
!]]
function Window.geometry(nWidth, nHeight)
    assert(nWidth >= 320 and nHeight >= 240, "Window surface requires at least 320 by 240 pixels.");
    local nX, nY          = _nMargin, _nMargin;
    local nWidth, nHeight = nWidth - _nMargin * 2, nHeight - _nMargin * 2;

    --[[!
    @fqxn wxLuma.UI.Window.fRect
    @desc Builds one plain geometry rectangle without allocating a native wxRect.
    @param number nRectX The rectangle x coordinate.
    @param number nRectY The rectangle y coordinate.
    @param number nRectWidth The rectangle width.
    @param number nRectHeight The rectangle height.
    @ret table tRectangle The plain rectangle.
    !]]
    local function fRect(nRectX, nRectY, nRectWidth, nRectHeight)
        return {
            x      = nRectX,
            y      = nRectY,
            width  = nRectWidth,
            height = nRectHeight
        };
    end
    return {
        Outer   = fRect(nX, nY, nWidth, nHeight),
        Content = fRect(nX + 40, nY + 100, nWidth - 80, nHeight - 144),
        Corners = {
            fRect(nX, nY, _nBorder, _nBorder),
            fRect(nX + nWidth - _nBorder, nY, _nBorder, _nBorder),
            fRect(nX, nY + nHeight - _nBorder, _nBorder, _nBorder),
            fRect(nX + nWidth - _nBorder, nY + nHeight - _nBorder, _nBorder, _nBorder),
        },
        Edges = {
            fRect(nX + _nBorder, nY, nWidth - _nBorder * 2, _nBorder),
            fRect(nX + _nBorder, nY + nHeight - _nBorder, nWidth - _nBorder * 2, _nBorder),
            fRect(nX, nY + _nBorder, _nBorder, nHeight - _nBorder * 2),
            fRect(nX + nWidth - _nBorder, nY + _nBorder, _nBorder, nHeight - _nBorder * 2),
        },
        Ornaments = {
            fRect(nX - 6, nY - 6, _nOrnament, _nOrnament),
            fRect(nX + nWidth - _nOrnament + 6, nY - 6, _nOrnament, _nOrnament),
            fRect(nX - 6, nY + nHeight - _nOrnament + 6, _nOrnament, _nOrnament),
            fRect(nX + nWidth - _nOrnament + 6, nY + nHeight - _nOrnament + 6, _nOrnament, _nOrnament),
        },
    };
end

--[[!
@fqxn wxLuma.UI.Window.create
@desc Creates a painted wxPanel. Future workbench widgets may parent to Control
      and lay out inside getGeometry().Content. PaintContent receives (DC, Content).
      Call destroy when its owning frame closes; artwork is released exactly once.
      Keep continuously animated game content on a separate child surface.
      Refreshing this native parent can invalidate otherwise unchanged HUD children.
@param wxWindow oParent Owning native window.
@param table tOptions Title, Subtitle, optional AssetPath, Decorated (true) and PaintContent callback.
    Decorated=false skips skin artwork and gives PaintContent the entire client rectangle.
@ret table oWindow Control, draw, getGeometry and destroy methods.
!]]
function Window.create(oParent, tOptions)
    tOptions = tOptions or {};
    assert(tOptions.Decorated == nil or type(tOptions.Decorated) == "boolean", "Decorated must be boolean.");
    local bDecorated = tOptions.Decorated ~= false;
    local pRoot    = tOptions.AssetPath or require("wxLuma.config").ImagePath .."/Window/";
    local oControl = _wx.wxPanel(oParent, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxTAB_TRAVERSAL + _wx.wxCLIP_CHILDREN);
    oControl:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    local tImages, tBitmaps, tEdgeBitmaps = {}, {}, {};
    local bDisposed                       = false;
    local nLastWidth, nLastHeight;
    local oSurface;
    local nSurfaceWidth, nSurfaceHeight;
    local oTitleFont = bDecorated and _wx.wxFont(20, _wx.wxFONTFAMILY_ROMAN, _wx.wxFONTSTYLE_NORMAL, _wx.wxFONTWEIGHT_NORMAL) or nil;
    local oBodyFont  = _wx.wxFont(10, _wx.wxFONTFAMILY_DEFAULT, _wx.wxFONTSTYLE_NORMAL,
        _wx.wxFONTWEIGHT_NORMAL);
    local oWindow    = _ControlObject.create({
        Control = oControl
    }, "wxLuma.UI.Window");

    --[[!
    @fqxn wxLuma.UI.Window.fLoad
    @desc Loads and validates a window image, optionally scales it to a fixed maximum dimension and
        retains its bitmap.
    @param string sName The artwork name.
    @param number|nil nSize The optional maximum image dimension.
    !]]
    local function fLoad(sName, nSize)
        local oImage = _wx.wxImage(pRoot .. sName ..".png", _wx.wxBITMAP_TYPE_PNG);
        assert(oImage:IsOk(), "Unable to load window part: " .. sName);
        tImages[sName] = oImage;
        local oScaled;
        if (nSize) then
            local nScale = nSize / math.max(oImage:GetWidth(), oImage:GetHeight());
            oScaled = oImage:Scale(math.max(1, math.floor(oImage:GetWidth() * nScale)),
                math.max(1, math.floor(oImage:GetHeight() * nScale)), _wx.wxIMAGE_QUALITY_HIGH);
        end
        tBitmaps[sName] = _wx.wxBitmap(oScaled or oImage);
        if (oScaled) then
            oScaled:delete();
        end
    end
    if (bDecorated) then
        for _, sCorner in ipairs(_tCorners) do
            fLoad("Window Corner " .. sCorner);
            fLoad("Window Ornament " .. sCorner, _nOrnament);
        end
        for _, sEdge in ipairs(_tEdges) do
            fLoad("Window Border " .. sEdge);
        end
        fLoad("Window Grain");
    end

    --[[!
    @fqxn wxLuma.UI.Window.getGeometry
    @desc Computes the content, border, corner and ornament rectangles for the current native client size.
    @ret table tGeometry The calculated pixel rectangles.
    !]]
    function oWindow.getGeometry()
        local nWidth, nHeight = oControl:GetClientSizeWH();
        if (not bDecorated) then
            local tRect = {x = 0, y = 0, width = nWidth, height = nHeight};
            return {Outer = tRect, Content = {x = 0, y = 0, width = nWidth, height = nHeight},
                Corners = {}, Edges = {}, Ornaments = {}};
        end
        return Window.geometry(nWidth, nHeight);
    end

    --[[!
    @fqxn wxLuma.UI.Window.fDrawSurface
    @desc Composes the static window artwork and text, rebuilding stretched edge bitmaps only after a
        size change.
    @param wxDC oDC The destination drawing context.
    @param number nWidth The width in client pixels.
    @param number nHeight The height in client pixels.
    !]]
    local function fDrawSurface(oDC, nWidth, nHeight)
        local tLayout     = Window.geometry(nWidth, nHeight);
        local tR          = tLayout.Outer;
        local oBackground = _wx.wxBrush(_wx.wxColour(10, 12, 16));
        oDC:SetBackground(oBackground);
        oDC:Clear();
        oDC:GradientFillLinear(_wx.wxRect(tR.x, tR.y, tR.width, tR.height),
            _wx.wxColour(31, 36, 43), _wx.wxColour(16, 19, 24), _wx.wxSOUTH);
        oDC:SetClippingRegion(tR.x + _nBorder, tR.y + _nBorder,
            tR.width - _nBorder * 2, tR.height - _nBorder * 2);

        -- Composite one opaque column, then copy it across the surface. The
        -- gradient and grain retain their original pixel coordinates; expensive
        -- alpha compositing happens once per grain row rather than per tile.
        local oStrip   = _wx.wxBitmap(64, nHeight);
        local oStripDC = _wx.wxMemoryDC();
        oStripDC:SelectObject(oStrip);
        oStripDC:GradientFillLinear(_wx.wxRect(0, tR.y, 64, tR.height),
            _wx.wxColour(31, 36, 43), _wx.wxColour(16, 19, 24), _wx.wxSOUTH);
        for nY = tR.y + _nBorder, tR.y + tR.height, 64 do
            oStripDC:DrawBitmap(tBitmaps["Window Grain"], 0, nY, true);
        end
        for nX = tR.x + _nBorder, tR.x + tR.width, 64 do
            oDC:Blit(nX, tR.y + _nBorder, 64, tR.height - _nBorder * 2,
                oStripDC, 0, tR.y + _nBorder, _wx.wxCOPY);
        end
        oStripDC:SelectObject(_wx.wxNullBitmap);
        oStripDC:delete();
        oStrip:delete();
        oDC:DestroyClippingRegion();
        if (nWidth ~= nLastWidth or nHeight ~= nLastHeight) then
            for nIndex, sEdge in ipairs(_tEdges) do
                if (tEdgeBitmaps[nIndex]) then
                    tEdgeBitmaps[nIndex]:delete();
                end
                local tEdge   = tLayout.Edges[nIndex];
                local oScaled = tImages["Window Border " .. sEdge]:Scale(
                    tEdge.width, tEdge.height, _wx.wxIMAGE_QUALITY_HIGH);
                tEdgeBitmaps[nIndex] = _wx.wxBitmap(oScaled);
                oScaled:delete();
            end
            nLastWidth, nLastHeight = nWidth, nHeight;
        end
        for nIndex, tEdge in ipairs(tLayout.Edges) do
            oDC:DrawBitmap(tEdgeBitmaps[nIndex], tEdge.x, tEdge.y, true);
        end
        for nIndex, sCorner in ipairs(_tCorners) do
            local tCorner   = tLayout.Corners[nIndex];
            local tOrnament = tLayout.Ornaments[nIndex];
            oDC:DrawBitmap(tBitmaps["Window Corner " .. sCorner], tCorner.x, tCorner.y, true);
            local oBitmap = tBitmaps["Window Ornament " .. sCorner];
            oDC:DrawBitmap(oBitmap, tOrnament.x + math.floor((_nOrnament - oBitmap:GetWidth()) / 2),
                tOrnament.y + math.floor((_nOrnament - oBitmap:GetHeight()) / 2), true);
        end
        oDC:SetBackgroundMode(_wx.wxTRANSPARENT);
        oDC:SetFont(oTitleFont);
        oDC:SetTextForeground(_wx.wxColour(211, 214, 219));
        oDC:DrawText(tOptions.Title or "UI TEST", tR.x + 62, tR.y + 27);
        oDC:SetFont(oBodyFont);
        oDC:SetTextForeground(_wx.wxColour(133, 144, 158));
        oDC:DrawText(tOptions.Subtitle or "", tR.x + 64, tR.y + 59);
        local oRule = _wx.wxPen(_wx.wxColour(62, 68, 77), 1, _wx.wxPENSTYLE_SOLID);
        oDC:SetPen(oRule);
        oDC:DrawLine(tR.x + 40, tR.y + 87, tR.x + tR.width - 40, tR.y + 87);
        oRule:delete();
        oBackground:delete();
    end

    -- Keep static artwork cached; content remains live on every paint.
    -- Draw is also usable with a memory DC for isolated native render verification.

    --[[!
    @fqxn wxLuma.UI.Window.draw
    @desc Copies cached static window artwork to the drawing context and invokes PaintContent on every draw.
    @param wxDC oDC The destination drawing context.
    @param number nWidth The width in client pixels.
    @param number nHeight The height in client pixels.
    !]]
    function oWindow.draw(oDC, nWidth, nHeight)
        if (bDisposed) then
            return;
        end
        if (not bDecorated) then
            if (tOptions.PaintContent) then
                tOptions.PaintContent(oDC, {x = 0, y = 0, width = nWidth, height = nHeight});
            else
                oDC:SetBackground(_wx.wxBLACK_BRUSH); oDC:Clear();
            end
            return;
        end
        if (not oSurface or nWidth ~= nSurfaceWidth or nHeight ~= nSurfaceHeight) then
            if (oSurface) then
                oSurface:delete();
            end
            oSurface = _wx.wxBitmap(nWidth, nHeight);
            local oMemory = _wx.wxMemoryDC();
            oMemory:SelectObject(oSurface);
            fDrawSurface(oMemory, nWidth, nHeight);
            oMemory:SelectObject(_wx.wxNullBitmap);
            oMemory:delete();
            nSurfaceWidth, nSurfaceHeight = nWidth, nHeight;
        end
        oDC:DrawBitmap(oSurface, 0, 0, false);
        if (tOptions.PaintContent) then
            tOptions.PaintContent(oDC, Window.geometry(nWidth, nHeight).Content);
        end
    end

    --[[!
    @fqxn wxLuma.UI.Window.destroy
    @desc Deletes the cached window surface, artwork, edge bitmaps and fonts once; its parent retains
        native window ownership.
    !]]
    function oWindow.destroy()
        if (bDisposed) then
            return;
        end
        bDisposed = true;
        if (oSurface) then
            oSurface:delete();
            oSurface = nil;
        end
        for _, oBitmap in pairs(tEdgeBitmaps) do
            oBitmap:delete();
        end
        for _, oBitmap in pairs(tBitmaps) do
            oBitmap:delete();
        end
        for _, oImage in pairs(tImages) do
            oImage:delete();
        end
        if (oTitleFont) then oTitleFont:delete(); end
        if (oBodyFont) then oBodyFont:delete(); end
    end
    oControl:Connect(_wx.wxEVT_PAINT, function()
        local nWidth, nHeight = oControl:GetClientSizeWH();

        -- draw already builds an opaque cached surface before copying it. Avoid
        -- a second client-sized buffering bitmap; native clipping skips children.
        local oDC = _wx.wxPaintDC(oControl);
        if (not bDisposed and nWidth >= 320 and nHeight >= 240) then
            oWindow.draw(oDC, nWidth, nHeight);
        end
        oDC:delete();
    end);
    oControl:Connect(_wx.wxEVT_SIZE, function(jEvent)
        if (not bDisposed) then
            oControl:Refresh(false);
        end
        jEvent:Skip();
    end);
    --[[!
    @fqxn wxLuma.UI.Window.isEnabled
    @desc Reports availability of the decorated surface for event subscribers.
    @ret boolean bEnabled Whether the live surface accepts input.
    !]]
    function oWindow.isEnabled()
        return not bDisposed and oControl:IsEnabled();
    end

    --[[!
    @fqxn wxLuma.UI.Window.setEnabled
    @desc Changes native surface availability without changing its artwork cache.
    @param boolean bEnabled Whether the surface accepts input.
    @ret table oWindow This surface.
    !]]
    function oWindow.setEnabled(bEnabled)
        assert(type(bEnabled) == "boolean", "Enabled flag must be boolean.");
        if (not bDisposed) then
            oControl:Enable(bEnabled);
        end
        return oWindow;
    end

    -- Keep public lifecycle state synchronized for shared native observers.
    local fDestroy = oWindow.destroy;
    oWindow.destroy = function()
        fDestroy();
        oWindow.Disposed = true;
    end;
    _Containment.attach(oWindow, oControl, tOptions);
    _Events.attach(oWindow);
    return oWindow;
end
return Window;
