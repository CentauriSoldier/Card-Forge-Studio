local _wx       = require("wx");
local _Surface  = require("wxLuma.Core.ControlSurface");
local _Artwork  = require("wxLuma.Core.ControlArtwork");
local _Events   = require("wxLuma.Core.ControlEvents");
local _Scroll   = require("wxLuma.Containers.ScrollContainer");
local _Editor   = require("wxLuma.Core.ControlEditor");
local _Numeric  = require("wxLuma.Widgets.NumericField");
local _Checkbox = require("wxLuma.Widgets.Checkbox");
local _Dropdown = require("wxLuma.Widgets.Dropdown");
local _ColorPicker = require("wxLuma.Widgets.ColorPicker");
local _FilePicker  = require("wxLuma.Widgets.FilePicker");
local _Color    = require("wxLuma.Core.ControlColor");
local _finite   = require("wxLuma.Core.ControlNumeric").finite;
local PropertyGrid = {};
local _tTypes = {text = true, number = true, boolean = true, choice = true,
    color = true, file = true, folder = true, category = true};

--[[!
@fqxn wxLuma.UI.PropertyGrid.create
@desc Creates a scrollable inspector using real typed wxLuma editors. Stable
    property IDs identify value changes. Read-only entries remain visible and
    categories separate related rows. Values and descriptors are copied; callers
    own application data and the shared skin, while the grid owns its editors.
@param wxWindow oParent Native owner.
@param table tOptions Skin, Properties ({Id,Text,Type,Value,ReadOnly,Items,
    Min,Max,Step,Precision}); optional RowHeight (42), LabelWidth (160),
    Artwork (Property Grid), Enabled, OnChange(id, value, component).
@ret table oComponent getValue(id/nil), setValue(id,value,notify), getProperties,
    getEditor, setReadOnly, Scroll, propertyChanged and standard input events.
!]]
function PropertyGrid.create(oParent, tOptions)
    assert(type(tOptions.Properties) == "table", "PropertyGrid requires Properties.");
    local nRow = tOptions.RowHeight or 42;
    local nLabel = tOptions.LabelWidth or 160;
    local nSplit = nLabel;
    assert(_finite(nRow) and nRow % 1 == 0 and nRow >= 32, "Invalid property RowHeight.");
    assert(_finite(nLabel) and nLabel % 1 == 0 and nLabel >= 40, "Invalid LabelWidth.");
    local tSpecs, tById, tValues, tEditors = {}, {}, {}, {};

    --[[!
    @fqxn wxLuma.UI.PropertyGrid.fValue
    @desc Validates a property's typed value before any live editor mutation.
        RGBA colors are normalized and copied to prevent aliasing caller data.
    !]]
    local function fValue(tSpec, vValue)
        if (tSpec.Type == "color") then return _Color.rgba(vValue); end
        if (tSpec.Type == "number") then
            assert(_finite(vValue) and vValue >= tSpec.Min and vValue <= tSpec.Max, "Property number is out of range.");
        elseif (tSpec.Type == "boolean") then assert(type(vValue) == "boolean", "Property must be boolean.");
        else
            assert(type(vValue) == "string", "Property must be a string.");
            if (tSpec.Type == "choice") then
                local bFound = false;
                for _, sItem in ipairs(tSpec.Items) do bFound = bFound or sItem == vValue; end
                assert(bFound, "Property choice is not an available item.");
            end
        end
        return vValue;
    end
    local nCount = 0;
    for nKey in pairs(tOptions.Properties) do
        nCount = nCount + 1;
        assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tOptions.Properties,
            "Properties must be a dense array.");
    end
    assert(nCount == #tOptions.Properties, "Properties must be a dense array.");
    for nIndex, tSource in ipairs(tOptions.Properties) do
        assert(type(tSource) == "table" and type(tSource.Id) == "string" and tSource.Id ~= ""
            and not tById[tSource.Id], "Invalid/duplicate property Id.");
        local tSpec = {Id = tSource.Id, Text = tSource.Text or tSource.Id, Type = tSource.Type or "text",
            ReadOnly = tSource.ReadOnly == true};
        assert(_tTypes[tSpec.Type] and type(tSpec.Text) == "string", "Invalid property Type/Text.");
        assert(tSource.ReadOnly == nil or type(tSource.ReadOnly) == "boolean", "Invalid ReadOnly.");
        if (tSpec.Type == "number") then
            tSpec.Min, tSpec.Max = tSource.Min or 0, tSource.Max or 100;
            tSpec.Step, tSpec.Precision = tSource.Step or 1, tSource.Precision or 2;
            assert(_finite(tSpec.Min) and _finite(tSpec.Max) and tSpec.Min < tSpec.Max, "Invalid property range.");
            assert(_finite(tSpec.Step) and tSpec.Step > 0 and _finite(tSpec.Precision)
                and tSpec.Precision % 1 == 0 and tSpec.Precision >= 0 and tSpec.Precision <= 10,
                "Invalid property numeric policy.");
            local nScale = 10 ^ tSpec.Precision;
            assert(tSpec.Step >= 1 / nScale and math.max(math.abs(tSpec.Min), math.abs(tSpec.Max)) * nScale < 2 ^ 52
                and math.ceil(tSpec.Min * nScale) <= math.floor(tSpec.Max * nScale), "Unrepresentable property range.");
        elseif (tSpec.Type == "choice") then
            assert(type(tSource.Items) == "table" and #tSource.Items > 0, "Choice requires Items.");
            local nItems = 0;
            for nKey in pairs(tSource.Items) do
                nItems = nItems + 1;
                assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tSource.Items,
                    "Choice Items must be a dense array.");
            end
            assert(nItems == #tSource.Items, "Choice Items must be a dense array.");
            tSpec.Items = {};
            for nItem, sItem in ipairs(tSource.Items) do
                assert(type(sItem) == "string", "Choice Items must be strings."); tSpec.Items[nItem] = sItem;
            end
        end
        tSpecs[nIndex], tById[tSpec.Id] = tSpec, tSpec;
        if (tSpec.Type ~= "category") then
            local vDefault = "";
            if (tSpec.Type == "number") then vDefault = tSpec.Min;
            elseif (tSpec.Type == "boolean") then vDefault = false;
            elseif (tSpec.Type == "choice") then vDefault = tSpec.Items[1];
            elseif (tSpec.Type == "color") then vDefault = {R = 255, G = 255, B = 255}; end
            local vValue = tSource.Value;
            if (vValue == nil) then vValue = vDefault; end
            tValues[tSpec.Id] = fValue(tSpec, vValue);
        end
    end
    local oComponent = _Surface.create(oParent, tOptions, "PropertyGrid");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Property Grid");
    local tEvents = _Events.attach(oComponent, nil, {"propertyChanged", "readOnlyChanged"});
    local oScroll = _Scroll.create(oComponent.Control, {Skin = tOptions.Skin});
    oComponent.Scroll = oScroll;
    oScroll.Content:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
    oScroll.Content:SetBackgroundColour(tArt.color("Surface Normal"));

    --[[!
    @fqxn wxLuma.UI.PropertyGrid.fCopyValue
    @desc Copies mutable color values while preserving scalar value identity.
    !]]
    local function fCopyValue(vValue)
        return type(vValue) == "table" and _Color.rgba(vValue) or vValue;
    end

    --[[!
    @fqxn wxLuma.UI.PropertyGrid.getValue
    @desc Returns an independent value for an ID, or an ID/value map if omitted.
    @param string|nil sId Property ID; categories do not have values.
    @ret any vValue Typed value or all property values.
    !]]
    function oComponent.getValue(sId)
        if (sId ~= nil) then
            assert(tById[sId] and tById[sId].Type ~= "category", "Unknown value property.");
            return fCopyValue(tValues[sId]);
        end
        local tCopy = {};
        for sKey, vValue in pairs(tValues) do tCopy[sKey] = fCopyValue(vValue); end
        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.PropertyGrid.getEditor
    @desc Returns the owned typed editor for bindings and focus management.
    @param string sId Property ID.
    @ret table oEditor Component; lifetime remains owned by the grid.
    !]]
    function oComponent.getEditor(sId) return assert(tEditors[sId], "Unknown property editor."); end

    --[[!
    @fqxn wxLuma.UI.PropertyGrid.setValue
    @desc Validates and writes one property silently by default. Numeric editors
        retain their precision policy; notifications carry normalized values.
    @param string sId Property ID.
    @param any vValue Typed value.
    @param boolean|nil bNotify Emit propertyChanged and OnChange on change.
    @ret table oComponent This object.
    !]]
    function oComponent.setValue(sId, vValue, bNotify)
        assert(not oComponent.Disposed and tById[sId] and tById[sId].Type ~= "category", "Unknown value property.");
        local tSpec = tById[sId];
        local vNext = fValue(tSpec, vValue);
        local oEditor = tEditors[sId];
        if (tSpec.Type == "choice") then
            for nIndex, sItem in ipairs(tSpec.Items) do if (sItem == vNext) then oEditor.setValue(nIndex); break; end end
        else
            oEditor.setValue(vNext);
            vNext = oEditor.getValue();
        end
        local vOld = tValues[sId];
        local bChanged = vNext ~= vOld;
        if (tSpec.Type == "color") then
            bChanged = vNext.R ~= vOld.R or vNext.G ~= vOld.G or vNext.B ~= vOld.B or vNext.A ~= vOld.A;
        end
        tValues[sId] = fCopyValue(vNext);
        if (bChanged and bNotify) then
            tEvents.emit("propertyChanged", {Id = sId, Value = fCopyValue(vNext), OldValue = fCopyValue(vOld)});
            if (tOptions.OnChange) then tOptions.OnChange(sId, fCopyValue(vNext), oComponent); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.PropertyGrid.getProperties
    @desc Returns ordered descriptor copies including current values and policy.
    @ret table tProperties Independent property descriptors.
    !]]
    function oComponent.getProperties()
        local tCopy = {};
        for nIndex, tSpec in ipairs(tSpecs) do
            local tEntry = {};
            for sKey, vValue in pairs(tSpec) do
                if (sKey == "Items") then
                    local tItems = {}; for nItem, sItem in ipairs(vValue) do tItems[nItem] = sItem; end
                    tEntry.Items = tItems;
                else tEntry[sKey] = vValue; end
            end
            tEntry.Value = fCopyValue(tValues[tSpec.Id]); tCopy[nIndex] = tEntry;
        end
        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.PropertyGrid.setReadOnly
    @desc Changes a value editor's availability without altering its value.
    @param string sId Property ID.
    @param boolean bReadOnly Read-only state.
    @ret table oComponent This object.
    !]]
    function oComponent.setReadOnly(sId, bReadOnly)
        assert(type(bReadOnly) == "boolean" and tEditors[sId] and not oComponent.Disposed, "Invalid read-only property.");
        local tSpec = tById[sId];
        if (tSpec.ReadOnly ~= bReadOnly) then
            tSpec.ReadOnly = bReadOnly;
            tEditors[sId].setEnabled(oComponent.isEnabled() and not bReadOnly);
            oScroll.Content:Refresh(false);
            tEvents.emit("readOnlyChanged", {Id = sId, ReadOnly = bReadOnly});
        end
        return oComponent;
    end
    for _, tSpec in ipairs(tSpecs) do
        if (tSpec.Type ~= "category") then
            local sId = tSpec.Id;
            local tEditorOptions = {Skin = tOptions.Skin, Value = tValues[sId], Enabled = not tSpec.ReadOnly,
                OnChange = function(vValue)
                    if (tSpec.Type == "choice") then vValue = tSpec.Items[vValue]; end
                    oComponent.setValue(sId, vValue, true);
                end};
            local oEditor;
            if (tSpec.Type == "number") then
                tEditorOptions.Min, tEditorOptions.Max = tSpec.Min, tSpec.Max;
                tEditorOptions.Step, tEditorOptions.Precision = tSpec.Step, tSpec.Precision;
                oEditor = _Numeric.create(oScroll.Content, tEditorOptions);
            elseif (tSpec.Type == "boolean") then
                tEditorOptions.Selected, tEditorOptions.Text = tValues[sId], "";
                oEditor = _Checkbox.create(oScroll.Content, tEditorOptions);
            elseif (tSpec.Type == "choice") then
                tEditorOptions.Items, tEditorOptions.Value = tSpec.Items, 1;
                for nIndex, sItem in ipairs(tSpec.Items) do if (sItem == tValues[sId]) then tEditorOptions.Value = nIndex; end end
                oEditor = _Dropdown.create(oScroll.Content, tEditorOptions);
                local oChoice = oEditor;
                oChoice.draw = function(oDC, nWidth, nHeight)
                    if (oChoice.Disposed) then return; end
                    tArt.part(oDC, "Editor "..oChoice.getState(), 0, 0, nWidth, nHeight);
                    oDC:SetClippingRegion(8, 4, math.max(1, nWidth - 38), math.max(1, nHeight - 8));
                    tArt.text(oDC, oChoice.getText(), 9, (nHeight - 18) / 2, oChoice.isEnabled());
                    oDC:DestroyClippingRegion();
                    tArt.part(oDC, "Arrow "..oChoice.getState(), nWidth - 26, (nHeight - 16) / 2, 16, 16);
                end;
            elseif (tSpec.Type == "color") then oEditor = _ColorPicker.create(oScroll.Content, tEditorOptions);
            elseif (tSpec.Type == "file" or tSpec.Type == "folder") then
                tEditorOptions.Mode = tSpec.Type; oEditor = _FilePicker.create(oScroll.Content, tEditorOptions);
            else
                tEditorOptions.Artwork = tOptions.Artwork and tOptions.Artwork.." Editor" or "Property Grid Editor";
                oEditor = _Editor.create(oScroll.Content, tEditorOptions, "PropertyEditor");
            end
            tEditors[sId] = oEditor;
            if (tSpec.Type == "number") then tValues[sId] = oEditor.getValue(); end
            if (oEditor.TextControl) then
                oEditor.TextControl:SetBackgroundColour(tArt.color("Editor Fill"));
                oEditor.TextControl:SetForegroundColour(tArt.color("Text Normal"));
            end
            for _, sEvent in ipairs({"pointerEnter", "pointerLeave", "leftDown", "leftUp", "rightDown", "rightUp", "leftClick", "rightClick"}) do
                oEditor.on(sEvent, function(oSource, tEvent)
                    tEvents.emit(sEvent, {Id = sId, Child = oSource, NativeEvent = tEvent.NativeEvent});
                end);
            end
        end
    end
    -- Labels and category rows are drawn together; editors remain native children.
    oScroll.Content:Connect(_wx.wxEVT_PAINT, function()
        local oDC = _wx.wxAutoBufferedPaintDC(oScroll.Content);
        if (not oComponent.Disposed) then
            local nWidth, nHeight = oScroll.Content:GetClientSizeWH();
            tArt.part(oDC, "Surface "..(oComponent.isEnabled() and "Normal" or "Disabled"), 0, 0, nWidth, nHeight);
            for nIndex, tSpec in ipairs(tSpecs) do
                local nY = (nIndex - 1) * nRow;
                tArt.part(oDC, tSpec.Type == "category" and "Category" or "Row", 0, nY, nWidth, nRow);
                oDC:SetClippingRegion(4, nY, math.max(1, tSpec.Type == "category" and nWidth - 8 or nSplit - 12), nRow);
                tArt.text(oDC, tSpec.Text, 10, nY + (nRow - 18) / 2, oComponent.isEnabled() and not tSpec.ReadOnly);
                oDC:DestroyClippingRegion();
                tArt.part(oDC, "Separator", 0, nY + nRow - 1, nWidth, 1);
            end
        end
        oDC:delete();
    end);
    oComponent.onLayout = function(nWidth, nHeight)
        oScroll.layout(4, 4, math.max(1, nWidth - 8), math.max(1, nHeight - 8));
        oScroll.setContentSize(0, #tSpecs * nRow);
        local nView = oScroll.getViewportSize();
        nSplit = math.min(nLabel, math.max(40, math.floor(nView * 0.55)));
        for nIndex, tSpec in ipairs(tSpecs) do
            if (tEditors[tSpec.Id]) then
                tEditors[tSpec.Id].layout(nSplit, (nIndex - 1) * nRow + 3, math.max(1, nView - nSplit - 6), nRow - 6);
            end
        end
    end;
    oComponent.onEnable = function(bEnabled)
        oScroll.setEnabled(bEnabled);
        for sId, oEditor in pairs(tEditors) do oEditor.setEnabled(bEnabled and not tById[sId].ReadOnly); end
        oScroll.Content:Refresh(false);
    end;
    oComponent.onDestroy = function()
        for _, oEditor in pairs(tEditors) do oEditor.destroy(); end
        oScroll.destroy(); tArt.destroy();
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (not oComponent.Disposed) then
            tArt.part(oDC, "Surface "..(oComponent.isEnabled() and "Normal" or "Disabled"), 0, 0, nWidth, nHeight);
        end
    end;
    oComponent.setEnabled(tOptions.Enabled ~= false);
    return oComponent;
end

return PropertyGrid;
