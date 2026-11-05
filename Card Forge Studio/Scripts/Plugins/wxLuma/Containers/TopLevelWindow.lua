local _wx     = require("wx");
local _Events = require("wxLuma.Core.ControlEvents");
local _Object = require("wxLuma.Core.ControlObject");
local _Window = require("wxLuma.Containers.Window");
local _Skin   = require("wxLuma.Core.ControlSkin");
local _Button = require("wxLuma.Widgets.PushButton");
local TopLevelWindow = {};

--[[!
@fqxn wxLuma.UI.TopLevelWindow.create
@desc Owns a native wxFrame, skinned Window surface and optional window actions.
    Borderless frames use shared pointer adapters for title dragging and eight-edge
    resizing. Native framed windows retain OS chrome and behavior. Caller owns the
    event loop and application widgets. Close honors native veto; destroy is explicit.
@param wxWindow oParent Native parent, or wx.NULL.
@param table tOptions Title, Subtitle, Width/Height (800/600), MinWidth/MinHeight
    (320/240), Borderless (false), Draggable/Resizable (true), MinimizeButton,
    MaximizeButton, CloseButton (true), optional Skin (borrowed), SkinPath, AssetPath,
    PaintContent(DC, contentRect), OnClose(component, closeEvent).
@ret table oWindow Frame, Control, Surface, Buttons, window actions and pointer adapter.
!]]
function TopLevelWindow.create(oParent, tOptions)
    tOptions = tOptions or {};
    local nWidth, nHeight = tOptions.Width or 800, tOptions.Height or 600;
    local nMinWidth, nMinHeight = tOptions.MinWidth or 320, tOptions.MinHeight or 240;
    for _, nValue in ipairs({nWidth, nHeight, nMinWidth, nMinHeight}) do
        assert(type(nValue) == "number" and nValue % 1 == 0 and nValue > 0
            and nValue <= 32767, "Window dimensions must be positive integers through 32767.");
    end
    assert(nMinWidth >= 320 and nMinHeight >= 240 and nWidth >= nMinWidth and nHeight >= nMinHeight,
        "Window dimensions must respect its minimum of at least 320 by 240.");
    for _, sKey in ipairs({"Borderless", "Draggable", "Resizable", "MinimizeButton", "MaximizeButton", "CloseButton"}) do
        assert(tOptions[sKey] == nil or type(tOptions[sKey]) == "boolean", sKey.." must be boolean.");
    end
    assert(tOptions.Title == nil or type(tOptions.Title) == "string", "Title must be a string.");
    assert(tOptions.OnClose == nil or type(tOptions.OnClose) == "function", "OnClose must be a function.");
    local bBorderless = tOptions.Borderless == true;
    local nStyle = bBorderless and _wx.wxBORDER_NONE or _wx.wxDEFAULT_FRAME_STYLE;
    if (not bBorderless and tOptions.Resizable == false) then
        nStyle = nStyle - _wx.wxRESIZE_BORDER - _wx.wxMAXIMIZE_BOX;
    end
    local oFrame = _wx.wxFrame(oParent or _wx.NULL, _wx.wxID_ANY, tOptions.Title or "",
        _wx.wxDefaultPosition, _wx.wxSize(nWidth, nHeight), nStyle);
    oFrame:SetClientSize(nWidth, nHeight);
    oFrame:SetMinClientSize(_wx.wxSize(nMinWidth, nMinHeight));
    local oSurface = _Window.create(oFrame, tOptions);
    local oControl = oSurface.Control;
    local oSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oSizer:Add(oControl, 1, _wx.wxEXPAND); oFrame:SetSizer(oSizer);
    local bOwnSkin = tOptions.Skin == nil;
    local oSkin = tOptions.Skin or _Skin.load(tOptions.SkinPath);
    local tButtons, tCursors = {}, {};
    local tDrag;
    local oRestoreCursor;
    local bFrameDestroyed = false;
    local oWindow = _Object.create({Frame = oFrame, Control = oControl, Surface = oSurface,
        Buttons = {}, Disposed = false}, "wxLuma.UI.TopLevelWindow");
    for sEdge, nCursor in pairs({move = _wx.wxCURSOR_ARROW, left = _wx.wxCURSOR_SIZEWE,
        right = _wx.wxCURSOR_SIZEWE, top = _wx.wxCURSOR_SIZENS, bottom = _wx.wxCURSOR_SIZENS,
        topleft = _wx.wxCURSOR_SIZENWSE, bottomright = _wx.wxCURSOR_SIZENWSE,
        topright = _wx.wxCURSOR_SIZENESW, bottomleft = _wx.wxCURSOR_SIZENESW}) do
        tCursors[sEdge] = _wx.wxCursor(nCursor);
    end

    -- Override the application cursor only while showing a resize affordance.
    local function fRestoreCursor()
        if (oRestoreCursor) then
            oControl:SetCursor(oRestoreCursor);
            oRestoreCursor:delete(); oRestoreCursor = nil;
        end
    end
    local function fCancel(bRestore)
        local tPrevious = tDrag; tDrag = nil;
        if (oControl:HasCapture()) then oControl:ReleaseMouse(); end
        if (bRestore and tPrevious) then oFrame:SetSize(tPrevious.X, tPrevious.Y, tPrevious.Width, tPrevious.Height); end
    end
    local function fLayout()
        if (oWindow.Disposed) then return; end
        local nW = oControl:GetClientSizeWH();
        local bShow = bBorderless and not oFrame:IsFullScreen();
        for nIndex, oButton in ipairs(tButtons) do
            oButton.Control:Show(bShow);
            if (bShow) then oButton.layout(nW - 34 - (#tButtons - nIndex + 1) * 42, 30, 40, 36); oButton.Control:Raise(); end
        end
    end

    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.show
    @param boolean|nil bShow Show unless explicitly false.
    @ret table oWindow This window.
    !]]
    function oWindow.show(bShow)
        assert(not oWindow.Disposed, "Window is disposed.");
        oFrame:Show(bShow ~= false); oFrame:Layout(); fLayout(); return oWindow;
    end
    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.showFullScreen
    @param boolean bShow Enter or leave native fullscreen; window actions hide while fullscreen.
    @ret table oWindow This window.
    !]]
    function oWindow.showFullScreen(bShow)
        assert(not oWindow.Disposed and type(bShow) == "boolean", "Fullscreen requires a live window and boolean.");
        fCancel(false); oFrame:ShowFullScreen(bShow); oFrame:Layout(); fLayout(); return oWindow;
    end
    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.minimize
    @ret table oWindow This window.
    !]]
    function oWindow.minimize()
        assert(not oWindow.Disposed, "Window is disposed.");
        fCancel(false); oFrame:Iconize(true); return oWindow;
    end
    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.maximize
    @param boolean|nil bMaximize Maximize unless explicitly false (restore).
    @ret table oWindow This window.
    !]]
    function oWindow.maximize(bMaximize)
        assert(not oWindow.Disposed and (bMaximize == nil or type(bMaximize) == "boolean"), "Invalid maximize request.");
        fCancel(false);
        if (oFrame:IsFullScreen()) then oWindow.showFullScreen(false); end
        if (oFrame:IsIconized()) then oFrame:Iconize(false); end
        oFrame:Maximize(bMaximize ~= false); fLayout(); return oWindow;
    end
    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.restore
    @desc Leaves fullscreen, unminimizes and restores maximized windows.
    @ret table oWindow This window.
    !]]
    function oWindow.restore()
        assert(not oWindow.Disposed, "Window is disposed.");
        fCancel(false);
        if (oFrame:IsFullScreen()) then oWindow.showFullScreen(false); end
        if (oFrame:IsIconized()) then oFrame:Iconize(false); end
        oFrame:Maximize(false); fLayout(); return oWindow;
    end
    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.close
    @desc Requests native close; OnClose/native handlers may veto it.
    @ret boolean bClosed Native close request result.
    !]]
    function oWindow.close()
        if (oWindow.Disposed) then return false; end
        fCancel(false); return oFrame:Close();
    end
    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.hitTest
    @desc Returns title move or edge/corner role for screen coordinates; nil over content,
        fullscreen/maximized windows, disabled policies or native-framed windows.
    @param number nX Screen x.
    @param number nY Screen y.
    @ret string|nil sRole move/left/right/top/bottom/topleft/topright/bottomleft/bottomright.
    !]]
    function oWindow.hitTest(nX, nY)
        if (oWindow.Disposed or not bBorderless or oFrame:IsFullScreen() or oFrame:IsMaximized()) then return nil; end
        local nLeft, nTop = oFrame:GetPositionXY();
        local nW, nH = oFrame:GetSizeWH();
        local nLocalX, nLocalY = nX - nLeft, nY - nTop;
        if (nLocalX < 0 or nLocalY < 0 or nLocalX >= nW or nLocalY >= nH) then return nil; end
        if (tOptions.Resizable ~= false) then
            local sVertical = nLocalY < 10 and "top" or nLocalY >= nH - 10 and "bottom" or "";
            local sHorizontal = nLocalX < 10 and "left" or nLocalX >= nW - 10 and "right" or "";
            if (sVertical ~= "" or sHorizontal ~= "") then return sVertical..sHorizontal; end
        end
        if (tOptions.Draggable ~= false and nLocalY >= 10 and nLocalY < 84) then return "move"; end
        return nil;
    end
    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.handlePointer
    @desc Native pointer adapter; screen coordinates preserve drag anchors while the frame moves.
        Escape restores drag-start geometry; capture loss/deactivation ends the gesture.
    @param string sEvent down/move/up/cancel.
    @param number nX Screen x.
    @param number nY Screen y.
    !]]
    function oWindow.handlePointer(sEvent, nX, nY)
        if (oWindow.Disposed) then return; end
        if (sEvent == "cancel") then fCancel(true); return; end
        if (sEvent == "down") then
            local sRole = oWindow.hitTest(nX, nY);
            if (not sRole) then return; end
            local nLeft, nTop = oFrame:GetPositionXY(); local nW, nH = oFrame:GetSizeWH();
            tDrag = {Role = sRole, MouseX = nX, MouseY = nY, X = nLeft, Y = nTop, Width = nW, Height = nH};
            if (not oControl:HasCapture()) then oControl:CaptureMouse(); end
        elseif ((sEvent == "move" or sEvent == "up") and tDrag) then
            local nDX, nDY = nX - tDrag.MouseX, nY - tDrag.MouseY;
            local nLeft, nTop, nW, nH = tDrag.X, tDrag.Y, tDrag.Width, tDrag.Height;
            if (tDrag.Role == "move") then
                nLeft, nTop = nLeft + nDX, nTop + nDY;
            else
                if (tDrag.Role:find("left", 1, true)) then nW = math.max(nMinWidth, nW - nDX); nLeft = tDrag.X + tDrag.Width - nW; end
                if (tDrag.Role:find("right", 1, true)) then nW = math.max(nMinWidth, nW + nDX); end
                if (tDrag.Role:find("top", 1, true)) then nH = math.max(nMinHeight, nH - nDY); nTop = tDrag.Y + tDrag.Height - nH; end
                if (tDrag.Role:find("bottom", 1, true)) then nH = math.max(nMinHeight, nH + nDY); end
            end
            oFrame:SetSize(math.floor(nLeft), math.floor(nTop), math.floor(nW), math.floor(nH));
            if (sEvent == "up") then fCancel(false); end
        elseif (sEvent == "move") then
            local sRole = oWindow.hitTest(nX, nY);
            if (sRole and sRole ~= "move") then
                if (not oRestoreCursor) then oRestoreCursor = _wx.wxCursor(oControl:GetCursor()); end
                oControl:SetCursor(tCursors[sRole]);
            else
                fRestoreCursor();
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.dispose
    @desc Releases framework-owned drawing/input resources once; keeps the native frame.
        Applications may call this after disposing their own widgets during normal close.
    !]]
    function oWindow.dispose()
        if (oWindow.Disposed) then return; end
        fCancel(false); fRestoreCursor(); oWindow.Disposed = true;
        for _, oButton in ipairs(tButtons) do oButton.destroy(); end
        oSurface.destroy();
        for _, oCursor in pairs(tCursors) do oCursor:delete(); end
        if (bOwnSkin) then oSkin.destroy(); end
    end
    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.destroy
    @desc Explicitly disposes resources and destroys the native frame, bypassing close veto.
    !]]
    function oWindow.destroy()
        if (bFrameDestroyed) then return; end
        oWindow.dispose(); bFrameDestroyed = true; oFrame:Destroy();
    end
    for _, tAction in ipairs({
        {Key = "Minimize", Text = "_", Enabled = tOptions.MinimizeButton, Action = oWindow.minimize},
        {Key = "Maximize", Text = "[]", Enabled = tOptions.MaximizeButton,
            Action = function() oWindow.maximize(not oFrame:IsMaximized()); end},
        {Key = "Close", Text = "X", Enabled = tOptions.CloseButton, Action = oWindow.close}
    }) do
        if (bBorderless and tAction.Enabled ~= false) then
            local oButton = _Button.create(oFrame, {Skin = oSkin, Text = tAction.Text, OnClick = tAction.Action});
            tButtons[#tButtons + 1] = oButton; oWindow.Buttons[tAction.Key] = oButton;
        end
    end
    for _, tBinding in ipairs({{_wx.wxEVT_LEFT_DOWN, "down"}, {_wx.wxEVT_MOTION, "move"}, {_wx.wxEVT_LEFT_UP, "up"}}) do
        local sEvent = tBinding[2];
        oControl:Connect(tBinding[1], function(oEvent)
            local oPoint = oControl:ClientToScreen(oEvent:GetPosition());
            oWindow.handlePointer(sEvent, oPoint:GetX(), oPoint:GetY());
            oEvent:Skip();
        end);
    end
    oControl:Connect(_wx.wxEVT_LEFT_DCLICK, function(oEvent)
        local nX, nY = oEvent:GetX(), oEvent:GetY();
        local nWidth = oControl:GetClientSizeWH();
        if (bBorderless and tOptions.Resizable ~= false and not oFrame:IsFullScreen()
            and nY >= 10 and nY < 84 and nX >= 10 and nX < nWidth - 10) then
            oWindow.maximize(not oFrame:IsMaximized());
        else oEvent:Skip(); end
    end);
    oControl:Connect(_wx.wxEVT_LEAVE_WINDOW, function(oEvent)
        if (not oWindow.Disposed and not tDrag) then fRestoreCursor(); end
        oEvent:Skip();
    end);
    oControl:Connect(_wx.wxEVT_MOUSE_CAPTURE_LOST, function() tDrag = nil; end);
    oFrame:Connect(_wx.wxEVT_ACTIVATE, function(oEvent)
        if (not oEvent:GetActive() and not oWindow.Disposed) then fCancel(false); end
        oEvent:Skip();
    end);
    oFrame:Connect(_wx.wxEVT_CHAR_HOOK, function(oEvent)
        if (tDrag and oEvent:GetKeyCode() == _wx.WXK_ESCAPE) then fCancel(true); else oEvent:Skip(); end
    end);
    oControl:Connect(_wx.wxEVT_SIZE, function(oEvent) fLayout(); oEvent:Skip(); end);
    oFrame:Connect(_wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (tOptions.OnClose) then tOptions.OnClose(oWindow, oEvent); end
        oEvent:Skip();
    end);
    local nFrameID = oFrame:GetId();
    oFrame:Connect(_wx.wxEVT_DESTROY, function(oEvent)
        if (oEvent:GetId() == nFrameID) then bFrameDestroyed = true; oWindow.dispose(); end
        oEvent:Skip();
    end);
    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.isEnabled
    @desc Reports whether this live native frame accepts interaction.
    @ret boolean bEnabled Current frame availability.
    !]]
    function oWindow.isEnabled()
        return not oWindow.Disposed and oFrame:IsEnabled();
    end

    --[[!
    @fqxn wxLuma.UI.TopLevelWindow.setEnabled
    @desc Changes frame availability, including its native child controls.
    @param boolean bEnabled Whether interaction is enabled.
    @ret table oWindow This public window.
    !]]
    function oWindow.setEnabled(bEnabled)
        assert(type(bEnabled) == "boolean", "Enabled flag must be boolean.");
        if (not oWindow.Disposed) then
            oFrame:Enable(bEnabled);
        end
        return oWindow;
    end

    _Events.attach(oWindow, {oFrame});
    oFrame:Layout(); fLayout();
    return oWindow;
end
return TopLevelWindow;
