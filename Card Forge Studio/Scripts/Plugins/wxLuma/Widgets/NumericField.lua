local _wx      = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events  = require("wxLuma.Core.ControlEvents");
local _finite  = require("wxLuma.Core.ControlNumeric").finite;
local NumericField = {};

--[[!
@fqxn wxLuma.UI.NumericField.create
@desc Creates a decimal editor. Enter/focus loss commits valid in-range text;
    invalid text restores the last value. Typing/paste accept decimal text only,
    including unfinished signs and decimal points. Step affects arrows, not typed values.
    Left/Right/Home/End remain native caret keys. Escape restores uncommitted text.
@param wxWindow oParent Native owner.
@param table tOptions Skin; optional Min (0), Max (100), Value (Min), Step (1),
    Precision (2; 0-10 decimal places), StepButtons (true), ReadOnly (false),
    Artwork (Numeric Field), Enabled, OnChange(value, component).
@ret table oComponent Editor with TextControl, standard value and policy setters.
!]]
function NumericField.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "NumericField requires Skin.");
    local nMin       = tOptions.Min == nil and 0 or tOptions.Min;
    local nMax       = tOptions.Max == nil and 100 or tOptions.Max;
    local nStep      = tOptions.Step == nil and 1 or tOptions.Step;
    local nPrecision = tOptions.Precision == nil and 2 or tOptions.Precision;
    local bButtons   = tOptions.StepButtons ~= false;
    local bReadOnly  = tOptions.ReadOnly == true;
    local sArtwork   = tOptions.Artwork or "Numeric Field";
    local tEvents;

    -- Validate before allocating native resources. Precision rounding must leave
    -- at least one representable value inside the requested range.
    --[[!
    @fqxn wxLuma.UI.NumericField.fValidate
    @desc Validates range, precision and step together before allocating or mutating state.
    !]]
    local function fValidate(nLow, nHigh, nDigits, nIncrement)
        assert(_finite(nLow) and _finite(nHigh) and nLow < nHigh, "Invalid numeric range.");
        assert(_finite(nDigits) and nDigits % 1 == 0 and nDigits >= 0 and nDigits <= 10,
            "Precision must be an integer from 0 through 10.");
        assert(_finite(nIncrement) and nIncrement > 0, "Step must be positive and finite.");
        local nScale = 10 ^ nDigits;
        assert(math.max(math.abs(nLow), math.abs(nHigh)) * nScale < 2 ^ 52,
            "Range exceeds reliable decimal precision.");
        assert(math.ceil(nLow * nScale) <= math.floor(nHigh * nScale),
            "Range contains no value at this precision.");
        assert(nIncrement >= 1 / nScale, "Step is smaller than the decimal precision.");
    end
    fValidate(nMin, nMax, nPrecision, nStep);
    assert(tOptions.Value == nil or _finite(tOptions.Value), "Value must be finite.");
    assert(tOptions.StepButtons == nil or type(tOptions.StepButtons) == "boolean", "Invalid StepButtons.");
    assert(tOptions.ReadOnly == nil or type(tOptions.ReadOnly) == "boolean", "Invalid ReadOnly.");
    local oComponent = _Surface.create(oParent, tOptions, "NumericField");
    local oText = _wx.wxTextCtrl(oComponent.Control, _wx.wxID_ANY, "", _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxTE_PROCESS_ENTER + _wx.wxTE_RIGHT);
    oComponent.TextControl = oText;
    oText:SetFont(oComponent.Skin.Font);
    oText:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    oText:SetForegroundColour(_wx.wxColour(208, 218, 230));
    oText:SetEditable(not bReadOnly);
    local nPressedPart;
    local sAcceptedText = "";
    local nEditStart, nEditEnd = 0, 0;

    --[[!
    @fqxn wxLuma.UI.NumericField.fDecimal
    @desc Accepts signed decimal text and unfinished edits, but no letters,
        whitespace, repeated signs or repeated decimal points. Completeness and
        numeric range remain commit-time checks so users can replace any value.
    @param string sText Proposed editor contents.
    @ret boolean bAccepted Whether the text can remain in the editor.
    !]]
    local function fDecimal(sText)
        return sText:match("^[+-]?%d*%.?%d*$") ~= nil;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.fRememberEdit
    @desc Records the actual current selection before native typing, deletion or
        paste so rejected edits can preserve both selection and caret.
    !]]
    local function fRememberEdit()
        local sText = oText:GetValue();
        if (fDecimal(sText)) then
            sAcceptedText = sText;
            nEditStart, nEditEnd = oText:GetSelection();
        end
    end


    -- Canonical text is separate from the stored number, avoiding repeated caret
    -- resets. Range endpoints need not themselves lie on the decimal lattice.
    --[[!
    @fqxn wxLuma.UI.NumericField.fNormalize
    @desc Clamps and rounds on the decimal lattice inside the inclusive bounds.
    !]]
    local function fNormalize(nValue)
        local nScale = 10 ^ nPrecision;
        local nLow   = math.ceil(nMin * nScale);
        local nHigh  = math.floor(nMax * nScale);
        local nUnits = math.floor(math.max(nMin, math.min(nMax, nValue)) * nScale + 0.5);
        return math.max(nLow, math.min(nHigh, nUnits)) / nScale;
    end
    --[[!
    @fqxn wxLuma.UI.NumericField.fRestore
    @desc Restores canonical decimal text without resetting an unchanged native editor.
    !]]
    local function fRestore()
        local sText = string.format("%."..nPrecision.."f", oComponent.Value);
        if (oText:GetValue() ~= sText) then
            oText:ChangeValue(sText);
        end
        fRememberEdit();
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.setValue
    @desc Clamps and rounds a finite number to the current range/precision.
        Typed values are not snapped to Step. Programmatic updates work read-only.
    @param number nValue Requested numeric value.
    @param boolean|nil bNotify Notify only on an effective value change.
    @ret table oComponent This public object.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(not oComponent.Disposed and _finite(nValue), "Value must be finite on a live field.");
        local nOld = oComponent.Value;
        nValue = fNormalize(nValue);
        oComponent.Value = nValue;
        fRestore();
        if (nOld ~= nValue) then
            oComponent.refresh();
            if (bNotify and tEvents) then
                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOld});
                if (oComponent.OnChange) then
                    oComponent.OnChange(nValue, oComponent);
                end
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.commitText
    @desc Commits complete finite in-range numeric text. Invalid edits restore the
        prior value and emit validationFailed; no value change occurs.
    @ret boolean bAccepted Whether the text was accepted.
    !]]
    function oComponent.commitText()
        if (not oComponent.isEnabled() or bReadOnly) then
            return false;
        end
        local sText  = oText:GetValue();
        local nValue = tonumber(sText);
        if (not fDecimal(sText) or not _finite(nValue) or nValue < nMin or nValue > nMax) then
            fRestore();
            tEvents.emit("validationFailed", {Text = sText});
            return false;
        end
        oComponent.setValue(nValue, true);
        tEvents.emit("committed", {Value = oComponent.Value});
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.getRange
    @desc Returns the current inclusive numeric bounds.
    @ret number nMin Minimum.
    @ret number nMax Maximum.
    !]]
    function oComponent.getRange()
        return nMin, nMax;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.setRange
    @desc Atomically validates new bounds, then clamps the current value.
    @param number nLow Minimum.
    @param number nHigh Maximum.
    @param boolean|nil bNotify Emit rangeChanged and any resulting valueChanged.
    @ret table oComponent This public object.
    !]]
    function oComponent.setRange(nLow, nHigh, bNotify)
        fValidate(nLow, nHigh, nPrecision, nStep);
        if (nLow ~= nMin or nHigh ~= nMax) then
            nMin, nMax = nLow, nHigh;
            oComponent.setValue(oComponent.Value, bNotify);
            if (bNotify) then
                tEvents.emit("rangeChanged", {Min = nMin, Max = nMax});
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.getPrecision
    @desc Returns the number of decimal places used for values and display.
    @ret number nPrecision Decimal places.
    !]]
    function oComponent.getPrecision()
        return nPrecision;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.setPrecision
    @desc Validates decimal precision before rounding the current value.
    @param number nDigits Decimal places from zero through ten.
    @param boolean|nil bNotify Notify precision and resulting value changes.
    @ret table oComponent This public object.
    !]]
    function oComponent.setPrecision(nDigits, bNotify)
        fValidate(nMin, nMax, nDigits, nStep);
        if (nDigits ~= nPrecision) then
            nPrecision = nDigits;
            oComponent.setValue(oComponent.Value, bNotify);
            if (bNotify) then
                tEvents.emit("precisionChanged", {Precision = nPrecision});
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.getStep
    @desc Returns the keyboard/button increment.
    @ret number nStep Positive increment.
    !]]
    function oComponent.getStep()
        return nStep;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.setStep
    @desc Changes the increment without snapping or changing the current value.
    @param number nIncrement Positive increment representable at this precision.
    @param boolean|nil bNotify Emit stepChanged after a change.
    @ret table oComponent This public object.
    !]]
    function oComponent.setStep(nIncrement, bNotify)
        fValidate(nMin, nMax, nPrecision, nIncrement);
        if (nIncrement ~= nStep) then
            nStep = nIncrement;
            if (bNotify) then
                tEvents.emit("stepChanged", {Step = nStep});
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.isReadOnly
    @desc Returns whether user edits and stepping are disabled.
    @ret boolean bReadOnly Editing policy.
    !]]
    function oComponent.isReadOnly()
        return bReadOnly;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.setReadOnly
    @desc Changes editing policy and discards any uncommitted text.
    @param boolean bFlag Read-only policy.
    @param boolean|nil bNotify Emit readOnlyChanged after a change.
    @ret table oComponent This public object.
    !]]
    function oComponent.setReadOnly(bFlag, bNotify)
        assert(type(bFlag) == "boolean", "ReadOnly must be boolean.");
        if (bFlag ~= bReadOnly) then
            bReadOnly = bFlag;
            nPressedPart = nil;
            oComponent.cancel();
            fRestore();
            oText:SetEditable(not bReadOnly);
            oComponent.refresh();
            if (bNotify) then
                tEvents.emit("readOnlyChanged", {ReadOnly = bReadOnly});
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.NumericField.fStep
    @desc Commits pending text before applying a bounded user increment.
    !]]
    local function fStep(nDirection)
        if (not oComponent.isEnabled() or bReadOnly) then
            return false;
        end
        -- Commit valid edits first; invalid text is restored before stepping.
        oComponent.commitText();
        if (not oComponent.Disposed) then
            local nValue = math.max(nMin, math.min(nMax, oComponent.Value + nDirection * nStep));
            oComponent.setValue(nValue, true);
        end
        return true;
    end
    --[[!
    @fqxn wxLuma.UI.NumericField.fPart
    @desc Returns the upper or lower step-button region, or nil outside the buttons.
    !]]
    local function fPart(nX, nY)
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        if (bButtons and nX >= nWidth - 26 and nX < nWidth and nY >= 0 and nY < nHeight) then
            return nY < nHeight / 2 and 1 or -1;
        end
    end

    -- Preserve native text navigation. Only numeric stepping keys are consumed.
    oComponent.key = function(nKey)
        if (bReadOnly) then
            return false;
        end
        if (nKey == _wx.WXK_UP or nKey == _wx.WXK_DOWN) then
            return fStep(nKey == _wx.WXK_UP and 1 or -1);
        elseif (nKey == _wx.WXK_PAGEUP or nKey == _wx.WXK_PAGEDOWN) then
            return fStep(nKey == _wx.WXK_PAGEUP and 10 or -10);
        elseif (nKey == _wx.WXK_ESCAPE) then
            fRestore();
            return true;
        end
        return false;
    end;
    oComponent.pointer = function(sEvent, nX, nY)
        if (sEvent == "down") then
            nPressedPart = fPart(nX, nY);
            if (not nPressedPart) then
                oComponent.cancel();
                oText:SetFocus();
            end
        elseif (sEvent == "up") then
            local nPart = nPressedPart;
            nPressedPart = nil;
            if (nPart and nPart == fPart(nX, nY)) then
                fStep(nPart);
            end
        end
    end;
    oComponent.onCancel = function()
        nPressedPart = nil;
    end;
    oComponent.onLayout = function(nWidth, nHeight)
        oText:SetSize(8, math.max(2, math.floor((nHeight - 23) / 2)),
            math.max(1, nWidth - (bButtons and 40 or 16)), 23);
    end;
    oComponent.onEnable = function(bEnabled)
        oText:Enable(bEnabled);
        oText:Show(bEnabled);
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end
        local sState = oComponent.getState();
        oComponent.Skin.drawOpaque(oDC, sArtwork.." "..sState, 0, 0,
            math.max(1, nWidth), math.max(1, nHeight));
        if (bButtons) then
            for nIndex, sDirection in ipairs({"Up", "Down"}) do
                local sArrowState = (not oComponent.isEnabled() or bReadOnly) and "Disabled" or sState;
                oComponent.Skin.draw(oDC, "Spinner "..sDirection.." "..sArrowState,
                    nWidth - 26, (nIndex - 1) * nHeight / 2, 24, math.max(1, math.floor(nHeight / 2)));
            end
        end
        if (not oComponent.isEnabled()) then
            oComponent.Skin.text(oDC, oText:GetValue(), 8, (nHeight - 18) / 2, false);
        end
    end;
    oText:Connect(_wx.wxEVT_COMMAND_TEXT_ENTER, function()
        oComponent.commitText();
    end);
    oText:Connect(_wx.wxEVT_KILL_FOCUS, function(jEvent)
        oComponent.commitText();
        jEvent:Skip();
    end);
    oText:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        fRememberEdit();
        if (not oComponent.handleKey("down", jEvent:GetKeyCode())) then
            jEvent:Skip();
        end
    end);
    -- Reject printable characters before native insertion. Checking the whole
    -- replacement permits a sign/point only where the selection makes it valid.
    -- Native shortcuts, deletion and navigation continue through wxWidgets.
    oText:Connect(_wx.wxEVT_CHAR, function(jEvent)
        fRememberEdit();
        local nKey = jEvent:GetKeyCode();
        if (nKey < 32 or nKey == _wx.WXK_DELETE or nKey >= _wx.WXK_START
            or jEvent:ControlDown() or jEvent:MetaDown()) then
            jEvent:Skip();
            return;
        end
        if (nKey >= 32 and nKey <= 126) then
            local sText = oText:GetValue();
            local nStart, nEnd = oText:GetSelection();
            local sNext = sText:sub(1, nStart)..string.char(nKey)..sText:sub(nEnd + 1);
            if (fDecimal(sNext)) then
                jEvent:Skip();
            end
        end
    end);

    -- Context-menu paste has no preceding key event. Capture its selection too
    -- when the binding provides this event; text-updated guards all edit sources.
    if (_wx.wxEVT_TEXT_PASTE) then
        oText:Connect(_wx.wxEVT_TEXT_PASTE, function(jEvent)
            fRememberEdit();
            jEvent:Skip();
        end);
    end
    tEvents = _Events.attach(oComponent, {oText}, {"committed", "validationFailed",
        "rangeChanged", "precisionChanged", "stepChanged", "readOnlyChanged", "textChanged"});
    oText:Connect(_wx.wxEVT_COMMAND_TEXT_UPDATED, function()
        if (oComponent.Disposed) then
            return;
        end
        local sText = oText:GetValue();
        if (not fDecimal(sText)) then
            -- Reject the entire invalid paste/edit rather than silently dropping
            -- characters and turning a pasted value into a different number.
            oText:ChangeValue(sAcceptedText);
            oText:SetSelection(nEditStart, nEditEnd);
            return;
        end
        if (sText ~= sAcceptedText) then
            fRememberEdit();
            tEvents.emit("textChanged", {Text = sText});
        end
    end);
    oComponent.setValue(tOptions.Value == nil and nMin or tOptions.Value);
    oComponent.setEnabled(tOptions.Enabled ~= false);
    return oComponent;
end

return NumericField;
