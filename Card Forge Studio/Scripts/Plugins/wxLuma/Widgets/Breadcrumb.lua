local _wx = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local Breadcrumb = {};

--[[!
@fqxn wxLuma.UI.Breadcrumb.create
@desc Creates a skinned hierarchy path with stable item IDs. Clicking an ancestor
    selects that prefix without removing deeper definitions. Left/Right/Home/End
    navigate; narrow layouts scroll to the selection, with a leading back glyph.
@param wxWindow oParent Native owner.
@param table tOptions Skin, Items={Id,Text,Image?}, optional Value (last ID), Artwork,
    Enabled and OnChange(id, component).
@ret table oComponent get/setItems, get/setValue, getPath and shared input events.
!]]
function Breadcrumb.create(oParent, tOptions)
    local tItems, tById, nSelected, tHits = {}, {}, 0, {};
    local oComponent = _Surface.create(oParent, tOptions, "Breadcrumb");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Breadcrumb");
    local tEvents = _Events.attach(oComponent, nil, {"itemsChanged"});
    local sPressed;

    --[[!
    @fqxn wxLuma.UI.Breadcrumb.getItems
    @desc Returns independent path descriptors in display order.
    !]]
    function oComponent.getItems()
        local tCopy = {};
        for nIndex, tItem in ipairs(tItems) do
            tCopy[nIndex] = {Id = tItem.Id, Text = tItem.Text, Image = tItem.Image};
        end
        return tCopy;
    end
    --[[!
    @fqxn wxLuma.UI.Breadcrumb.getValue
    @desc Returns the selected stable ID, or nil for an empty/unselected path.
    !]]
    function oComponent.getValue() return tItems[nSelected] and tItems[nSelected].Id or nil; end
    --[[!
    @fqxn wxLuma.UI.Breadcrumb.setValue
    @desc Selects an existing ID; nil clears selection. Definitions are never created by selection.
    !]]
    function oComponent.setValue(sId, bNotify)
        assert(sId == nil or tById[sId], "Unknown breadcrumb ID.");
        if (oComponent.Disposed) then return oComponent; end
        local sOld = oComponent.getValue();
        nSelected = sId and tById[sId] or 0;
        if (sOld ~= sId) then
            oComponent.refresh();
            if (bNotify) then
                tEvents.emit("valueChanged", {Value = sId, OldValue = sOld});
                if (oComponent.OnChange) then oComponent.OnChange(sId, oComponent); end
            end
        end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Breadcrumb.setItems
    @desc Validates/copies dense, uniquely identified path definitions before replacing them; preserves a surviving selection.
    !]]
    function oComponent.setItems(tSource, bNotify)
        assert(type(tSource) == "table", "Items must be a dense array.");
        local tNext, tIndex, nCount = {}, {}, 0;
        for nKey in pairs(tSource) do
            nCount = nCount + 1;
            assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tSource, "Items must be dense.");
        end
        assert(nCount == #tSource, "Items must be dense.");
        for nIndex, tItem in ipairs(tSource) do
            assert(type(tItem) == "table" and type(tItem.Id) == "string" and tItem.Id ~= "" and not tIndex[tItem.Id]
                and type(tItem.Text) == "string" and (tItem.Image == nil or type(tItem.Image) == "string"), "Invalid breadcrumb item.");
            tArt.prepare(tItem.Image);
            tNext[nIndex] = {Id = tItem.Id, Text = tItem.Text, Image = tItem.Image};
            tIndex[tItem.Id] = nIndex;
        end
        local sOld = oComponent.getValue();
        tItems, tById = tNext, tIndex;
        tArt.retain(tItems);
        nSelected = sOld and tById[sOld] or #tItems;
        oComponent.refresh();
        if (bNotify) then tEvents.emit("itemsChanged", {Count = #tItems}); end
        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.Breadcrumb.getPath
    @desc Returns descriptor copies from the root through the selected ancestor.
    !]]
    function oComponent.getPath()
        local tCopy = oComponent.getItems();
        for nIndex = #tCopy, nSelected + 1, -1 do tCopy[nIndex] = nil; end
        return tCopy;
    end

    --[[!
    @fqxn wxLuma.UI.Breadcrumb.layoutHits
    @desc Measures text once per draw/hit query and exposes selection without squeezing labels.
    !]]
    local function fHits(oDC, nWidth)
        local tWidths, nSelectedEnd = {}, 0;
        oDC:SetFont(oComponent.Skin.Font);
        for nIndex, tItem in ipairs(tItems) do
            local nText = oDC:GetTextExtent(tItem.Text);
            tWidths[nIndex] = nText + (tItem.Image and 52 or 28);
            if (nIndex <= nSelected) then nSelectedEnd = nSelectedEnd + tWidths[nIndex] + 18; end
        end
        local nOffset = math.max(0, nSelectedEnd - math.max(1, nWidth - 12));
        local nX = 6 - nOffset;
        tHits = {};
        for nIndex, tItem in ipairs(tItems) do
            tHits[#tHits + 1] = {X = nX, Width = tWidths[nIndex], Index = nIndex};
            nX = nX + tWidths[nIndex] + 18;
        end
        return nOffset;
    end
    oComponent.pointer = function(sEvent, nX)
        local oDC = _wx.wxClientDC(oComponent.Control);
        local nOffset = fHits(oDC, oComponent.Control:GetClientSizeWH()); oDC:delete();
        local sHit;
        if (nOffset > 0 and nX < 24) then
            sHit = tItems[math.max(1, nSelected - 1)] and tItems[math.max(1, nSelected - 1)].Id;
        else
            for _, tHit in ipairs(tHits) do
                if (nX >= math.max(0, tHit.X) and nX < tHit.X + tHit.Width) then sHit = tItems[tHit.Index].Id; break; end
            end
        end
        if (sEvent == "down") then sPressed = sHit;
        elseif (sEvent == "up" and oComponent.Pressed and sPressed and sPressed == sHit) then oComponent.setValue(sHit, true); end
    end;
    oComponent.key = function(nKey)
        local nNext;
        if (nKey == _wx.WXK_LEFT) then nNext = math.max(1, nSelected - 1);
        elseif (nKey == _wx.WXK_RIGHT) then nNext = math.min(#tItems, nSelected + 1);
        elseif (nKey == _wx.WXK_HOME) then nNext = 1;
        elseif (nKey == _wx.WXK_END) then nNext = #tItems;
        else return false; end
        if (tItems[nNext]) then oComponent.setValue(tItems[nNext].Id, true); end
        return true;
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        local sState = oComponent.getState();
        tArt.part(oDC, "Surface "..sState, 0, 0, nWidth, nHeight);
        local nOffset = fHits(oDC, nWidth);
        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)));
        for _, tHit in ipairs(tHits) do
            if (tHit.X + tHit.Width > 0 and tHit.X < nWidth) then
                local tItem = tItems[tHit.Index];
                tArt.part(oDC, "Item "..(oComponent.isEnabled() and tHit.Index == nSelected and "Hover" or sState), tHit.X, 2, tHit.Width, nHeight - 4);
                if (tItem.Image) then tArt.image(oDC, tItem.Image, tHit.X + 6, (nHeight - 20) / 2, 20); end
                tArt.text(oDC, tItem.Text, tHit.X + (tItem.Image and 32 or 10), (nHeight - 18) / 2, oComponent.isEnabled());
                tArt.part(oDC, "Separator "..sState, tHit.X + tHit.Width, (nHeight - 16) / 2, 16, 16);
            end
        end
        if (nOffset > 0) then
            tArt.part(oDC, "Item "..sState, 0, 0, 24, nHeight);
            tArt.part(oDC, "Back "..sState, 4, (nHeight - 16) / 2, 16, 16);
        end
        oClip:delete();
    end;
    oComponent.onDestroy = tArt.destroy;
    oComponent.setItems(tOptions.Items or {});
    if (tOptions.Value ~= nil) then oComponent.setValue(tOptions.Value); end
    return oComponent;
end

return Breadcrumb;
