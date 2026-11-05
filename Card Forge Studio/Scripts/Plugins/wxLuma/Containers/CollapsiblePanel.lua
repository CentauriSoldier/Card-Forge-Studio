local _wx      = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events  = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _finite  = require("wxLuma.Core.ControlNumeric").finite;
local CollapsiblePanel = {};

--[[!
@fqxn wxLuma.UI.CollapsiblePanel.create
@desc Creates a skinned disclosure header and clipped Content parent. Collapse
    hides real children without destroying their state. Layout remains owned by
    the caller; getBestHeight supplies the collapsed/expanded requested extent.
@param wxWindow oParent Native owner.
@param table tOptions Skin; optional Text, Expanded (true), HeaderHeight (36),
    ContentHeight (140), Artwork (Collapsible Panel), Enabled, OnChange.
@ret table oComponent Content parent, isExpanded/setExpanded/toggle/getBestHeight,
    expandedChanged and standard pointer, keyboard and lifetime subscriptions.
!]]
function CollapsiblePanel.create(oParent, tOptions)
    local nHeader = tOptions.HeaderHeight or 36;
    local nContent = tOptions.ContentHeight or 140;
    assert(_finite(nHeader) and nHeader % 1 == 0 and nHeader >= 24, "HeaderHeight must be at least 24.");
    assert(_finite(nContent) and nContent % 1 == 0 and nContent >= 0, "Invalid ContentHeight.");
    assert(tOptions.Expanded == nil or type(tOptions.Expanded) == "boolean", "Invalid Expanded.");
    local oComponent = _Surface.create(oParent, tOptions, "CollapsiblePanel");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Collapsible Panel");
    local tEvents = _Events.attach(oComponent, nil, {"expandedChanged"});
    local bExpanded = tOptions.Expanded ~= false;
    local oContent = _wx.wxPanel(oComponent.Control, _wx.wxID_ANY, _wx.wxDefaultPosition,
        _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxTAB_TRAVERSAL);
    oComponent.Content = oContent;
    oContent:SetBackgroundColour(tArt.color("Surface Normal"));

    --[[!
    @fqxn wxLuma.UI.CollapsiblePanel.isExpanded
    @desc Reports the stored expansion state independently of ancestor visibility.
    @ret boolean bExpanded Expansion state.
    !]]
    function oComponent.isExpanded() return bExpanded; end

    --[[!
    @fqxn wxLuma.UI.CollapsiblePanel.getBestHeight
    @desc Returns header height plus configured content height when expanded.
    @ret number nHeight Requested height in client pixels.
    !]]
    function oComponent.getBestHeight() return nHeader + (bExpanded and nContent or 0); end

    --[[!
    @fqxn wxLuma.UI.CollapsiblePanel.setExpanded
    @desc Shows/hides Content and preserves child state. Collapsing focused
        content returns focus to the header before hiding it. Optionally notifies.
    @param boolean bNext Requested expansion state.
    @param boolean|nil bNotify Emit expandedChanged and OnChange on change.
    @ret table oComponent This object.
    !]]
    function oComponent.setExpanded(bNext, bNotify)
        assert(not oComponent.Disposed and type(bNext) == "boolean", "Invalid expansion state.");
        if (bNext == bExpanded) then return oComponent; end
        if (not bNext) then
            local oFocus = _wx.wxWindow.FindFocus();
            if (oFocus and (oFocus == oContent or oContent:IsDescendant(oFocus))) then oComponent.Control:SetFocus(); end
        end
        bExpanded = bNext;
        oContent:Show(bNext);
        oComponent.refresh();
        if (bNotify) then
            tEvents.emit("expandedChanged", {Expanded = bNext, Value = bNext});
            if (oComponent.OnChange) then oComponent.OnChange(bNext, oComponent); end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.CollapsiblePanel.toggle
    @desc Toggles enabled disclosure input and notifies applications.
    @ret boolean bChanged Whether enabled input allowed the change.
    !]]
    function oComponent.toggle()
        if (not oComponent.isEnabled()) then return false; end
        oComponent.setExpanded(not bExpanded, true);
        return true;
    end
    oComponent.getValue = oComponent.isExpanded;
    oComponent.setValue = oComponent.setExpanded;
    oComponent.onLayout = function(nWidth, nHeight)
        oContent:SetSize(4, nHeader, math.max(1, nWidth - 8), math.max(1, nHeight - nHeader - 4));
    end;
    oComponent.onEnable = function(bEnabled) oContent:Enable(bEnabled); end;
    oComponent.onDestroy = function() tArt.destroy(); end;
    oComponent.pointer = function(sEvent, nX, nY)
        if (sEvent == "up" and oComponent.Pressed and oComponent.Hover and nY < nHeader) then oComponent.toggle(); end
    end;
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_RETURN or nKey == _wx.WXK_SPACE) then return oComponent.toggle(); end
        if (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_RIGHT) then
            oComponent.setExpanded(nKey == _wx.WXK_RIGHT, true);
            return true;
        end
        return false;
    end;
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then return; end
        tArt.part(oDC, "Surface "..(oComponent.isEnabled() and "Normal" or "Disabled"), 0, 0, nWidth, nHeight);
        tArt.part(oDC, "Header "..oComponent.getState(), 0, 0, nWidth, math.min(nHeader, nHeight));
        tArt.part(oDC, (bExpanded and "Open " or "Closed ")..oComponent.getState(), 10, (nHeader - 16) / 2, 16, 16);
        oDC:SetClippingRegion(32, 0, math.max(1, nWidth - 40), math.min(nHeader, nHeight));
        tArt.text(oDC, tOptions.Text or "Section", 34, (nHeader - 18) / 2, oComponent.isEnabled());
        oDC:DestroyClippingRegion();
        if (oComponent.Control:HasFocus()) then tArt.part(oDC, "Focus", 0, 0, nWidth, nHeader); end
    end;
    oContent:Show(bExpanded);
    oComponent.setEnabled(tOptions.Enabled ~= false);
    return oComponent;
end

return CollapsiblePanel;
