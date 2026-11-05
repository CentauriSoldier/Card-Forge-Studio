--[[!
@fqxn wxLuma.UI.ControlDateTime
@desc Timezone-independent Gregorian/24-hour validation for the date/time editor.
    Fixed-width ISO strings compare in chronological order within the same mode.
!]]
local ControlDateTime = {};

--[[!
@fqxn wxLuma.UI.ControlDateTime.days
@desc Returns days in a valid Gregorian month, including century leap-year rules.
!]]
function ControlDateTime.days(nYear, nMonth)
    if (nMonth == 2) then
        return (nYear % 4 == 0 and (nYear % 100 ~= 0 or nYear % 400 == 0)) and 29 or 28;
    end
    return ({31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31})[nMonth];
end

--[[!
@fqxn wxLuma.UI.ControlDateTime.parse
@desc Returns validated components for date, time or datetime; invalid text returns nil without normalizing impossible dates.
!]]
function ControlDateTime.parse(sValue, sMode)
    if (type(sValue) ~= "string") then return nil; end
    local sYear, sMonth, sDay, sHour, sMinute;
    if (sMode == "date") then sYear, sMonth, sDay = sValue:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$");
    elseif (sMode == "time") then sHour, sMinute = sValue:match("^(%d%d):(%d%d)$");
    elseif (sMode == "datetime") then sYear, sMonth, sDay, sHour, sMinute = sValue:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$");
    else return nil; end
    if ((sMode ~= "time" and not sYear) or (sMode ~= "date" and not sHour)) then return nil; end
    local tValue = {Year = tonumber(sYear) or 2000, Month = tonumber(sMonth) or 1, Day = tonumber(sDay) or 1,
        Hour = tonumber(sHour) or 0, Minute = tonumber(sMinute) or 0};
    if (tValue.Year < 1 or tValue.Year > 9999 or tValue.Month < 1 or tValue.Month > 12
        or tValue.Day < 1 or tValue.Day > ControlDateTime.days(tValue.Year, tValue.Month)
        or tValue.Hour > 23 or tValue.Minute > 59) then return nil; end
    return tValue;
end

--[[!
@fqxn wxLuma.UI.ControlDateTime.format
@desc Produces fixed-width ISO text for already valid date/time components.
!]]
function ControlDateTime.format(tValue, sMode)
    local sDate = string.format("%04d-%02d-%02d", tValue.Year, tValue.Month, tValue.Day);
    local sTime = string.format("%02d:%02d", tValue.Hour, tValue.Minute);
    return sMode == "date" and sDate or sMode == "time" and sTime or sDate.." "..sTime;
end

--[[!
@fqxn wxLuma.UI.ControlDateTime.weekday
@desc Returns Sunday=0 through Saturday=6 for a Gregorian date without local timezone conversions.
!]]
function ControlDateTime.weekday(nYear, nMonth, nDay)
    local nYearAdjusted = nYear - (nMonth < 3 and 1 or 0);
    local tOffset = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
    return (nYearAdjusted + math.floor(nYearAdjusted / 4) - math.floor(nYearAdjusted / 100)
        + math.floor(nYearAdjusted / 400) + tOffset[nMonth] + nDay) % 7;
end

return ControlDateTime;
