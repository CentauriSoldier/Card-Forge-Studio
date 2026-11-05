local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _Events = require("wxLuma.Core.ControlEvents");
local _Options = require("wxLuma.Core.ControlOptions");
local _Color = require("wxLuma.Core.ControlColor");
local _copy = require("wxLuma.State").copy;
local Chart = {};

--[[!
@fqxn wxLuma.UI.Chart.create
@desc Creates an independent skinned line, area, grouped/stacked bar, scatter,
    pie or donut chart. Series have stable Id, Text, Visible, optional Color and
    Marker image path, and Points {Id,X,Y,Text?,Color?}. X defaults to position.
    Pie/donut use points of the first visible series; negative slices are rejected.
    Data, layout and supersampled artwork are rebuilt only after invalidation.
    Shared events/audio plus data, selection, hover, legend and view events apply.
@param table tOptions Skin, Series, Artwork (Chart), OnChange and ChartOptions.
    Each documented setting exposes get/set<Property>(value, notify). Axis ranges
    accept false/nil for automatic or {Min,Max}. State contains plain data only.
!]]
function Chart.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "Chart requires Skin.");
    local oComponent = _Surface.create(oParent, tOptions, "Chart");
    local sArtwork = tOptions.Artwork or "Chart";
    local tArt = _Artwork.create(tOptions.Skin, sArtwork);
    local tEvents = _Events.attach(oComponent, nil, {"dataChanged", "seriesAdded", "seriesRemoved", "seriesVisibilityChanged",
        "pointAdded", "pointRemoved", "pointChanged", "selectionChanged", "pointHovered", "pointLeft", "pointClicked", "legendClicked", "viewChanged"});
    local tSeries, tById, tSettings, tSelected, tHovered, tDrag = {}, {}, nil, nil, nil, nil;
    local tHits, tLegends, tGeometry, tRender = {}, {}, nil, nil;
    local tPartSources, tPartBitmaps, tPartOrder = {}, {}, {};
    local tLayerShapes, nLayerSlot = {}, 0;
    local tFormatters = {};
    local nRevision = 0;
    local oTooltip, oTooltipTimer;
    local fEnsure;

    --[[!
    @fqxn wxLuma.UI.Chart.create.invalidate
    @desc Invalidates pixels and, unless explicitly retained, layout and coverage.
        Opacity changes reuse shape coverage; ordinary paints reuse final pixels.
    !]]
    local function fInvalidate(bKeepGeometry)
        nRevision = nRevision + 1;
        if (bKeepGeometry ~= true) then tGeometry = nil; tLayerShapes = {}; end
        oComponent.refresh();
        if (oTooltip) then oTooltip.hide(); end
        if (oTooltipTimer) then oTooltipTimer:Stop(); end
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.range
    @desc Normalizes an explicit finite axis range or automatic false/nil.
    !]]
    local function fRange(vRange)
        if (vRange == false or vRange == nil) then return false; end
        assert(type(vRange) == "table", "Range must be {Min,Max} or false.");
        local nMin = _Options.number(-1e100, 1e100)(vRange.Min);
        local nMax = _Options.number(-1e100, 1e100)(vRange.Max);
        assert(nMax > nMin, "Axis maximum must exceed minimum.");
        return {Min = nMin, Max = nMax};
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.validateMode
    @desc Validates data against the complete proposed mode/scale settings before
        mutating either data or options. Logarithmic axes require positive values.
    !]]
    local function fValidateMode(tNext, tData)
        local bPie = tNext.Type == "pie" or tNext.Type == "donut";
        for _, tItem in ipairs(tData or tSeries) do
            for _, tPoint in ipairs(tItem.Points) do
                assert(not bPie or tPoint.Y >= 0, "Pie/donut values cannot be negative.");
                if (not bPie) then
                    assert(tNext.XScale ~= "log" or tPoint.X > 0, "Log X requires positive data.");
                    assert(tNext.YScale ~= "log" or tPoint.Y > 0, "Log Y requires positive data.");
                end
            end
        end
        for _, sAxis in ipairs({"X", "Y"}) do
            local tRange = tNext[sAxis.."Range"];
            assert(tNext[sAxis.."Scale"] ~= "log" or not tRange or tRange.Min > 0, "Log ranges must be positive.");
        end
        if (not bPie and (tNext.Type == "bar" or tNext.Type == "area") and tNext.YScale == "log") then
            assert(tNext.Baseline >= 0, "Log fills require a nonnegative baseline (zero chooses the view minimum).");
        end
    end

    local tDefaults = {Type = "line", Title = "", Subtitle = "", XLabel = "", YLabel = "", Legend = true,
        LegendPosition = "bottom", LegendWidth = 130, LegendRowHeight = 24, LegendToggle = true,
        Grid = true, GridX = true, GridY = true, GridWidth = 1, GridStyle = "solid", AxisWidth = 1,
        LegendSwatchSize = 12, Axes = true, TickLabels = true, CategoryLabels = true, ValueLabels = false,
        PercentLabels = false, SliceLabels = false, ValueLabelOffset = {X = 5, Y = -18},
        Tooltips = true, TooltipDelay = 200, Markers = true, TintMarkers = true, TintBars = true, MarkerSize = 7, LineWidth = 2, LineStyle = "solid", Interpolation = "linear",
        AreaOpacity = 0.3, BarGap = 0.2, Stacked = false, Orientation = "vertical", Baseline = 0,
        HoleSize = 0.5, RadiusScale = 0.92, SliceGap = 0, StartAngle = -90, Clockwise = true,
        XRange = false, YRange = false, XScale = "linear", YScale = "linear", TickCount = 5, Precision = 3, AutoPrecision = true,
        Padding = {Left = 54, Right = 20, Top = 18, Bottom = 42},
        ZoomEnabled = true, PanEnabled = true, ZoomFactor = 1.2, HitRadius = 10,
        Supersampling = 2, MaxPoints = 10000, EmptyText = "No data"};
    local tValidators = {};
    for sName, vValue in pairs(tDefaults) do if (type(vValue) == "boolean") then tValidators[sName] = _Options.boolean; end end
    for _, sName in ipairs({"Title", "Subtitle", "XLabel", "YLabel", "EmptyText"}) do tValidators[sName] = _Options.text; end
    tValidators.Type = _Options.enum({"line", "area", "bar", "scatter", "pie", "donut"});
    tValidators.LegendPosition = _Options.enum({"top", "bottom", "left", "right"});
    tValidators.LineStyle = _Options.enum({"solid", "dash", "dot"});
    tValidators.GridStyle = _Options.enum({"solid", "dash", "dot"});
    tValidators.Interpolation = _Options.enum({"linear", "step"});
    tValidators.Orientation = _Options.enum({"horizontal", "vertical"});
    tValidators.XScale, tValidators.YScale = _Options.enum({"linear", "log"}), _Options.enum({"linear", "log"});
    tValidators.XRange, tValidators.YRange = fRange, fRange;
    for _, sName in ipairs({"LegendWidth", "LegendRowHeight"}) do tValidators[sName] = _Options.number(16, 512, true); end
    for _, sName in ipairs({"MarkerSize", "LineWidth", "HitRadius", "GridWidth", "AxisWidth", "LegendSwatchSize"}) do tValidators[sName] = _Options.number(1, 64); end
    tValidators.AreaOpacity = _Options.number(0, 1);
    tValidators.BarGap = _Options.number(0, 0.95);
    tValidators.HoleSize = _Options.number(0, 0.95);
    tValidators.RadiusScale = _Options.number(0.05, 1);
    tValidators.SliceGap = _Options.number(0, 45);
    tValidators.StartAngle = _Options.number(-1e9, 1e9);
    tValidators.Baseline = _Options.number(-1e100, 1e100);
    tValidators.TickCount = _Options.number(2, 20, true);
    tValidators.Precision = _Options.number(0, 10, true);
    tValidators.ZoomFactor = _Options.number(1.01, 10);
    tValidators.Supersampling = _Options.number(1, 4, true);
    tValidators.MaxPoints = _Options.number(1, 1000000, true);
    tValidators.TooltipDelay = _Options.number(0, 60000, true);
    tValidators.ValueLabelOffset = function(tValue)
        assert(type(tValue) == "table", "ValueLabelOffset must have X/Y.");
        return {X = _Options.number(-512, 512)(tValue.X), Y = _Options.number(-512, 512)(tValue.Y)};
    end;
    tValidators.Padding = function(tValue)
        assert(type(tValue) == "table", "Padding must have Left/Right/Top/Bottom.");
        local tResult = {};
        for _, sSide in ipairs({"Left", "Right", "Top", "Bottom"}) do tResult[sSide] = _Options.number(0, 512, true)(tValue[sSide]); end
        return tResult;
    end;
    tSettings = _Options.create(oComponent, tEvents, tDefaults, tValidators, tOptions, "ChartOptions", function(tChanges, bNotify)
        local bOpacityOnly = true;
        for _, tChange in ipairs(tChanges) do if (tChange.Property ~= "AreaOpacity") then bOpacityOnly = false; break; end end
        fInvalidate(bOpacityOnly);
        if (oTooltip) then oTooltip.setEnabled(tSettings.Tooltips and oComponent.isEnabled()); end
        for _, tChange in ipairs(tChanges) do
            if (tChange.Property == "MaxPoints" and oComponent.setSeries) then oComponent.setSeries(tSeries, bNotify); end
            if (bNotify and (tChange.Property == "XRange" or tChange.Property == "YRange")) then
                tEvents.emit("viewChanged", {XRange = _copy(tSettings.XRange), YRange = _copy(tSettings.YRange)}); break;
            end
        end
    end, fValidateMode);
    -- Nil is the documented convenience spelling for automatic ranges.
    for _, sName in ipairs({"XRange", "YRange"}) do
        local sAxisRange = sName;
        oComponent["set"..sAxisRange] = function(vValue, bNotify)
            return oComponent.setChartOptions({[sAxisRange] = vValue == nil and false or vValue}, bNotify);
        end;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.series
    @desc Validates dense series/point data, creates stable default IDs and
        prepares optional marker images before committing live data.
    !]]
    local function fSeries(tData, tConfig)
        tConfig = tConfig or tSettings;
        _Options.array(tData); local tResult, tIds = {}, {};
        for nSeries, tItem in ipairs(tData) do
            assert(type(tItem) == "table", "Series must be records.");
            local sId = tItem.Id; if (sId == nil) then sId = "series-"..nSeries; end
            assert(type(sId) == "string" and sId ~= "" and not tIds[sId], "Series IDs must be unique."); tIds[sId] = true;
            local tCopy = {Id = sId, Text = _Options.text(tItem.Text == nil and sId or tItem.Text), Points = {}, Visible = tItem.Visible ~= false};
            if (tItem.Visible ~= nil) then _Options.boolean(tItem.Visible); end
            if (tItem.Color ~= nil) then tCopy.Color = _Color.rgba(tItem.Color); end
            if (tItem.Marker ~= nil) then assert(type(tItem.Marker) == "string", "Marker must be an image path."); tArt.prepare(tItem.Marker); tCopy.Marker = tItem.Marker; end
            local tPoints = tItem.Points == nil and {} or tItem.Points;
            _Options.array(tPoints); local tPointIds = {};
            for nPoint, tPoint in ipairs(tPoints) do
                assert(type(tPoint) == "table", "Points must be records.");
                local sPointId = tPoint.Id; if (sPointId == nil) then sPointId = "point-"..nPoint; end
                assert(type(sPointId) == "string" and sPointId ~= "" and not tPointIds[sPointId], "Point IDs must be unique within a series."); tPointIds[sPointId] = true;
                local tNext = {Id = sPointId, X = _Options.number(-1e100, 1e100)(tPoint.X == nil and nPoint or tPoint.X), Y = _Options.number(-1e100, 1e100)(tPoint.Y)};
                if (tPoint.Text ~= nil) then tNext.Text = _Options.text(tPoint.Text); end
                if (tPoint.Color ~= nil) then tNext.Color = _Color.rgba(tPoint.Color); end
                tCopy.Points[#tCopy.Points + 1] = tNext;
            end
            if (#tCopy.Points > tConfig.MaxPoints) then
                local tKept = {}; for nIndex = #tCopy.Points - tConfig.MaxPoints + 1, #tCopy.Points do tKept[#tKept + 1] = tCopy.Points[nIndex]; end
                tCopy.Points = tKept;
            end
            tResult[#tResult + 1] = tCopy;
        end
        fValidateMode(tConfig, tResult); return tResult;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.getSeries
    @desc Returns all series or one stable series ID as independent plain data.
    !]]
    function oComponent.getSeries(sId) return _copy(sId and tById[sId] or not sId and tSeries or nil); end

    --[[!
    @fqxn wxLuma.UI.Chart.getPoint
    @desc Returns one independent point by series/point IDs, or nil if missing.
    !]]
    function oComponent.getPoint(sSeries, sPoint)
        local tItem = tById[sSeries]; if (tItem) then
            for _, tPoint in ipairs(tItem.Points) do if (tPoint.Id == sPoint) then return _copy(tPoint); end end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Chart.getValue
    @desc Returns selected {Series,Point} IDs or nil; selection never copies handles.
    !]]
    function oComponent.getValue() return _copy(tSelected); end

    --[[!
    @fqxn wxLuma.UI.Chart.setValue
    @desc Selects an existing point or clears with nil. Missing IDs are skipped
        for partial reloads. Optional notifications include both old/new selection.
    !]]
    function oComponent.setValue(tValue, bNotify)
        assert(not oComponent.Disposed, "Chart is disposed.");
        if (tValue ~= nil) then
            assert(type(tValue) == "table" and type(tValue.Series) == "string" and type(tValue.Point) == "string", "Invalid chart selection.");
            if (not oComponent.getPoint(tValue.Series, tValue.Point)) then return oComponent; end
            tValue = {Series = tValue.Series, Point = tValue.Point};
        end
        if (not _Options.same(tSelected, tValue)) then
            local tOld, tNext = tSelected, _copy(tValue); tSelected = _copy(tNext); fInvalidate();
            if (bNotify) then
                tEvents.emit("valueChanged", {Value = _copy(tNext), OldValue = _copy(tOld)});
                tEvents.emit("selectionChanged", {Value = _copy(tNext), OldValue = _copy(tOld)});
                if (oComponent.OnChange) then oComponent.OnChange(_copy(tNext), oComponent); end
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.setSeries
    @desc Replaces validated data atomically and reconciles stable point selection.
        Identical data does no work. Oldest points beyond MaxPoints are trimmed.
    !]]
    function oComponent.setSeries(tData, bNotify)
        assert(not oComponent.Disposed, "Chart is disposed."); local tNext = fSeries(tData);
        if (_Options.same(tNext, tSeries)) then return oComponent; end
        local tOld = tById; tSeries, tById = tNext, {};
        local tMarkers = {}; for _, tItem in ipairs(tSeries) do tById[tItem.Id] = tItem; tMarkers[#tMarkers + 1] = {Image = tItem.Marker}; end
        tArt.retain(tMarkers);
        if (tSelected and not oComponent.getPoint(tSelected.Series, tSelected.Point)) then oComponent.setValue(nil, bNotify); end
        fInvalidate();
        if (bNotify) then
            for sId in pairs(tOld) do if (not tById[sId]) then tEvents.emit("seriesRemoved", {Id = sId}); end end
            for sId in pairs(tById) do if (not tOld[sId]) then tEvents.emit("seriesAdded", {Id = sId}); end end
            tEvents.emit("dataChanged", {SeriesCount = #tSeries});
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.addSeries
    @desc Adds a unique series through the same atomic validation/data event path.
    !]]
    function oComponent.addSeries(tItem, bNotify)
        local tData = oComponent.getSeries(); tData[#tData + 1] = _copy(tItem); return oComponent.setSeries(tData, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Chart.removeSeries
    @desc Removes a series and its selection; unknown IDs are harmless.
    !]]
    function oComponent.removeSeries(sId, bNotify)
        local tData = {}; for _, tItem in ipairs(tSeries) do if (tItem.Id ~= sId) then tData[#tData + 1] = tItem; end end
        return oComponent.setSeries(tData, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Chart.setSeriesVisible
    @desc Shows/hides one series and optionally emits seriesVisibilityChanged.
    !]]
    function oComponent.setSeriesVisible(sId, bVisible, bNotify)
        _Options.boolean(bVisible); assert(tById[sId], "Unknown series.");
        if (tById[sId].Visible ~= bVisible) then
            local tData = oComponent.getSeries(); for _, tItem in ipairs(tData) do if (tItem.Id == sId) then tItem.Visible = bVisible; end end
            oComponent.setSeries(tData, bNotify);
            if (bNotify) then tEvents.emit("seriesVisibilityChanged", {Id = sId, Visible = bVisible}); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.addPoint
    @desc Appends to one series; a missing point ID gets a monotonically unused
        numeric suffix so trimming never reuses an existing point identity.
    !]]
    function oComponent.addPoint(sId, tPoint, bNotify)
        assert(type(tPoint) == "table", "Invalid point."); return oComponent.addPoints(sId, {tPoint}, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Chart.addPoints
    @desc Appends a batch with one validation/retention/layout pass. Missing IDs
        use unused numeric suffixes; omitted X advances from the previous point.
        pointAdded is emitted for retained new points after the full batch commits.
    !]]
    function oComponent.addPoints(sId, tPoints, bNotify)
        assert(tById[sId], "Unknown series."); _Options.array(tPoints);
        if (#tPoints == 0) then return oComponent; end
        local tData, tIds, tAdded, nId = oComponent.getSeries(), {}, {}, 0;
        for _, tOld in ipairs(tById[sId].Points) do
            tIds[tOld.Id] = true; nId = math.max(nId, tonumber(tOld.Id:match("^point%-(%d+)$")) or 0);
        end
        for _, tItem in ipairs(tData) do if (tItem.Id == sId) then
            for _, tPoint in ipairs(tPoints) do
                assert(type(tPoint) == "table", "Invalid point."); local tNext = _copy(tPoint);
                if (not tNext.Id) then repeat nId = nId + 1; tNext.Id = "point-"..nId; until not tIds[tNext.Id]; end
                assert(not tIds[tNext.Id], "Duplicate point ID."); tIds[tNext.Id] = true;
                if (tNext.X == nil) then tNext.X = #tItem.Points > 0 and tItem.Points[#tItem.Points].X + 1 or 1; end
                tItem.Points[#tItem.Points + 1] = tNext; tAdded[#tAdded + 1] = tNext.Id;
            end
        end end
        oComponent.setSeries(tData, bNotify);
        if (bNotify) then for _, sPoint in ipairs(tAdded) do
            local tPoint = oComponent.getPoint(sId, sPoint); if (tPoint) then tEvents.emit("pointAdded", {Series = sId, Point = tPoint}); end
        end end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.setPoint
    @desc Replaces one point without changing its identity. All data validate first.
    !]]
    function oComponent.setPoint(sId, sPoint, tPoint, bNotify)
        assert(oComponent.getPoint(sId, sPoint) and type(tPoint) == "table", "Unknown point.");
        assert(tPoint.Id == nil or tPoint.Id == sPoint, "Point IDs cannot change.");
        local tData, tNext = oComponent.getSeries(), _copy(tPoint); tNext.Id = sPoint;
        for _, tItem in ipairs(tData) do if (tItem.Id == sId) then
            for nIndex, tOld in ipairs(tItem.Points) do if (tOld.Id == sPoint) then tItem.Points[nIndex] = tNext; end end
        end end
        local tOld = oComponent.getPoint(sId, sPoint); oComponent.setSeries(tData, bNotify);
        if (bNotify and not _Options.same(tOld, oComponent.getPoint(sId, sPoint))) then
            tEvents.emit("pointChanged", {Series = sId, Point = oComponent.getPoint(sId, sPoint), OldPoint = tOld});
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.removePoint
    @desc Removes one stable point ID, retaining all other point identities.
    !]]
    function oComponent.removePoint(sId, sPoint, bNotify)
        if (not oComponent.getPoint(sId, sPoint)) then return oComponent; end
        local tData = oComponent.getSeries();
        for _, tItem in ipairs(tData) do if (tItem.Id == sId) then
            for nIndex = #tItem.Points, 1, -1 do if (tItem.Points[nIndex].Id == sPoint) then table.remove(tItem.Points, nIndex); end end
        end end
        oComponent.setSeries(tData, bNotify);
        if (bNotify) then tEvents.emit("pointRemoved", {Series = sId, Point = sPoint}); end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.clear
    @desc Clears point data for a series, or all series when no ID is supplied.
    !]]
    function oComponent.clear(sId, bNotify)
        if (sId == nil) then return oComponent.setSeries({}, bNotify); end
        assert(tById[sId], "Unknown series."); local tData = oComponent.getSeries();
        for _, tItem in ipairs(tData) do if (tItem.Id == sId) then tItem.Points = {}; end end
        return oComponent.setSeries(tData, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Chart.getChartState
    @desc Returns options, series, selection and local enabled state as one plain
        record. Formatter callbacks and native resources are never serialized.
    !]]
    function oComponent.getChartState()
        return {Options = oComponent.getChartOptions(), Series = oComponent.getSeries(),
            Value = oComponent.getValue(), Enabled = oComponent.Control:IsThisEnabled()};
    end

    --[[!
    @fqxn wxLuma.UI.Chart.setChartState
    @desc Validates options and data together before silent restoration. This
        permits switching between signed Cartesian data and nonnegative pie/log
        data without validating saved options against the wrong live dataset.
        Existing control/tooltip objects are reused; no constructors run.
    !]]
    function oComponent.setChartState(tState)
        assert(not oComponent.Disposed and type(tState) == "table" and type(tState.Options) == "table", "Invalid chart state.");
        local tConfig = oComponent.getChartOptions();
        for sName, vValue in pairs(tState.Options) do
            assert(tValidators[sName], "Unknown chart state option."); tConfig[sName] = tValidators[sName](_copy(vValue));
        end
        local tData = fSeries(tState.Series, tConfig);
        if (tState.Enabled ~= nil) then _Options.boolean(tState.Enabled); end
        if (tState.Value ~= nil) then
            assert(type(tState.Value) == "table" and type(tState.Value.Series) == "string" and type(tState.Value.Point) == "string", "Invalid saved point selection.");
        end
        oComponent.setSeries({}); oComponent.setChartOptions(tConfig); oComponent.setSeries(tData);
        oComponent.setValue(tState.Value);
        if (tState.Enabled ~= nil) then oComponent.setEnabled(tState.Enabled); end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.setFormatter
    @desc Installs an optional runtime callback for X, Y or Value labels/tooltips.
        Callback(number, point?, series?) returns text. Functions are never saved.
    !]]
    function oComponent.setFormatter(sAxis, fFormatter)
        assert(sAxis == "X" or sAxis == "Y" or sAxis == "Value", "Unknown formatter.");
        assert(fFormatter == nil or type(fFormatter) == "function", "Formatter must be callable.");
        assert(not oComponent.Disposed, "Chart is disposed."); tFormatters[sAxis] = fFormatter; fInvalidate(); return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.format
    @desc Formats all numeric labels consistently; custom callbacks must return text.
    !]]
    local function fFormat(sAxis, nValue, tPoint, tItem, nPrecision)
        if (tFormatters[sAxis]) then return _Options.text(tFormatters[sAxis](nValue, _copy(tPoint), _copy(tItem))); end
        nPrecision = nPrecision or tSettings.Precision;
        if (math.abs(nValue) >= 1e9 or nPrecision > 12) then return string.format("%.4g", nValue); end
        if (math.abs(nValue) < 0.5 * 10 ^ -nPrecision) then nValue = 0; end
        return string.format("%."..nPrecision.."f", nValue):gsub("(%..-)0+$", "%1"):gsub("%.$", "");
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.tickText
    @desc Adds axis precision when tick spacing is fractional, so integer value
        labels cannot make distinct fractional ticks display the same number.
        Wide log ranges use per-tick magnitude; extreme values use scientific text.
    !]]
    local function fTickText(sAxis, nValue)
        local nPrecision = tSettings.Precision;
        if (tSettings.AutoPrecision) then
            local tView = tGeometry.View;
            local nStep = (tView[sAxis.."Max"] - tView[sAxis.."Min"]) / (tSettings.TickCount - 1);
            if (nStep > 0) then nPrecision = math.max(nPrecision, 0, math.ceil(-math.log(nStep) / math.log(10)) + 1); end
            if (tSettings[sAxis.."Scale"] == "log" and nValue > 0) then
                nPrecision = math.max(nPrecision, 0, math.ceil(-math.log(nValue) / math.log(10)) + 2);
            end
        end
        return fFormat(sAxis, nValue, nil, nil, nPrecision);
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.bounds
    @desc Computes finite automatic ranges from visible data; stacked bars include
        both positive and negative cumulative extents, independently per X value.
    !]]
    local function fBounds()
        local nXMin, nXMax, nYMin, nYMax;
        local tSums = {};
        for _, tItem in ipairs(tSeries) do if (tItem.Visible) then
            for _, tPoint in ipairs(tItem.Points) do
                nXMin, nXMax = math.min(nXMin or tPoint.X, tPoint.X), math.max(nXMax or tPoint.X, tPoint.X);
                local nY = tPoint.Y;
                if (tSettings.Type == "bar" and tSettings.Stacked) then
                    local tSum = tSums[tPoint.X] or {Positive = tSettings.Baseline, Negative = tSettings.Baseline}; tSums[tPoint.X] = tSum;
                    local sSign = nY >= 0 and "Positive" or "Negative";
                    tSum[sSign] = tSum[sSign] + nY; nY = tSum[sSign];
                end
                nYMin, nYMax = math.min(nYMin or nY, nY), math.max(nYMax or nY, nY);
            end
        end end
        local bEmpty = nXMin == nil;
        nXMin, nXMax = nXMin or 0, nXMax or 1; nYMin, nYMax = nYMin or 0, nYMax or 1;
        if ((tSettings.Type == "bar" or tSettings.Type == "area") and tSettings.YScale ~= "log") then
            nYMin, nYMax = math.min(nYMin, tSettings.Baseline), math.max(nYMax, tSettings.Baseline);
        elseif ((tSettings.Type == "bar" or tSettings.Type == "area") and not bEmpty) then
            if (tSettings.Baseline > 0) then nYMin, nYMax = math.min(nYMin, tSettings.Baseline), math.max(nYMax, tSettings.Baseline);
            elseif (tSettings.Type == "bar") then nYMin = nYMin / 10; end
        end
        if (tSettings.Type == "bar") then
            if (tSettings.XScale == "log" and not bEmpty) then nXMin, nXMax = nXMin * 0.75, nXMax * 1.25;
            else nXMin, nXMax = nXMin - 0.5, nXMax + 0.5; end
        end
        if (tSettings.XScale == "log") then
            if (bEmpty) then nXMin, nXMax = 1, 10; else nXMin = math.max(1e-100, nXMin); end
        end
        if (tSettings.YScale == "log" and bEmpty) then nYMin, nYMax = 1, 10; end
        if (nXMin == nXMax) then
            if (tSettings.XScale == "log") then nXMin, nXMax = nXMin / 2, nXMax * 2;
            else local nPad = math.max(1, math.abs(nXMin) * 0.1); nXMin, nXMax = nXMin - nPad, nXMax + nPad; end
        end
        if (nYMin == nYMax) then
            if (tSettings.YScale == "log") then nYMin, nYMax = nYMin / 2, nYMax * 2;
            else local nPad = math.max(1, math.abs(nYMin) * 0.1); nYMin, nYMax = nYMin - nPad, nYMax + nPad; end
        end
        return {XMin = nXMin, XMax = nXMax, YMin = nYMin, YMax = nYMax, Empty = bEmpty};
    end

    --[[!
    @fqxn wxLuma.UI.Chart.getDataBounds
    @desc Returns automatic bounds before explicit view ranges, including Empty.
    !]]
    function oComponent.getDataBounds() return fBounds(); end

    --[[!
    @fqxn wxLuma.UI.Chart.create.transform
    @desc Maps logarithmic axes in transformed space; linear values pass through.
    !]]
    local function fTransform(sAxis, nValue)
        return tSettings[sAxis.."Scale"] == "log" and math.log(nValue) or nValue;
    end
    --[[!
    @fqxn wxLuma.UI.Chart.create.inverse
    @desc Converts transformed axis coordinates back to public data values.
    !]]
    local function fInverse(sAxis, nValue)
        return tSettings[sAxis.."Scale"] == "log" and math.exp(nValue) or nValue;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.geometry
    @desc Caches view bounds, plot rectangle, legends and hit targets independently
        of DC lifetime. Native handles are never returned from geometry getters.
    !]]
    fEnsure = function(nW, nH)
        if (not nW) then nW, nH = oComponent.Control:GetClientSizeWH(); end
        nW, nH = math.max(1, nW), math.max(1, nH);
        if (tGeometry and tGeometry.Width == nW and tGeometry.Height == nH) then return; end
        tLayerShapes = {};
        tHits, tLegends = {}, {};
        local tBounds = fBounds();
        local tX, tY = tSettings.XRange, tSettings.YRange;
        local tView = {XMin = tX and tX.Min or tBounds.XMin, XMax = tX and tX.Max or tBounds.XMax,
            YMin = tY and tY.Min or tBounds.YMin, YMax = tY and tY.Max or tBounds.YMax};
        local tPad = tSettings.Padding;
        local nLeft, nTop, nRight, nBottom = tPad.Left, tPad.Top, tPad.Right, tPad.Bottom;
        if (tSettings.Title ~= "") then nTop = nTop + 26; end
        if (tSettings.Subtitle ~= "") then nTop = nTop + 22; end
        local bPie = tSettings.Type == "pie" or tSettings.Type == "donut";
        local tLegendItems = {};
        if (bPie) then
            for nIndex, tItem in ipairs(tSeries) do if (tItem.Visible) then
                for nPoint, tPoint in ipairs(tItem.Points) do tLegendItems[#tLegendItems + 1] = {Series = tItem.Id, Point = tPoint.Id,
                    Text = tPoint.Text or tPoint.Id, Palette = nPoint, Color = tPoint.Color or tItem.Color, Visible = true}; end
                break;
            end end
        else
            for nIndex, tItem in ipairs(tSeries) do tLegendItems[#tLegendItems + 1] = {Series = tItem.Id, Text = tItem.Text,
                Palette = nIndex, Color = tItem.Color, Visible = tItem.Visible}; end
        end
        if (tSettings.Legend and #tLegendItems > 0) then
            local nRows = math.ceil(#tLegendItems / math.max(1, math.floor(nW / tSettings.LegendWidth)));
            if (tSettings.LegendPosition == "bottom") then nBottom = nBottom + nRows * tSettings.LegendRowHeight;
            elseif (tSettings.LegendPosition == "top") then nTop = nTop + nRows * tSettings.LegendRowHeight;
            elseif (tSettings.LegendPosition == "left") then nLeft = nLeft + tSettings.LegendWidth;
            else nRight = nRight + tSettings.LegendWidth; end
            for nIndex, tLegend in ipairs(tLegendItems) do
                local bSide = tSettings.LegendPosition == "left" or tSettings.LegendPosition == "right";
                local nColumns = math.max(1, math.floor(nW / tSettings.LegendWidth));
                tLegend.X = bSide and (tSettings.LegendPosition == "left" and 4 or nW - tSettings.LegendWidth)
                    or ((nIndex - 1) % nColumns) * tSettings.LegendWidth + 4;
                tLegend.Y = bSide and (nTop + (nIndex - 1) * tSettings.LegendRowHeight)
                    or (tSettings.LegendPosition == "top" and nTop - nRows * tSettings.LegendRowHeight
                    or nH - nRows * tSettings.LegendRowHeight) + math.floor((nIndex - 1) / nColumns) * tSettings.LegendRowHeight;
                tLegends[#tLegends + 1] = tLegend;
            end
        end
        local tPlot = {X = math.min(nLeft, nW - 1), Y = math.min(nTop, nH - 1),
            Width = math.max(1, nW - nLeft - nRight), Height = math.max(1, nH - nTop - nBottom)};
        tGeometry = {Width = nW, Height = nH, Plot = tPlot, View = tView, Empty = tBounds.Empty, Pie = bPie};
        local nTXMin, nTXMax = fTransform("X", tView.XMin), fTransform("X", tView.XMax);
        local nTYMin, nTYMax = fTransform("Y", tView.YMin), fTransform("Y", tView.YMax);
        tGeometry.Map = function(nX, nY)
            local nFX = (fTransform("X", nX) - nTXMin) / (nTXMax - nTXMin);
            local nFY = (fTransform("Y", nY) - nTYMin) / (nTYMax - nTYMin);
            -- Bound offscreen raster coordinates before passing them to native
            -- integer drawing APIs, including extreme but finite data/ranges.
            nFX, nFY = math.max(-1000, math.min(1000, nFX)), math.max(-1000, math.min(1000, nFY));
            if (tSettings.Type == "bar" and tSettings.Orientation == "horizontal") then
                return tPlot.X + nFY * tPlot.Width, tPlot.Y + tPlot.Height - nFX * tPlot.Height;
            end
            return tPlot.X + nFX * tPlot.Width, tPlot.Y + (1 - nFY) * tPlot.Height;
        end;
        if (bPie) then
            local tFirst; for _, tItem in ipairs(tSeries) do if (tItem.Visible) then tFirst = tItem; break; end end
            local nTotal = 0; if (tFirst) then for _, tPoint in ipairs(tFirst.Points) do nTotal = nTotal + tPoint.Y; end end
            tGeometry.Total = nTotal;
            local nRadius = math.min(tPlot.Width, tPlot.Height) / 2 * tSettings.RadiusScale;
            tGeometry.CX, tGeometry.CY, tGeometry.Radius = tPlot.X + tPlot.Width / 2, tPlot.Y + tPlot.Height / 2, nRadius;
            local nAngle = tSettings.StartAngle;
            if (tFirst and nTotal > 0) then for nIndex, tPoint in ipairs(tFirst.Points) do
                local nSweep = tPoint.Y / nTotal * 360;
                if (nSweep > 0) then
                    tHits[#tHits + 1] = {Series = tFirst.Id, Point = tPoint.Id, Palette = nIndex, Color = tPoint.Color or tFirst.Color,
                        Angle = nAngle, Sweep = nSweep, Text = tPoint.Text or tPoint.Id, Value = tPoint.Y};
                end
                nAngle = nAngle + (tSettings.Clockwise and 1 or -1) * nSweep;
            end end
        else
            local tVisible = {}; for _, tItem in ipairs(tSeries) do if (tItem.Visible) then tVisible[#tVisible + 1] = tItem; end end
            local tStacks = {};
            for nSeries, tItem in ipairs(tSeries) do if (tItem.Visible) then
                local nGroup = 1; for nIndex, tOther in ipairs(tVisible) do if (tOther.Id == tItem.Id) then nGroup = nIndex; end end
                for _, tPoint in ipairs(tItem.Points) do
                    local nPX, nPY = tGeometry.Map(tPoint.X, tPoint.Y);
                    local tHit = {Series = tItem.Id, Point = tPoint.Id, X = nPX, Y = nPY, Palette = nSeries,
                        Color = tPoint.Color or tItem.Color, Text = tPoint.Text or tPoint.Id, Value = tPoint.Y, Marker = tItem.Marker};
                    if (tSettings.Type == "bar") then
                        local nBase, nEnd = tSettings.Baseline, tPoint.Y;
                        if (tSettings.Stacked) then
                            local tStack = tStacks[tPoint.X] or {Positive = nBase, Negative = nBase}; tStacks[tPoint.X] = tStack;
                            local sSign = tPoint.Y >= 0 and "Positive" or "Negative";
                            nBase, nEnd = tStack[sSign], tStack[sSign] + tPoint.Y; tStack[sSign] = nEnd;
                        end
                        if (tSettings.YScale == "log") then nBase, nEnd = math.max(tView.YMin, nBase), math.max(tView.YMin, nEnd); end
                        local nGroupWidth = (1 - tSettings.BarGap) / (tSettings.Stacked and 1 or math.max(1, #tVisible));
                        local nA = tPoint.X - (1 - tSettings.BarGap) / 2 + (tSettings.Stacked and 0 or (nGroup - 1) * nGroupWidth);
                        -- Category coordinates remain linear even with a log X
                        -- axis: bar boundaries use positive fractions of X there.
                        if (tSettings.XScale == "log") then
                            nGroupWidth = tPoint.X * nGroupWidth / 2;
                            nA = math.max(tView.XMin, tPoint.X * (1 - (1 - tSettings.BarGap) / 4)
                                + (tSettings.Stacked and 0 or (nGroup - 1) * nGroupWidth));
                        end
                        local nX1, nY1 = tGeometry.Map(nA, nBase);
                        local nX2, nY2 = tGeometry.Map(nA + nGroupWidth, nEnd);
                        tHit.Rect = {X = math.min(nX1, nX2), Y = math.min(nY1, nY2), Width = math.max(1, math.abs(nX2 - nX1)), Height = math.max(1, math.abs(nY2 - nY1))};
                        tHit.X, tHit.Y = (nX1 + nX2) / 2, (nY1 + nY2) / 2;
                    end
                    tHits[#tHits + 1] = tHit;
                end
            end end
        end
    end;

    --[[!
    @fqxn wxLuma.UI.Chart.getViewRange
    @desc Returns effective view bounds, resolving automatic XRange/YRange.
    !]]
    function oComponent.getViewRange() fEnsure(); return _copy(tGeometry.View); end

    --[[!
    @fqxn wxLuma.UI.Chart.getPlotRect
    @desc Returns the current plot rectangle in client pixels as plain data.
    !]]
    function oComponent.getPlotRect() fEnsure(); return _copy(tGeometry.Plot); end

    --[[!
    @fqxn wxLuma.UI.Chart.getPointPosition
    @desc Returns a point/bar center in client pixels or nil for hidden/missing
        targets. Pie/donut return the angular/radial center of the visible slice.
    !]]
    local function fPointPosition(sSeries, sPoint)
        for _, tHit in ipairs(tHits) do if (tHit.Series == sSeries and tHit.Point == sPoint) then
            if (tGeometry.Pie) then
                local nAngle = math.rad(tHit.Angle + (tSettings.Clockwise and 1 or -1) * tHit.Sweep / 2);
                local nRadius = tGeometry.Radius * (tSettings.Type == "donut" and (1 + tSettings.HoleSize) / 2 or 0.6);
                return tGeometry.CX + math.cos(nAngle) * nRadius, tGeometry.CY + math.sin(nAngle) * nRadius;
            end
            return tHit.X, tHit.Y;
        end end
    end
    function oComponent.getPointPosition(sSeries, sPoint) fEnsure(); return fPointPosition(sSeries, sPoint); end

    --[[!
    @fqxn wxLuma.UI.Chart.hitTest
    @desc Returns a copied {Series,Point} target, excluding clipped points, donut
        holes and slice gaps. Nearest marker wins within HitRadius pixels.
    !]]
    function oComponent.hitTest(nX, nY)
        fEnsure(); local tPlot = tGeometry.Plot;
        if (nX < tPlot.X or nX > tPlot.X + tPlot.Width or nY < tPlot.Y or nY > tPlot.Y + tPlot.Height) then return nil; end
        if (tGeometry.Pie) then
            local nDX, nDY = nX - tGeometry.CX, nY - tGeometry.CY; local nRadius = math.sqrt(nDX * nDX + nDY * nDY);
            if (nRadius > tGeometry.Radius or tSettings.Type == "donut" and nRadius < tGeometry.Radius * tSettings.HoleSize) then return nil; end
            local nAngle = math.deg(math.atan(nDY, nDX));
            for _, tHit in ipairs(tHits) do
                local nOffset = (tSettings.Clockwise and nAngle - tHit.Angle or tHit.Angle - nAngle) % 360;
                local nGap = math.min(tSettings.SliceGap, tHit.Sweep * 0.8) / 2;
                if (nOffset >= nGap and nOffset <= tHit.Sweep - nGap) then return {Series = tHit.Series, Point = tHit.Point}; end
            end
        else
            local tBest, nBest = nil, tSettings.HitRadius * tSettings.HitRadius;
            for _, tHit in ipairs(tHits) do
                local tRect = tHit.Rect;
                if (tRect and nX >= tRect.X and nX <= tRect.X + tRect.Width and nY >= tRect.Y and nY <= tRect.Y + tRect.Height) then return {Series = tHit.Series, Point = tHit.Point}; end
                if (not tRect and tHit.X >= tPlot.X and tHit.X <= tPlot.X + tPlot.Width and tHit.Y >= tPlot.Y and tHit.Y <= tPlot.Y + tPlot.Height) then
                    local nDistance = (nX - tHit.X) ^ 2 + (nY - tHit.Y) ^ 2;
                    if (nDistance <= nBest) then nBest, tBest = nDistance, tHit; end
                end
            end
            if (tBest) then return {Series = tBest.Series, Point = tBest.Point}; end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Chart.setViewRange
    @desc Atomically sets explicit Cartesian bounds; resetView restores auto axes.
    !]]
    function oComponent.setViewRange(nXMin, nXMax, nYMin, nYMax, bNotify)
        return oComponent.setChartOptions({XRange = {Min = nXMin, Max = nXMax}, YRange = {Min = nYMin, Max = nYMax}}, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Chart.resetView
    @desc Restores automatic ranges from currently visible data.
    !]]
    function oComponent.resetView(bNotify) return oComponent.setChartOptions({XRange = false, YRange = false}, bNotify); end

    --[[!
    @fqxn wxLuma.UI.Chart.zoom
    @desc Scales Cartesian view spans by a positive factor about optional data
        coordinates. Factors below one zoom in. Pie/donut ignore zoom/pan.
    !]]
    function oComponent.zoom(nFactor, nCenterX, nCenterY, bNotify)
        _Options.number(0.001, 1000)(nFactor); fEnsure(); if (tGeometry.Pie) then return oComponent; end
        local tView = tGeometry.View;
        local tNext = {};
        for _, sAxis in ipairs({"X", "Y"}) do
            local nMin, nMax = fTransform(sAxis, tView[sAxis.."Min"]), fTransform(sAxis, tView[sAxis.."Max"]);
            local nCenter; if (sAxis == "X") then nCenter = nCenterX; else nCenter = nCenterY; end
            nCenter = nCenter and fTransform(sAxis, _Options.number(-1e100, 1e100)(nCenter)) or (nMin + nMax) / 2;
            tNext[sAxis.."Range"] = {Min = fInverse(sAxis, nCenter + (nMin - nCenter) * nFactor),
                Max = fInverse(sAxis, nCenter + (nMax - nCenter) * nFactor)};
        end
        return oComponent.setChartOptions(tNext, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Chart.pan
    @desc Translates linear axes by data units; logarithmic axes use log-space
        deltas. Programmatic actions remain available when gestures are disabled.
    !]]
    function oComponent.pan(nDX, nDY, bNotify)
        _Options.number(-1e100, 1e100)(nDX); _Options.number(-1e100, 1e100)(nDY); fEnsure();
        if (tGeometry.Pie) then return oComponent; end
        local tView = tGeometry.View;
        return oComponent.setViewRange(fInverse("X", fTransform("X", tView.XMin) + nDX),
            fInverse("X", fTransform("X", tView.XMax) + nDX), fInverse("Y", fTransform("Y", tView.YMin) + nDY),
            fInverse("Y", fTransform("Y", tView.YMax) + nDY), bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.color
    @desc Resolves skinned series colors or explicit validated RGBA overrides.
        The caller owns only newly created override colors.
    !]]
    local function fColor(tHit, sState)
        if (tHit.Color) then
            local nFactor = sState == "Disabled" and 0.45 or (sState == "Hover" or sState == "Selected") and 1.15 or 1;
            return _wx.wxColour(math.min(255, math.floor(tHit.Color.R * nFactor)), math.min(255, math.floor(tHit.Color.G * nFactor)),
                math.min(255, math.floor(tHit.Color.B * nFactor)), tHit.Color.A), true;
        end
        return tArt.color("Series "..((tHit.Palette - 1) % 8 + 1).." "..sState), false;
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.composite
    @desc Blends a bitmap over a bounded copy of its destination. The native
        alpha fallback otherwise reads the entire chart for every small marker.
        Opaque blits copy the result back through the destination's plot clip.
    !]]
    local function fComposite(oDC, oBitmap, nX, nY)
        nX, nY = math.floor(nX), math.floor(nY);
        local nTargetW, nTargetH = oDC:GetSize();
        local nLeft, nTop = math.max(0, nX), math.max(0, nY);
        local nW = math.min(nTargetW, nX + oBitmap:GetWidth()) - nLeft;
        local nH = math.min(nTargetH, nY + oBitmap:GetHeight()) - nTop;
        if (nW <= 0 or nH <= 0) then return; end
        local oPatch = _wx.wxBitmap(nW, nH);
        local oPatchDC = _wx.wxMemoryDC(); oPatchDC:SelectObject(oPatch);
        oPatchDC:Blit(0, 0, nW, nH, oDC, nLeft, nTop, _wx.wxCOPY);
        oPatchDC:DrawBitmap(oBitmap, nX - nLeft, nY - nTop, true);
        oDC:Blit(nLeft, nTop, nW, nH, oPatchDC, 0, 0, _wx.wxCOPY);
        oPatchDC:SelectObject(_wx.wxNullBitmap); oPatchDC:delete(); oPatch:delete();
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.part
    @desc Applies series colors to neutral Marker/Bar/Swatch image layers while
        retaining authored shape, shading and alpha. A bounded 64-entry bitmap
        cache prevents live data/resize churn from retaining unlimited resources.
    !]]
    local function fPart(oDC, sPart, sState, tHit, nX, nY, nW, nH, bTint)
        nW, nH = math.max(1, math.floor(nW)), math.max(1, math.floor(nH));
        local sName = sArtwork.." "..sPart.." "..sState;
        if (not bTint) then oComponent.Skin.draw(oDC, sName, nX, nY, nW, nH); return; end
        local oColor, bOwn = fColor(tHit, sState);
        local nRed, nGreen, nBlue, nAlpha = oColor:Red(), oColor:Green(), oColor:Blue(), oColor:Alpha();
        local sKey = sName..":"..nW..":"..nH..":"..nRed..":"..nGreen..":"..nBlue..":"..nAlpha;
        if (not tPartBitmaps[sKey]) then
            if (not tPartSources[sName]) then tPartSources[sName] = oComponent.Skin.getBitmap(sName):ConvertToImage(); end
            local oSource = tPartSources[sName];
            local oImage = oSource:Scale(nW, nH, _wx.wxIMAGE_QUALITY_HIGH);
            if (oSource:GetWidth() == 1 and oSource:GetHeight() == 1) then
                -- A single texel remains constant after scaling. Repeat its tinted
                -- value directly instead of visiting every bar pixel in Lua.
                local nShade = oSource:GetRed(0, 0);
                local nSourceAlpha = oSource:HasAlpha() and oSource:GetAlpha(0, 0) or 255;
                oImage:SetData(string.rep(string.char(math.floor(nRed * nShade / 255), math.floor(nGreen * nShade / 255),
                    math.floor(nBlue * nShade / 255)), nW * nH));
                if (not oImage:HasAlpha()) then oImage:InitAlpha(); end
                oImage:SetAlpha(string.rep(string.char(math.floor(nSourceAlpha * nAlpha / 255)), nW * nH));
            else
                local sShades = oImage:GetData():gsub("(.)..", "%1"); local tRGB, tAlpha = {}, {};
                for nByte = 0, 255 do
                    local sByte = string.char(nByte);
                    tRGB[sByte] = string.char(math.floor(nRed * nByte / 255), math.floor(nGreen * nByte / 255), math.floor(nBlue * nByte / 255));
                    tAlpha[sByte] = string.char(math.floor(nByte * nAlpha / 255));
                end
                local sRGB = sShades:gsub(".", tRGB);
                local sAlpha = (oImage:HasAlpha() and oImage:GetAlpha() or string.rep(string.char(255), nW * nH)):gsub(".", tAlpha);
                oImage:SetData(sRGB); if (not oImage:HasAlpha()) then oImage:InitAlpha(); end; oImage:SetAlpha(sAlpha);
            end
            tPartBitmaps[sKey] = _wx.wxBitmap(oImage); oImage:delete(); tPartOrder[#tPartOrder + 1] = sKey;
            if (#tPartOrder > 64) then local sOld = table.remove(tPartOrder, 1); tPartBitmaps[sOld]:delete(); tPartBitmaps[sOld] = nil; end
        end
        fComposite(oDC, tPartBitmaps[sKey], nX, nY);
        if (bOwn) then oColor:delete(); end
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.polygon
    @desc Draws native polygon geometry and explicitly releases temporary points.
    !]]
    local function fPolygon(oDC, tCoordinates, nScale)
        if (#tCoordinates < 3) then return; end
        local tPoints = {}; for _, tXY in ipairs(tCoordinates) do tPoints[#tPoints + 1] = _wx.wxPoint(math.floor(tXY[1] * nScale), math.floor(tXY[2] * nScale)); end
        oDC:DrawPolygon(tPoints); for _, oPoint in ipairs(tPoints) do oPoint:delete(); end
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.layer
    @desc Converts binary native polygon/stroke coverage to alpha in native code.
        Crops to the plot and retains up to eight coverage strings for opacity
        changes. Replaces opaque runs in bulk, retaining true compositing over
        skinned backgrounds and the final supersampled edge filtering.
    !]]
    local function fLayer(oDC, oColor, nW, nH, nOpacity, fDraw)
        nLayerSlot = nLayerSlot + 1;
        if (nOpacity <= 0 or oColor:Alpha() == 0) then return; end
        -- Coverage outside the plot cannot contribute through the plot clip.
        -- Crop before allocating or blending, including extreme offscreen data.
        local nScale, tPlot = tSettings.Supersampling, tGeometry.Plot;
        local nLeft, nTop = math.max(0, math.floor(tPlot.X * nScale)), math.max(0, math.floor(tPlot.Y * nScale));
        nW = math.min(nW - nLeft, math.max(1, math.floor(tPlot.Width * nScale)));
        nH = math.min(nH - nTop, math.max(1, math.floor(tPlot.Height * nScale)));
        if (nW <= 0 or nH <= 0) then return; end
        local tShape = tLayerShapes[nLayerSlot];
        if (not tShape) then
            local oMask = _wx.wxBitmap(nW, nH); local oMaskDC = _wx.wxMemoryDC(); oMaskDC:SelectObject(oMask);
            local oBlack = _wx.wxBrush(_wx.wxColour(0, 0, 0)); local oWhite = _wx.wxBrush(_wx.wxColour(255, 255, 255));
            oMaskDC:SetBackground(oBlack); oMaskDC:Clear(); oMaskDC:SetPen(_wx.wxTRANSPARENT_PEN); oMaskDC:SetBrush(oWhite);
            oMaskDC:SetDeviceOrigin(-nLeft, -nTop);
            fDraw(oMaskDC); oMaskDC:SelectObject(_wx.wxNullBitmap); oMaskDC:delete();
            local oImage = oMask:ConvertToImage(); oMask:delete(); oBlack:delete(); oWhite:delete();
            -- Native integer-coordinate coverage contains only black and white.
            -- InitAlpha converts the black mask color to zero without a per-pixel
            -- Lua pattern pass; the white spans receive one uniform opacity.
            oImage:SetMaskColour(0, 0, 0); oImage:InitAlpha();
            tShape = {Alpha = oImage:GetAlpha()}; oImage:delete();
            -- Retain only a bounded number of plain coverage strings, never an
            -- unbounded bitmap for every series, opacity value or historical size.
            if (nLayerSlot <= 8) then tLayerShapes[nLayerSlot] = tShape; end
        end
        local sOpacity = string.char(math.floor(nOpacity * oColor:Alpha()));
        local sAlpha = tShape.Alpha:gsub("\255+", function(sRun) return string.rep(sOpacity, #sRun); end);
        local oImage = _wx.wxImage(nW, nH);
        oImage:SetData(string.rep(string.char(oColor:Red(), oColor:Green(), oColor:Blue()), nW * nH));
        oImage:InitAlpha(); oImage:SetAlpha(sAlpha);
        local oFill = _wx.wxBitmap(oImage); oImage:delete(); fComposite(oDC, oFill, nLeft, nTop); oFill:delete();
    end

    --[[!
    @fqxn wxLuma.UI.Chart.create.render
    @desc Renders cached geometry at configurable supersampling. All decorative
        colors, plot surfaces, markers, focus and legend swatches come from skins.
        Numeric text stays at native resolution in the final draw pass.
    !]]
    local function fRender(nW, nH, sState)
        nLayerSlot = 0;
        local nScale = tSettings.Supersampling; local nSW, nSH = nW * nScale, nH * nScale;
        local oBitmap = _wx.wxBitmap(nSW, nSH); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
        tArt.part(oDC, "Surface "..sState, 0, 0, nSW, nSH);
        local tPlot = tGeometry.Plot;
        tArt.part(oDC, "Plot "..sState, tPlot.X * nScale, tPlot.Y * nScale, tPlot.Width * nScale, tPlot.Height * nScale);
        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(math.floor(tPlot.X * nScale), math.floor(tPlot.Y * nScale),
            math.max(1, math.floor(tPlot.Width * nScale)), math.max(1, math.floor(tPlot.Height * nScale))));
        local oGridPen = _wx.wxPen(tArt.color("Grid "..sState), math.max(1, math.floor(tSettings.GridWidth * nScale)),
            tSettings.GridStyle == "dash" and _wx.wxPENSTYLE_SHORT_DASH or tSettings.GridStyle == "dot" and _wx.wxPENSTYLE_DOT or _wx.wxPENSTYLE_SOLID);
        local oAxisPen = _wx.wxPen(tArt.color("Axis "..sState), math.max(1, math.floor(tSettings.AxisWidth * nScale)), _wx.wxPENSTYLE_SOLID);
        if (not tGeometry.Pie and tSettings.Grid) then
            oDC:SetPen(oGridPen);
            for nTick = 0, tSettings.TickCount - 1 do
                local nFraction = nTick / (tSettings.TickCount - 1);
                if (tSettings.GridX) then local nX = (tPlot.X + tPlot.Width * nFraction) * nScale; oDC:DrawLine(nX, tPlot.Y * nScale, nX, (tPlot.Y + tPlot.Height) * nScale); end
                if (tSettings.GridY) then local nY = (tPlot.Y + tPlot.Height * nFraction) * nScale; oDC:DrawLine(tPlot.X * nScale, nY, (tPlot.X + tPlot.Width) * nScale, nY); end
            end
        end
        if (tGeometry.Pie) then
            for _, tHit in ipairs(tHits) do
                local sPartState = not oComponent.isEnabled() and "Disabled" or _Options.same(tSelected, {Series = tHit.Series, Point = tHit.Point}) and "Selected"
                    or _Options.same(tHovered, {Series = tHit.Series, Point = tHit.Point}) and "Hover" or "Normal";
                local oColor, bOwn = fColor(tHit, sPartState); local oBrush = _wx.wxBrush(oColor);
                oDC:SetBrush(oBrush); oDC:SetPen(_wx.wxTRANSPARENT_PEN);
                local nGap = math.min(tSettings.SliceGap, tHit.Sweep * 0.8) / 2;
                local nSign = tSettings.Clockwise and 1 or -1; local tPoints = {};
                local nInner = tSettings.Type == "donut" and tGeometry.Radius * tSettings.HoleSize or 0;
                local nSteps = math.max(2, math.ceil(tHit.Sweep / 3));
                if (nInner == 0) then tPoints[#tPoints + 1] = {tGeometry.CX, tGeometry.CY}; end
                for nStep = 0, nSteps do
                    local nAngle = math.rad(tHit.Angle + nSign * (nGap + (tHit.Sweep - 2 * nGap) * nStep / nSteps));
                    tPoints[#tPoints + 1] = {tGeometry.CX + math.cos(nAngle) * tGeometry.Radius, tGeometry.CY + math.sin(nAngle) * tGeometry.Radius};
                end
                if (nInner > 0) then for nStep = nSteps, 0, -1 do
                    local nAngle = math.rad(tHit.Angle + nSign * (nGap + (tHit.Sweep - 2 * nGap) * nStep / nSteps));
                    tPoints[#tPoints + 1] = {tGeometry.CX + math.cos(nAngle) * nInner, tGeometry.CY + math.sin(nAngle) * nInner};
                end end
                if (oColor:Alpha() < 255) then
                    fLayer(oDC, oColor, nSW, nSH, 1, function(oMaskDC) fPolygon(oMaskDC, tPoints, nScale); end);
                else fPolygon(oDC, tPoints, nScale); end
                oBrush:delete(); if (bOwn) then oColor:delete(); end
            end
        else
            local tGroups = {};
            for _, tHit in ipairs(tHits) do
                tGroups[tHit.Series] = tGroups[tHit.Series] or {}; tGroups[tHit.Series][#tGroups[tHit.Series] + 1] = tHit;
            end
            for _, tItem in ipairs(tSeries) do if (tItem.Visible and tGroups[tItem.Id]) then
                local tGroup = tGroups[tItem.Id]; local oColor, bOwn = fColor({Palette = tGroup[1].Palette, Color = tItem.Color}, oComponent.isEnabled() and "Normal" or "Disabled");
                local oPen = _wx.wxPen(oColor, math.max(1, math.floor(tSettings.LineWidth * nScale)),
                    tSettings.LineStyle == "dash" and _wx.wxPENSTYLE_SHORT_DASH or tSettings.LineStyle == "dot" and _wx.wxPENSTYLE_DOT or _wx.wxPENSTYLE_SOLID);
                oDC:SetPen(oPen);
                if (tSettings.Type == "area") then
                    local nBase = tSettings.YScale == "log" and tSettings.Baseline == 0 and tGeometry.View.YMin or tSettings.Baseline;
                    local nFirstX, nBaseY = tGeometry.Map(tItem.Points[1].X, nBase);
                    local tPolygon = {{nFirstX, nBaseY}};
                    for nIndex, tHit in ipairs(tGroup) do
                        if (nIndex > 1 and tSettings.Interpolation == "step") then tPolygon[#tPolygon + 1] = {tHit.X, tGroup[nIndex - 1].Y}; end
                        tPolygon[#tPolygon + 1] = {tHit.X, tHit.Y};
                    end
                    tPolygon[#tPolygon + 1] = {tGroup[#tGroup].X, nBaseY};
                    fLayer(oDC, oColor, nSW, nSH, tSettings.AreaOpacity, function(oMaskDC) fPolygon(oMaskDC, tPolygon, nScale); end); oDC:SetPen(oPen);
                end
                if (oColor:Alpha() < 255 and tSettings.Type ~= "bar" and tSettings.Type ~= "scatter") then
                    fLayer(oDC, oColor, nSW, nSH, 1, function(oMaskDC)
                        local oWhitePen = _wx.wxPen(_wx.wxColour(255, 255, 255), math.max(1, math.floor(tSettings.LineWidth * nScale)),
                            tSettings.LineStyle == "dash" and _wx.wxPENSTYLE_SHORT_DASH or tSettings.LineStyle == "dot" and _wx.wxPENSTYLE_DOT or _wx.wxPENSTYLE_SOLID);
                        oMaskDC:SetPen(oWhitePen);
                        for nIndex = 2, #tGroup do
                            local tA, tB = tGroup[nIndex - 1], tGroup[nIndex];
                            if (tSettings.Interpolation == "step") then
                                oMaskDC:DrawLine(tA.X * nScale, tA.Y * nScale, tB.X * nScale, tA.Y * nScale);
                                oMaskDC:DrawLine(tB.X * nScale, tA.Y * nScale, tB.X * nScale, tB.Y * nScale);
                            else oMaskDC:DrawLine(tA.X * nScale, tA.Y * nScale, tB.X * nScale, tB.Y * nScale); end
                        end
                        oWhitePen:delete();
                    end);
                end
                for nIndex, tHit in ipairs(tGroup) do
                    if (tHit.Rect) then
                        local sPartState = not oComponent.isEnabled() and "Disabled" or _Options.same(tSelected, {Series = tHit.Series, Point = tHit.Point}) and "Selected"
                            or _Options.same(tHovered, {Series = tHit.Series, Point = tHit.Point}) and "Hover" or "Normal";
                        local nLeft, nTop = math.max(tPlot.X, tHit.Rect.X), math.max(tPlot.Y, tHit.Rect.Y);
                        local nRight, nBottom = math.min(tPlot.X + tPlot.Width, tHit.Rect.X + tHit.Rect.Width), math.min(tPlot.Y + tPlot.Height, tHit.Rect.Y + tHit.Rect.Height);
                        if (nRight > nLeft and nBottom > nTop) then
                            fPart(oDC, "Bar", sPartState, tHit, nLeft * nScale, nTop * nScale,
                                (nRight - nLeft) * nScale, (nBottom - nTop) * nScale, tSettings.TintBars);
                        end
                    elseif (tSettings.Type ~= "scatter" and nIndex > 1 and oColor:Alpha() == 255) then
                        local tPrevious = tGroup[nIndex - 1]; oDC:SetPen(oPen);
                        if (tSettings.Interpolation == "step") then
                            oDC:DrawLine(tPrevious.X * nScale, tPrevious.Y * nScale, tHit.X * nScale, tPrevious.Y * nScale);
                            oDC:DrawLine(tHit.X * nScale, tPrevious.Y * nScale, tHit.X * nScale, tHit.Y * nScale);
                        else oDC:DrawLine(tPrevious.X * nScale, tPrevious.Y * nScale, tHit.X * nScale, tHit.Y * nScale); end
                    end
                    if (not tHit.Rect and tSettings.Markers) then
                        local nSize = tSettings.MarkerSize * nScale;
                        local sMarkerState = not oComponent.isEnabled() and "Disabled" or _Options.same(tSelected, {Series = tHit.Series, Point = tHit.Point}) and "Selected"
                            or _Options.same(tHovered, {Series = tHit.Series, Point = tHit.Point}) and "Hover" or "Normal";
                        if (tHit.Marker) then tArt.image(oDC, tHit.Marker, tHit.X * nScale - nSize / 2, tHit.Y * nScale - nSize / 2, nSize);
                        else fPart(oDC, "Marker", sMarkerState, tHit, tHit.X * nScale - nSize / 2, tHit.Y * nScale - nSize / 2, nSize, nSize, tSettings.TintMarkers); end
                    end
                end
                oPen:delete(); if (bOwn) then oColor:delete(); end
            end end
        end
        if (not tGeometry.Pie and tSettings.Axes) then
            oDC:SetPen(oAxisPen); oDC:SetBrush(_wx.wxTRANSPARENT_BRUSH);
            oDC:DrawRectangle(tPlot.X * nScale, tPlot.Y * nScale, tPlot.Width * nScale, tPlot.Height * nScale);
        end
        oClip:delete(); oGridPen:delete(); oAxisPen:delete();
        oDC:SelectObject(_wx.wxNullBitmap); oDC:delete();
        local oImage = oBitmap:ConvertToImage(); oBitmap:delete(); local oScaled = oImage:Scale(nW, nH, _wx.wxIMAGE_QUALITY_HIGH); oImage:delete();
        if (tRender) then tRender.Bitmap:delete(); end
        tRender = {Width = nW, Height = nH, State = sState, Revision = nRevision, Bitmap = _wx.wxBitmap(oScaled)}; oScaled:delete();
    end

    oComponent.draw = function(oDC, nW, nH)
        if (oComponent.Disposed or nW < 1 or nH < 1) then return; end
        fEnsure(nW, nH); local sState = oComponent.getState();
        if (not tRender or tRender.Width ~= nW or tRender.Height ~= nH or tRender.State ~= sState or tRender.Revision ~= nRevision) then fRender(nW, nH, sState); end
        oDC:DrawBitmap(tRender.Bitmap, 0, 0, false);
        local tPlot = tGeometry.Plot;
        local nTextY = tSettings.Padding.Top;
        if (tSettings.Title ~= "") then tArt.text(oDC, tSettings.Title, tPlot.X, nTextY, oComponent.isEnabled()); nTextY = nTextY + 26; end
        if (tSettings.Subtitle ~= "") then tArt.text(oDC, tSettings.Subtitle, tPlot.X, nTextY, oComponent.isEnabled()); end
        if (not tGeometry.Pie and tSettings.TickLabels) then
            for nTick = 0, tSettings.TickCount - 1 do
                local nFraction = nTick / (tSettings.TickCount - 1);
                local tView = tGeometry.View;
                local bHorizontal = tSettings.Type == "bar" and tSettings.Orientation == "horizontal";
                local sBottomAxis, sLeftAxis = bHorizontal and "Y" or "X", bHorizontal and "X" or "Y";
                local nBottom = fInverse(sBottomAxis, fTransform(sBottomAxis, tView[sBottomAxis.."Min"]) + nFraction
                    * (fTransform(sBottomAxis, tView[sBottomAxis.."Max"]) - fTransform(sBottomAxis, tView[sBottomAxis.."Min"])));
                local nLeft = fInverse(sLeftAxis, fTransform(sLeftAxis, tView[sLeftAxis.."Min"]) + nFraction
                    * (fTransform(sLeftAxis, tView[sLeftAxis.."Max"]) - fTransform(sLeftAxis, tView[sLeftAxis.."Min"])));
                if (not (tSettings.Type == "bar" and tSettings.CategoryLabels and not bHorizontal)) then
                    tArt.text(oDC, fTickText(sBottomAxis, nBottom), tPlot.X + nFraction * tPlot.Width - 10, tPlot.Y + tPlot.Height + 3, oComponent.isEnabled());
                end
                if (not (tSettings.Type == "bar" and tSettings.CategoryLabels and bHorizontal)) then
                    tArt.text(oDC, fTickText(sLeftAxis, nLeft), math.max(0, tPlot.X - 48), tPlot.Y + (1 - nFraction) * tPlot.Height - 8, oComponent.isEnabled());
                end
            end
            if (tSettings.Type == "bar" and tSettings.CategoryLabels) then
                local tSeen = {};
                for _, tItem in ipairs(tSeries) do if (tItem.Visible) then for _, tPoint in ipairs(tItem.Points) do
                    if (not tSeen[tPoint.X]) then
                        tSeen[tPoint.X] = true;
                        local sLabel = tFormatters.X and fFormat("X", tPoint.X, tPoint, tItem) or tPoint.Text or fFormat("X", tPoint.X);
                        local nX, nY = tGeometry.Map(tPoint.X, tGeometry.View.YMin);
                        if (tSettings.Orientation == "horizontal") then tArt.text(oDC, sLabel, math.max(0, tPlot.X - 48), nY - 8, oComponent.isEnabled());
                        else local nTextW = oDC:GetTextExtent(sLabel); tArt.text(oDC, sLabel, nX - nTextW / 2, tPlot.Y + tPlot.Height + 3, oComponent.isEnabled()); end
                    end
                end end end
            end
        end
        if (tSettings.XLabel ~= "") then tArt.text(oDC, tSettings.XLabel, tPlot.X + tPlot.Width / 2 - 20, tPlot.Y + tPlot.Height + 22, oComponent.isEnabled()); end
        if (tSettings.YLabel ~= "") then tArt.text(oDC, tSettings.YLabel, 2, math.max(0, tPlot.Y - 18), oComponent.isEnabled()); end
        if (tGeometry.Empty or tGeometry.Pie and tGeometry.Total == 0) then tArt.text(oDC, tSettings.EmptyText, tPlot.X + 8, tPlot.Y + 8, oComponent.isEnabled()); end
        if (tSettings.ValueLabels or tGeometry.Pie and tSettings.SliceLabels) then
            local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(tPlot.X, tPlot.Y, tPlot.Width, tPlot.Height));
            for _, tHit in ipairs(tHits) do
                local nX, nY = fPointPosition(tHit.Series, tHit.Point);
                if (nX) then
                    local sLabel = tGeometry.Pie and tSettings.SliceLabels and tHit.Text or "";
                    if (tSettings.ValueLabels) then
                        local bPercent = tGeometry.Pie and tSettings.PercentLabels;
                        local nValue = bPercent and (tGeometry.Total > 0 and tHit.Value / tGeometry.Total * 100 or 0) or tHit.Value;
                        sLabel = sLabel..(sLabel ~= "" and " " or "")..fFormat("Value", nValue, oComponent.getPoint(tHit.Series, tHit.Point), tById[tHit.Series])..(bPercent and "%" or "");
                    end
                    tArt.text(oDC, sLabel, nX + tSettings.ValueLabelOffset.X, nY + tSettings.ValueLabelOffset.Y, oComponent.isEnabled());
                end
            end
            oClip:delete();
        end
        for _, tLegend in ipairs(tLegends) do
            fPart(oDC, "Swatch", oComponent.isEnabled() and tLegend.Visible and "Normal" or "Disabled", tLegend,
                tLegend.X, tLegend.Y + 4, tSettings.LegendSwatchSize, tSettings.LegendSwatchSize, true);
            local nTextX = tLegend.X + tSettings.LegendSwatchSize + 6;
            local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(nTextX, tLegend.Y, math.max(1, tSettings.LegendWidth - tSettings.LegendSwatchSize - 10), tSettings.LegendRowHeight));
            tArt.text(oDC, tLegend.Text, nTextX, tLegend.Y + 1, oComponent.isEnabled() and tLegend.Visible); oClip:delete();
        end
        if (oComponent.Control:HasFocus()) then tArt.part(oDC, "Focus", 0, 0, nW, nH); end
    end;

    oTooltip = require("wxLuma.Widgets.Tooltip").create(oComponent.Control, {Skin = tOptions.Skin, Text = "", Automatic = false, Enabled = tSettings.Tooltips});
    oTooltipTimer = _wx.wxTimer(oComponent.Control);
    local nTooltipId = oTooltipTimer:GetId();
    oComponent.Control:Connect(nTooltipId, _wx.wxEVT_TIMER, function()
        if (not oComponent.Disposed and oComponent.isEnabled() and tSettings.Tooltips and tHovered and not oComponent.Pressed) then oTooltip.show(); end
    end);
    oComponent.Tooltip = oTooltip;
    oComponent.pointer = function(sEvent, nX, nY)
        fEnsure();
        local tHit = sEvent ~= "leave" and oComponent.hitTest(nX, nY) or nil;
        if (not _Options.same(tHit, tHovered)) then
            if (tHovered) then tEvents.emit("pointLeft", _copy(tHovered)); end
            tHovered = _copy(tHit); nRevision = nRevision + 1; oComponent.refresh(); oTooltip.hide(); oTooltipTimer:Stop();
            if (tHovered) then
                local tPoint = oComponent.getPoint(tHovered.Series, tHovered.Point);
                tEvents.emit("pointHovered", {Series = tHovered.Series, Point = tHovered.Point, Data = tPoint});
                if (tSettings.Tooltips) then
                    oTooltip.setText(tById[tHovered.Series].Text..": "..(tPoint.Text or tPoint.Id).." = "..fFormat("Value", tPoint.Y, tPoint, tById[tHovered.Series]));
                    if (tSettings.TooltipDelay == 0) then oTooltip.show(); else oTooltipTimer:Start(tSettings.TooltipDelay, true); end
                end
            end
        end
        if (sEvent == "down" and oComponent.Pressed) then
            oTooltipTimer:Stop(); oTooltip.hide();
            for _, tLegend in ipairs(tLegends) do
                if (nX >= tLegend.X and nX < tLegend.X + tSettings.LegendWidth and nY >= tLegend.Y and nY < tLegend.Y + tSettings.LegendRowHeight) then
                    tDrag = {Legend = _copy(tLegend)}; return;
                end
            end
            tDrag = {X = nX, Y = nY, View = _copy(tGeometry.View), Target = tHit, Panning = false};
        elseif (sEvent == "move" and oComponent.Pressed and tDrag and not tDrag.Legend and tSettings.PanEnabled and not tGeometry.Pie) then
            if (math.abs(nX - tDrag.X) + math.abs(nY - tDrag.Y) > 4) then tDrag.Panning = true; end
            if (tDrag.Panning) then
                local tPlot, tView = tGeometry.Plot, tDrag.View;
                local bHorizontal = tSettings.Type == "bar" and tSettings.Orientation == "horizontal";
                local nFX = bHorizontal and (nY - tDrag.Y) / tPlot.Height or -(nX - tDrag.X) / tPlot.Width;
                local nFY = bHorizontal and -(nX - tDrag.X) / tPlot.Width or (nY - tDrag.Y) / tPlot.Height;
                local nDX = nFX * (fTransform("X", tView.XMax) - fTransform("X", tView.XMin));
                local nDY = nFY * (fTransform("Y", tView.YMax) - fTransform("Y", tView.YMin));
                oComponent.setViewRange(fInverse("X", fTransform("X", tView.XMin) + nDX), fInverse("X", fTransform("X", tView.XMax) + nDX),
                    fInverse("Y", fTransform("Y", tView.YMin) + nDY), fInverse("Y", fTransform("Y", tView.YMax) + nDY), true);
            end
        elseif (sEvent == "up" and tDrag) then
            local tStart = tDrag;
            if (tStart.Legend) then
                local tLegend = tStart.Legend;
                if (nX >= tLegend.X and nX < tLegend.X + tSettings.LegendWidth and nY >= tLegend.Y and nY < tLegend.Y + tSettings.LegendRowHeight) then
                    tEvents.emit("legendClicked", _copy(tLegend));
                    if (tLegend.Point) then oComponent.setValue({Series = tLegend.Series, Point = tLegend.Point}, true);
                    elseif (tSettings.LegendToggle) then oComponent.setSeriesVisible(tLegend.Series, not tById[tLegend.Series].Visible, true); end
                end
            elseif (not tStart.Panning and _Options.same(tStart.Target, tHit)) then
                oComponent.setValue(tHit, true);
                if (tHit) then tEvents.emit("pointClicked", {Series = tHit.Series, Point = tHit.Point, Data = oComponent.getPoint(tHit.Series, tHit.Point)}); end
            end
        end
    end;
    oComponent.onCancel = function() tDrag = nil; end;
    oComponent.onLayout = fInvalidate;
    oComponent.wheel = function(nSteps)
        if (tSettings.ZoomEnabled) then oComponent.zoom(math.max(0.001, math.min(1000, tSettings.ZoomFactor ^ -nSteps)), nil, nil, true); end
    end;
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_ESCAPE) then oComponent.setValue(nil, true);
        elseif (nKey == _wx.WXK_HOME) then oComponent.resetView(true);
        elseif (nKey == _wx.WXK_ADD or nKey == string.byte("+")) then if (tSettings.ZoomEnabled) then oComponent.zoom(1 / tSettings.ZoomFactor, nil, nil, true); end
        elseif (nKey == _wx.WXK_SUBTRACT or nKey == string.byte("-")) then if (tSettings.ZoomEnabled) then oComponent.zoom(tSettings.ZoomFactor, nil, nil, true); end
        elseif (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_RIGHT) then
            local tPoints = {}; for _, tItem in ipairs(tSeries) do if (tItem.Visible) then for _, tPoint in ipairs(tItem.Points) do tPoints[#tPoints + 1] = {Series = tItem.Id, Point = tPoint.Id}; end end end
            local nCurrent = 0; for nIndex, tPoint in ipairs(tPoints) do if (_Options.same(tPoint, tSelected)) then nCurrent = nIndex; end end
            if (#tPoints > 0) then oComponent.setValue(tPoints[math.max(1, math.min(#tPoints, nCurrent + (nKey == _wx.WXK_LEFT and -1 or 1)))], true); end
        else return false; end
        return true;
    end;
    oComponent.onEnable = function(bEnabled) oTooltip.setEnabled(bEnabled and tSettings.Tooltips); fInvalidate(); end;
    oComponent.onDestroy = function()
        if (tRender) then tRender.Bitmap:delete(); tRender = nil; end
        for _, oImage in pairs(tPartSources) do oImage:delete(); end
        for _, oBitmap in pairs(tPartBitmaps) do oBitmap:delete(); end
        tPartSources, tPartBitmaps, tPartOrder = {}, {}, {};
        tLayerShapes = {};
        oTooltipTimer:Stop(); oComponent.Control:Disconnect(nTooltipId, _wx.wxEVT_TIMER); oTooltipTimer:delete();
        oTooltip.destroy(); tArt.destroy(); tSeries, tById, tHits, tLegends, tFormatters = {}, {}, {}, {}, {};
    end;
    oComponent.setSeries(tOptions.Series or {});
    return oComponent;
end

-- Capture/restore the coupled chart settings/data as one validated operation.
-- The adapter still participates in the shared iterative ownership traversal.
require("wxLuma.State").register("wxLuma.UI.Chart", {
    capture = function(oChart) return oChart.getChartState(); end,
    restore = function(oChart, tState) oChart.setChartState(tState); end,
    validate = function(tState)
        assert(type(tState) == "table" and type(tState.Options) == "table" and type(tState.Series) == "table", "Invalid chart snapshot.");
    end
});

--[[!
@fqxn wxLuma.UI.Chart.typedFactories
@desc Named line/area/bar/scatter/pie/donut factories share the engine and API;
    runtime setType can switch among them without reconstructing native controls.
!]]
for _, sType in ipairs({"line", "area", "bar", "scatter", "pie", "donut"}) do
    local sKind = sType;
    Chart[sKind] = function(oParent, tOptions)
        local tCopy = {}; for sName, vValue in pairs(tOptions or {}) do tCopy[sName] = vValue; end
        tCopy.Type = sKind; return Chart.create(oParent, tCopy);
    end;
end

return Chart;
