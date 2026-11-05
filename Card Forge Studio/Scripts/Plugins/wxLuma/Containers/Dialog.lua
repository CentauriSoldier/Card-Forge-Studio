local _wx          = require("wx");
local _Object      = require("wxLuma.Core.ControlObject");
local _Events      = require("wxLuma.Core.ControlEvents");
local _Containment = require("wxLuma.Core.ControlContainment");
local _Button      = require("wxLuma.Widgets.PushButton");
local Dialog       = {};
local _tResults    = {ok = _wx.wxID_OK, cancel = _wx.wxID_CANCEL, yes = _wx.wxID_YES, no = _wx.wxID_NO};

--[[!
@fqxn wxLuma.UI.Dialog.create
@desc Creates a reusable dialog with a skinned client and buttons. Native title
    chrome, focus traversal and modal ownership retain platform behavior. Normal
    dialogs are independent windows; their child popups inherit dialog containment.
@param wxWindow oParent Native lifetime owner.
@param table tOptions Skin; optional Title, Width (480), Height (300), Message,
    Buttons ({ok,cancel}), DefaultResult (first), CancelResult (cancel),
    Artwork (Dialog), OnClose(result, component), Enabled.
@ret table oDialog Dialog (native), Control (painted client), Content (child parent),
    show/showModal/close/getValue, standard events and containment.
!]]
function Dialog.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "Dialog requires Skin.");
    local nWidth  = tOptions.Width or 480;
    local nHeight = tOptions.Height or 300;
    assert(type(nWidth) == "number" and nWidth % 1 == 0 and nWidth >= 320
        and type(nHeight) == "number" and nHeight % 1 == 0 and nHeight >= 200,
        "Dialog requires integer dimensions of at least 320 by 200.");
    local tButtons = {};
    local tSeen    = {};
    local tSource  = tOptions.Buttons or {"ok", "cancel"};
    assert(type(tSource) == "table" and #tSource > 0 and #tSource <= 4, "Use one to four standard buttons.");
    for nIndex, sResult in ipairs(tSource) do
        assert(_tResults[sResult] and not tSeen[sResult], "Invalid or duplicate dialog button.");
        tButtons[nIndex], tSeen[sResult] = sResult, true;
    end
    local sDefault = tOptions.DefaultResult or tButtons[1];
    local sCancel  = tOptions.CancelResult or "cancel";
    assert(tSeen[sDefault], "DefaultResult must name a displayed button.");
    assert(_tResults[sCancel], "Invalid CancelResult.");
    local oNative = _wx.wxDialog(oParent, _wx.wxID_ANY, tOptions.Title or "Dialog",
        _wx.wxDefaultPosition, _wx.wxDefaultSize, _wx.wxDEFAULT_DIALOG_STYLE + _wx.wxRESIZE_BORDER);
    oNative:SetClientSize(nWidth, nHeight);
    oNative:SetMinClientSize(_wx.wxSize(320, 200));
    local oControl = _wx.wxPanel(oNative, _wx.wxID_ANY, _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxTAB_TRAVERSAL + _wx.wxCLIP_CHILDREN);
    oControl:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    local oContent = _wx.wxPanel(oControl, _wx.wxID_ANY, _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxTAB_TRAVERSAL);
    oContent:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    local oDialog = _Object.create({
        Dialog   = oNative,
        Control  = oControl,
        Content  = oContent,
        Skin     = tOptions.Skin,
        Disposed = false,
        OnClose  = tOptions.OnClose,
        Buttons  = {},
    }, "wxLuma.UI.Dialog");
    local tEvents;
    local sArtwork = tOptions.Artwork or "Dialog";
    local bClosing = false;
    local oReturnFocus;
    local oMessage = _wx.wxStaticText(oContent, _wx.wxID_ANY, tOptions.Message or "",
        _wx.wxPoint(8, 8));
    oMessage:SetFont(oDialog.Skin.Font);
    oMessage:SetForegroundColour(_wx.wxColour(208, 218, 230));

    --[[!
    @fqxn wxLuma.UI.Dialog.isEnabled
    @desc Reports whether this live dialog accepts input.
    @ret boolean bEnabled Availability.
    !]]
    function oDialog.isEnabled()
        return not oDialog.Disposed and oNative:IsEnabled();
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.isOpen
    @desc Reports native dialog visibility without starting an event loop.
    @ret boolean bOpen Visibility.
    !]]
    function oDialog.isOpen()
        return not oDialog.Disposed and oNative:IsShown();
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.getValue
    @desc Returns the completed standard result, or nil after a new opening.
    @ret string|nil sResult ok, cancel, yes or no.
    !]]
    function oDialog.getValue()
        return oDialog.Value;
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.refresh
    @desc Requests an erase-free repaint of the skinned client.
    !]]
    function oDialog.refresh()
        if (not oDialog.Disposed) then
            oControl:Refresh(false);
        end
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.setEnabled
    @desc Enables or disables dialog input; result state is preserved.
    @param boolean bFlag Enabled state.
    @ret table oDialog This public object.
    !]]
    function oDialog.setEnabled(bFlag)
        assert(type(bFlag) == "boolean" and not oDialog.Disposed, "Invalid dialog enabled state.");
        oNative:Enable(bFlag);
        for _, oButton in pairs(oDialog.Buttons) do
            oButton.setEnabled(bFlag);
        end
        oDialog.refresh();
        return oDialog;
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.layout
    @desc Applies screen position and client size. Content remains available above
        the standard button row; applications lay out their children in Content.
    @param number nX Screen x.
    @param number nY Screen y.
    @param number nClientWidth Client width, at least 320.
    @param number nClientHeight Client height, at least 200.
    @ret table oDialog This public object.
    !]]
    function oDialog.layout(nX, nY, nClientWidth, nClientHeight)
        assert(nClientWidth >= 320 and nClientHeight >= 200, "Dialog is too small.");
        oNative:Move(nX, nY);
        oNative:SetClientSize(nClientWidth, nClientHeight);
        return oDialog;
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.close
    @desc Completes an open dialog once, hides it, ends a modal loop if present,
        then emits closed and OnClose. Title close and Escape use CancelResult.
    @param string|nil sResult Standard result; nil uses CancelResult.
    @ret table oDialog This public object.
    !]]
    function oDialog.close(sResult)
        sResult = sResult or sCancel;
        assert(_tResults[sResult], "Invalid dialog result.");
        if (not oDialog.isOpen() or bClosing) then
            return oDialog;
        end
        bClosing = true;
        oDialog.Value = sResult;
        if (oNative:IsModal()) then
            oNative:EndModal(_tResults[sResult]);
        else
            oNative:Hide();
        end
        bClosing = false;
        -- Native modal dialogs restore focus themselves. Modeless dialogs restore
        -- the previous owner control when it still accepts keyboard input.
        if (oReturnFocus) then
            pcall(function()
                if (oReturnFocus:IsShownOnScreen() and oReturnFocus:IsEnabled()) then
                    oReturnFocus:SetFocus();
                end
            end);
            oReturnFocus = nil;
        end
        local fCallback = oDialog.OnClose;
        tEvents.emit("closed", {Value = sResult, Result = sResult});
        if (fCallback) then
            fCallback(sResult, oDialog);
        end
        return oDialog;
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.fPrepare
    @desc Clears the previous result and remembers focus before a new opening.
    !]]
    local function fPrepare()
        assert(not oDialog.Disposed, "Dialog is disposed.");
        if (oDialog.isOpen() or not oDialog.isEnabled()) then
            return false;
        end
        oDialog.Value = nil;
        oReturnFocus = _wx.wxWindow.FindFocus();
        oNative:CentreOnParent();
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.show
    @desc Opens modelessly. Results arrive through closed/OnClose/getValue.
    @ret boolean bOpened False when already open or disabled.
    !]]
    function oDialog.show()
        if (not fPrepare()) then
            return false;
        end
        oNative:Show(true);
        oDialog.Buttons[sDefault].Control:SetFocus();
        tEvents.emit("opened", {Modal = false});
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.showModal
    @desc Runs the native modal loop and returns its completed standard result.
        opened is emitted once the dialog becomes visible in the modal loop.
    @ret string|nil sResult Result, or nil when already open/disabled.
    !]]
    function oDialog.showModal()
        if (not fPrepare()) then
            return nil;
        end
        local nResult = oNative:ShowModal();
        -- A completion callback may reopen the same object. Return the completed
        -- modal invocation's native result rather than its new opening's state.
        for sResult, nCode in pairs(_tResults) do
            if (nCode == nResult) then
                return sResult;
            end
        end
        return nil;
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.destroy
    @desc Ends an active modal loop as cancellation, releases button state and
        destroys the owned native dialog once. Disposal does not invoke OnClose.
    !]]
    function oDialog.destroy()
        if (oDialog.Disposed) then
            return;
        end
        oDialog.Disposed = true;
        if (oNative:IsModal()) then
            oNative:EndModal(_tResults[sCancel]);
        end
        for _, oButton in pairs(oDialog.Buttons) do
            oButton.destroy();
        end
        oNative:Destroy();
    end

    --[[!
    @fqxn wxLuma.UI.Dialog.draw
    @desc Draws the client artwork into a borrowed DC; native children draw themselves.
    @param wxDC oDC Destination.
    @param number nClientWidth Width.
    @param number nClientHeight Height.
    !]]
    function oDialog.draw(oDC, nClientWidth, nClientHeight)
        if (not oDialog.Disposed) then
            oDialog.Skin.drawOpaque(oDC, sArtwork..(oDialog.isEnabled() and " Normal" or " Disabled"),
                0, 0, math.max(1, nClientWidth), math.max(1, nClientHeight));
        end
    end

    for _, sResult in ipairs(tButtons) do
        oDialog.Buttons[sResult] = _Button.create(oControl, {Skin = oDialog.Skin,
            Text = sResult == "ok" and "OK" or sResult:sub(1, 1):upper()..sResult:sub(2),
            OnClick = function()
                oDialog.close(sResult);
            end});
    end
    --[[!
    @fqxn wxLuma.UI.Dialog.fLayout
    @desc Fits content and the action row inside the current native client area.
    !]]
    local function fLayout()
        if (oDialog.Disposed) then
            return;
        end
        local nClientWidth, nClientHeight = oControl:GetClientSizeWH();
        oContent:SetSize(16, 16, math.max(1, nClientWidth - 32), math.max(1, nClientHeight - 86));
        oMessage:Wrap(math.max(1, nClientWidth - 64));
        local nButtonWidth = math.min(100, math.floor((nClientWidth - 32 - (#tButtons - 1) * 12) / #tButtons));
        local nRowWidth    = #tButtons * nButtonWidth + (#tButtons - 1) * 12;
        for nIndex, sResult in ipairs(tButtons) do
            oDialog.Buttons[sResult].layout(nClientWidth - 16 - nRowWidth + (nIndex - 1) * (nButtonWidth + 12),
                nClientHeight - 56, nButtonWidth, 40);
        end
    end
    local oSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oSizer:Add(oControl, 1, _wx.wxEXPAND);
    oNative:SetSizer(oSizer);
    oControl:Connect(_wx.wxEVT_SIZE, function(jEvent)
        fLayout();
        jEvent:Skip();
    end);
    oControl:Connect(_wx.wxEVT_PAINT, function()
        local oDC = _wx.wxAutoBufferedPaintDC(oControl);
        oDialog.draw(oDC, oControl:GetClientSizeWH());
        oDC:delete();
    end);
    oNative:Connect(_wx.wxEVT_CLOSE_WINDOW, function(jEvent)
        if (jEvent:CanVeto()) then
            jEvent:Veto();
            oDialog.close(sCancel);
        else
            oDialog.destroy();
        end
    end);
    oNative:Connect(_wx.wxEVT_CHAR_HOOK, function(jEvent)
        if (jEvent:GetKeyCode() == _wx.WXK_ESCAPE) then
            oDialog.close(sCancel);
        elseif (jEvent:GetKeyCode() == _wx.WXK_RETURN or jEvent:GetKeyCode() == _wx.WXK_NUMPAD_ENTER) then
            -- Enter on a focused action button must retain that button's own
            -- key-release activation. Elsewhere it chooses the default result.
            local oFocus = _wx.wxWindow.FindFocus();
            for _, oButton in pairs(oDialog.Buttons) do
                if (oFocus and oFocus:GetId() == oButton.Control:GetId()) then
                    jEvent:Skip();
                    return;
                end
            end
            -- Editors that explicitly process Enter (including NumericField)
            -- retain that key for committing text; multiline editors keep newlines.
            local oText = oFocus and _wx.wxDynamicCast(oFocus, "wxTextCtrl");
            if (oText and (math.floor(oText:GetWindowStyleFlag() / _wx.wxTE_PROCESS_ENTER) % 2 == 1
                or math.floor(oText:GetWindowStyleFlag() / _wx.wxTE_MULTILINE) % 2 == 1)) then
                jEvent:Skip();
                return;
            end
            oDialog.close(sDefault);
        else
            jEvent:Skip();
        end
    end);
    oNative:Connect(_wx.wxEVT_SHOW, function(jEvent)
        if (jEvent:IsShown() and oNative:IsModal()) then
            oDialog.Buttons[sDefault].Control:SetFocus();
            tEvents.emit("opened", {Modal = true});
        end
        jEvent:Skip();
    end);
    _Containment.attach(oDialog, oControl, tOptions);
    tEvents = _Events.attach(oDialog, {oContent}, {"opened", "closed"});
    oDialog.setEnabled(tOptions.Enabled ~= false);
    oNative:Layout();
    fLayout();
    return oDialog;
end

return Dialog;
