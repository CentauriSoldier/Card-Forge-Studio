local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _Containment = require("wxLuma.Core.ControlContainment");
local _Date = require("wxLuma.Core.ControlDateTime");
local DateTimePicker = {};

--[[!
@fqxn wxLuma.UI.DateTimePicker.create
@desc Creates a skinned ISO editor and reusable calendar/time popup. Mode date
    uses YYYY-MM-DD, time uses HH:MM, datetime combines them with a space. Enter
    and focus loss commit valid text; invalid edits restore the accepted value.
    Calendar cells, navigation, time actions and surface are all skin materials.
@param wxWindow oParent Native owner.
@param table tOptions Skin, optional Mode (date), Value (local current date/time),
    Min/Max (ISO bounds), ReadOnly, Artwork, Enabled, OnChange(value, component).
@ret table oComponent Value/range/read-only APIs, open/close/isOpen, TextControl,
    Calendar surface and shared pointer/keyboard events.
!]]
function DateTimePicker.create(oParent, tOptions)
    local sMode = tOptions.Mode or "date";
    assert(sMode == "date" or sMode == "time" or sMode == "datetime", "Invalid date/time Mode.");
    local sValue = tOptions.Value or os.date(sMode == "date" and "%Y-%m-%d" or sMode == "time" and "%H:%M" or "%Y-%m-%d %H:%M");
    local sMin, sMax = tOptions.Min, tOptions.Max;
    local bReadOnly = tOptions.ReadOnly == true;
    assert(tOptions.ReadOnly == nil or type(tOptions.ReadOnly) == "boolean", "Invalid ReadOnly.");
    assert(_Date.parse(sValue, sMode) and (sMin == nil or _Date.parse(sMin, sMode))
        and (sMax == nil or _Date.parse(sMax, sMode)) and (not sMin or not sMax or sMin <= sMax)
        and (not sMin or sValue >= sMin) and (not sMax or sValue <= sMax), "Invalid date/time value or bounds.");
    local oComponent = _Surface.create(oParent, tOptions, "DateTimePicker");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Date Time Picker");
    local oText = _wx.wxTextCtrl(oComponent.Control, _wx.wxID_ANY, sValue, _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxTE_PROCESS_ENTER);
    oText:SetFont(tOptions.Skin.Font);
    oText:SetBackgroundColour(tArt.color("Editor Normal"));
    oText:SetForegroundColour(tArt.color("Text Normal"));
    oText:SetEditable(not bReadOnly);
    oComponent.TextControl = oText;
    local tEvents = _Events.attach(oComponent, {oText}, {"opened", "closed", "invalidInput", "rangeChanged", "readOnlyChanged"});
    local oPopup = _wx.wxFrame(oComponent.Control, _wx.wxID_ANY, "", _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxFRAME_NO_TASKBAR + _wx.wxFRAME_FLOAT_ON_PARENT + _wx.wxBORDER_NONE);
    local oCalendar = _Surface.create(oPopup, {Skin = tOptions.Skin}, "Calendar");
    oComponent.Popup, oComponent.Calendar = oPopup, oCalendar;
    tEvents.extend({oCalendar.Control});
    local tContainment = _Containment.getPolicy(oComponent);
    local bOpen = false;
    local tDate = _Date.parse(sValue, sMode);
    local nYear, nMonth = tDate.Year, tDate.Month;
    local nTimeTop = sMode == "time" and 8 or 254;
    local nPopupHeight = sMode == "date" and 252 or sMode == "time" and 84 or 330;

    --[[!
    @fqxn wxLuma.UI.DateTimePicker.getValue
    @desc Returns the last valid ISO value, never an unfinished native edit.
    !]]
    function oComponent.getValue() return sValue; end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.setValue
    @desc Validates date/time and bounds before mutation; optional notifications contain accepted ISO values.
    !]]
    function oComponent.setValue(sNext, bNotify)
        local tNext = _Date.parse(sNext, sMode);
        assert(tNext and (not sMin or sNext >= sMin) and (not sMax or sNext <= sMax), "Invalid/out-of-range date/time.");
        if (oComponent.Disposed) then return oComponent; end
        local sOld = sValue;
        sValue, tDate = sNext, tNext;
        nYear, nMonth = tDate.Year, tDate.Month;
        if (oText:GetValue() ~= sNext) then oText:ChangeValue(sNext); end
        oCalendar.refresh();
        if (sOld ~= sNext and bNotify) then
            tEvents.emit("valueChanged", {Value = sNext, OldValue = sOld});
            if (oComponent.OnChange) then oComponent.OnChange(sNext, oComponent); end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.getRange
    @desc Returns optional minimum and maximum ISO bounds.
    !]]
    function oComponent.getRange() return sMin, sMax; end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.setRange
    @desc Validates optional ISO bounds, then fits current before optional range notification.
    !]]
    function oComponent.setRange(sLow, sHigh, bNotify)
        assert((sLow == nil or _Date.parse(sLow, sMode)) and (sHigh == nil or _Date.parse(sHigh, sMode))
            and (not sLow or not sHigh or sLow <= sHigh), "Invalid date/time bounds.");
        if (not oComponent.Disposed and (sLow ~= sMin or sHigh ~= sMax)) then
            sMin, sMax = sLow, sHigh;
            oComponent.setValue(sMin and sValue < sMin and sMin or sMax and sValue > sMax and sMax or sValue);
            if (bNotify) then tEvents.emit("rangeChanged", {Min = sMin, Max = sMax}); end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.isReadOnly
    @desc Reports whether editing and popup selection are blocked.
    !]]
    function oComponent.isReadOnly() return bReadOnly; end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.setReadOnly
    @desc Changes editing policy; entering read-only dismisses the calendar.
    !]]
    function oComponent.setReadOnly(bNext, bNotify)
        assert(type(bNext) == "boolean", "ReadOnly must be boolean.");
        if (not oComponent.Disposed and bNext ~= bReadOnly) then
            bReadOnly = bNext; oText:SetEditable(not bNext);
            if (bNext) then oComponent.close(); end
            if (bNotify) then tEvents.emit("readOnlyChanged", {ReadOnly = bNext}); end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.commit
    @desc Accepts a valid editor value or restores the prior value without changing state on failure.
    !]]
    function oComponent.commit()
        local sNext = oText:GetValue();
        if (not _Date.parse(sNext, sMode) or sMin and sNext < sMin or sMax and sNext > sMax) then
            oText:ChangeValue(sValue); tEvents.emit("invalidInput", {Text = sNext}); return false;
        end
        oComponent.setValue(sNext, true);
        return true;
    end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.isOpen
    @desc Returns popup visibility without entering another event loop.
    !]]
    function oComponent.isOpen() return bOpen and not oComponent.Disposed; end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.close
    @desc Dismisses the reusable popup without creating, destroying or changing its value.
    !]]
    function oComponent.close()
        if (bOpen) then bOpen = false; oCalendar.cancel(); oPopup:Hide(); tEvents.emit("closed"); end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.open
    @desc Opens a contained, skinned calendar/time popup when editable and enabled.
    !]]
    function oComponent.open()
        if (not oComponent.isEnabled() or bReadOnly or bOpen) then return false; end
        oComponent.commit(); nYear, nMonth = tDate.Year, tDate.Month;
        oPopup:SetClientSize(294, nPopupHeight); oCalendar.layout(0, 0, 294, nPopupHeight);
        if (not tContainment.place(oPopup)) then return false; end
        bOpen = true; oPopup:Show(true); oCalendar.Control:SetFocus(); tEvents.emit("opened"); return true;
    end

    --[[!
    @fqxn wxLuma.UI.DateTimePicker.calendar.choose
    @desc Commits a valid in-range calendar candidate, preserving time; out-of-range cells do nothing.
    !]]
    local function fChoose(nDay)
        local tNext = {Year = nYear, Month = nMonth, Day = nDay, Hour = tDate.Hour, Minute = tDate.Minute};
        local sNext = _Date.format(tNext, sMode);
        if (not sMin or sNext >= sMin) and (not sMax or sNext <= sMax) then
            oComponent.setValue(sNext, true);
            if (sMode == "date") then oComponent.close(); end
        end
    end
    --[[!
    @fqxn wxLuma.UI.DateTimePicker.calendar.month
    @desc Changes the viewed month inside years 1..9999 without changing the accepted date.
    !]]
    local function fMonth(nDelta)
        local nNext = (nYear - 1) * 12 + nMonth - 1 + nDelta;
        if (nNext >= 0 and nNext < 9999 * 12) then
            nYear, nMonth = math.floor(nNext / 12) + 1, nNext % 12 + 1; oCalendar.refresh();
        end
    end
    oCalendar.pointer = function(sEvent, nX, nY)
        if (not bOpen or not oComponent.isEnabled() or bReadOnly
            or sEvent ~= "up" or not oCalendar.Pressed or not oCalendar.Hover) then return; end
        if (sMode ~= "time" and nY < 34) then
            if (nX < 38) then fMonth(-1); elseif (nX > 256) then fMonth(1); end
        elseif (sMode ~= "time" and nY >= 58 and nY < 250) then
            local nDay = math.floor((nY - 58) / 32) * 7 + math.floor((nX - 7) / 40) - _Date.weekday(nYear, nMonth, 1) + 1;
            if (nX >= 7 and nX < 287 and nDay >= 1 and nDay <= _Date.days(nYear, nMonth)) then fChoose(nDay); end
        elseif (sMode ~= "date" and nY >= nTimeTop + 28 and nY < nTimeTop + 62) then
            local nAction = math.floor(nX / 73);
            local tNext = _Date.parse(sValue, sMode);
            if (nAction == 0) then tNext.Hour = (tNext.Hour + 23) % 24;
            elseif (nAction == 1) then tNext.Hour = (tNext.Hour + 1) % 24;
            elseif (nAction == 2) then tNext.Minute = (tNext.Minute + 59) % 60;
            elseif (nAction == 3) then tNext.Minute = (tNext.Minute + 1) % 60; end
            local sNext = _Date.format(tNext, sMode);
            if ((not sMin or sNext >= sMin) and (not sMax or sNext <= sMax)) then oComponent.setValue(sNext, true); end
        end
    end;
    oCalendar.key = function(nKey)
        if (not bOpen or not oComponent.isEnabled() or bReadOnly) then return false; end
        if (nKey == _wx.WXK_ESCAPE) then oComponent.close(); oText:SetFocus(); return true; end
        if (sMode ~= "time") then
            if (nKey == _wx.WXK_PAGEUP) then fMonth(-1); return true;
            elseif (nKey == _wx.WXK_PAGEDOWN) then fMonth(1); return true; end
            local nDelta = nKey == _wx.WXK_LEFT and -1 or nKey == _wx.WXK_RIGHT and 1
                or nKey == _wx.WXK_UP and -7 or nKey == _wx.WXK_DOWN and 7;
            if (nDelta) then
                local nDay = math.max(1, math.min(_Date.days(nYear, nMonth), tDate.Day + nDelta));
                fChoose(nDay); return true;
            end
        end
        if (nKey == _wx.WXK_RETURN) then oComponent.close(); oText:SetFocus(); return true; end
        return false;
    end;
    oCalendar.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        local sState = oComponent.getState();
        tArt.part(oDC, "Calendar "..sState, 0, 0, nWidth, nHeight);
        if (sMode ~= "time") then
            tArt.part(oDC, "Back "..sState, 8, 8, 22, 22);
            tArt.part(oDC, "Next "..sState, 264, 8, 22, 22);
            tArt.text(oDC, string.format("%04d-%02d", nYear, nMonth), 105, 8, true);
            for nColumn, sDay in ipairs({"S", "M", "T", "W", "T", "F", "S"}) do tArt.text(oDC, sDay, 20 + (nColumn - 1) * 40, 36, true); end
            local nFirst = _Date.weekday(nYear, nMonth, 1);
            for nDay = 1, _Date.days(nYear, nMonth) do
                local nCell = nFirst + nDay - 1;
                local nX, nY = 7 + nCell % 7 * 40, 58 + math.floor(nCell / 7) * 32;
                local bSelected = tDate.Year == nYear and tDate.Month == nMonth and tDate.Day == nDay;
                local sCandidate = _Date.format({Year = nYear, Month = nMonth, Day = nDay,
                    Hour = tDate.Hour, Minute = tDate.Minute}, sMode);
                local bAvailable = (not sMin or sCandidate >= sMin) and (not sMax or sCandidate <= sMax);
                tArt.part(oDC, "Day "..(not bAvailable and "Disabled" or bSelected and "Hover" or "Normal"), nX, nY, 38, 30);
                tArt.text(oDC, tostring(nDay), nX + 10, nY + 5, bAvailable);
            end
        end
        if (sMode ~= "date") then
            tArt.text(oDC, string.format("Time: %02d:%02d", tDate.Hour, tDate.Minute), 84, nTimeTop, true);
            for nIndex, sText in ipairs({"Hour -", "Hour +", "Min -", "Min +"}) do
                tArt.part(oDC, "Day Normal", (nIndex - 1) * 73 + 2, nTimeTop + 28, 70, 32);
                tArt.text(oDC, sText, (nIndex - 1) * 73 + 9, nTimeTop + 34, true);
            end
        end
    end;
    oComponent.onLayout = function(nWidth, nHeight) oText:SetSize(9, math.max(4, (nHeight - 23) / 2), math.max(1, nWidth - 46), math.min(23, math.max(1, nHeight - 8))); end;
    oComponent.onEnable = function(bEnabled) oText:Enable(bEnabled); if (not bEnabled) then oComponent.close(); end end;
    oComponent.pointer = function(sEvent, nX)
        local nWidth = oComponent.Control:GetClientSizeWH();
        if (sEvent == "up" and oComponent.Pressed and oComponent.Hover and nX >= nWidth - 34) then
            if (bOpen) then oComponent.close(); else oComponent.open(); end
        elseif (sEvent == "down" and nX < nWidth - 34) then oComponent.cancel(); oText:SetFocus(); end
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        tArt.part(oDC, "Surface "..oComponent.getState(), 0, 0, nWidth, nHeight);
        tArt.part(oDC, "Icon "..oComponent.getState(), nWidth - 28, (nHeight - 20) / 2, 20, 20);
        if (oText:HasFocus()) then tArt.part(oDC, "Focus", 0, 0, nWidth, nHeight); end
    end;
    oText:Connect(_wx.wxEVT_COMMAND_TEXT_ENTER, function() if (oComponent.isEnabled() and not bReadOnly) then oComponent.commit(); end end);
    oText:Connect(_wx.wxEVT_KILL_FOCUS, function(jEvent) if (not oComponent.Disposed and not bReadOnly) then oComponent.commit(); end; jEvent:Skip(); end);
    oText:Connect(_wx.wxEVT_KEY_DOWN, function(jEvent)
        local nKey = jEvent:GetKeyCode();
        if (nKey == _wx.WXK_ESCAPE) then oText:ChangeValue(sValue); oComponent.close();
        elseif (nKey == _wx.WXK_F4 or nKey == _wx.WXK_DOWN) then oComponent.open(); else jEvent:Skip(); end
    end);
    oPopup:Connect(_wx.wxEVT_ACTIVATE, function(jEvent) if (not jEvent:GetActive()) then oComponent.close(); end; jEvent:Skip(); end);
    tContainment.watch(function(sReason) if (bOpen and sReason ~= "policy") then oComponent.close(); end end);
    oComponent.onDestroy = function()
        bOpen = false; oCalendar.destroy();
        if (not oPopup:IsBeingDeleted()) then oPopup:Destroy(); end
        tArt.destroy();
    end;
    oComponent.setEnabled(tOptions.Enabled ~= false);
    return oComponent;
end

return DateTimePicker;
