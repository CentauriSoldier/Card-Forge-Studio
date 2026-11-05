local _Surface = require("wxLuma.Core.ControlSurface");
local _Events  = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local _Scroll  = require("wxLuma.Containers.ScrollContainer");
local _Panel   = require("wxLuma.Containers.CollapsiblePanel");
local _finite  = require("wxLuma.Core.ControlNumeric").finite;
local Accordion = {};

--[[!
@fqxn wxLuma.UI.Accordion.create
@desc Arranges independent collapsible sections in a scrollable viewport.
    Exclusive mode keeps at most one section open. Section native Content owns
    application children; collapsing preserves them and their current values.
@param wxWindow oParent Native owner.
@param table tOptions Skin, Sections ({Id,Text,Height,Expanded}); optional
    Exclusive (true), Artwork (Accordion), SectionArtwork (Collapsible Panel),
    Enabled, OnChange(id, expanded, component).
@ret table oComponent getSection/setExpanded/getExpanded, Sections, Scroll,
    expandedChanged and standard component events.
!]]
function Accordion.create(oParent, tOptions)
    assert(type(tOptions.Sections) == "table", "Accordion requires Sections.");
    assert(tOptions.Exclusive == nil or type(tOptions.Exclusive) == "boolean", "Invalid Exclusive.");
    local tSpecs, tSeen = {}, {};
    local nCount = 0;
    for nKey in pairs(tOptions.Sections) do
        nCount = nCount + 1;
        assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tOptions.Sections,
            "Sections must be a dense array.");
    end
    assert(nCount == #tOptions.Sections, "Sections must be a dense array.");
    for nIndex, tSection in ipairs(tOptions.Sections) do
        assert(type(tSection) == "table" and type(tSection.Id) == "string" and tSection.Id ~= ""
            and not tSeen[tSection.Id], "Invalid/duplicate section Id.");
        local nHeight = tSection.Height or 140;
        assert(tSection.Text == nil or type(tSection.Text) == "string", "Invalid section Text.");
        assert(_finite(nHeight) and nHeight >= 0 and nHeight % 1 == 0, "Invalid section Height.");
        assert(tSection.Expanded == nil or type(tSection.Expanded) == "boolean", "Invalid section Expanded.");
        tSpecs[nIndex] = {Id = tSection.Id, Text = tSection.Text or tSection.Id, Height = nHeight,
            Expanded = tSection.Expanded == true};
        tSeen[tSection.Id] = true;
    end
    local oComponent = _Surface.create(oParent, tOptions, "Accordion");
    local tArt = _Artwork.create(tOptions.Skin, tOptions.Artwork or "Accordion");
    local tEvents = _Events.attach(oComponent, nil, {"expandedChanged"});
    local oScroll = _Scroll.create(oComponent.Control, {Skin = tOptions.Skin});
    local tSections, tOrder = {}, {};
    oComponent.Sections, oComponent.Scroll = tSections, oScroll;
    local bChanging = false;

    --[[!
    @fqxn wxLuma.UI.Accordion.fLayout
    @desc Reflows section bounds after expansion and updates the scroll extent.
        A second width pass accounts for a newly appearing vertical scrollbar.
    !]]
    local function fLayout()
        if (oComponent.Disposed) then return; end
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        oScroll.layout(4, 4, math.max(1, nWidth - 8), math.max(1, nHeight - 8));
        local nTotal = 4;
        for _, oSection in ipairs(tOrder) do nTotal = nTotal + oSection.getBestHeight() + 4; end
        oScroll.setContentSize(0, nTotal);
        local nView = oScroll.getViewportSize();
        local nY = 4;
        for _, oSection in ipairs(tOrder) do
            oSection.layout(4, nY, math.max(1, nView - 8), oSection.getBestHeight());
            nY = nY + oSection.getBestHeight() + 4;
        end
    end

    --[[!
    @fqxn wxLuma.UI.Accordion.getSection
    @desc Returns the named section, whose Content accepts application controls.
    @param string sId Section ID.
    @ret table oSection CollapsiblePanel component.
    !]]
    function oComponent.getSection(sId)
        return assert(tSections[sId], "Unknown accordion section: "..tostring(sId));
    end

    --[[!
    @fqxn wxLuma.UI.Accordion.getExpanded
    @desc Returns open section IDs in display order as an independent array.
    @ret table tIds Open section IDs.
    !]]
    function oComponent.getExpanded()
        local tIds = {};
        for _, tSpec in ipairs(tSpecs) do
            if (tSections[tSpec.Id].isExpanded()) then tIds[#tIds + 1] = tSpec.Id; end
        end
        return tIds;
    end

    --[[!
    @fqxn wxLuma.UI.Accordion.setExpanded
    @desc Applies section expansion and exclusive sibling collapse as one layout
        update. Each effective section transition can notify independently.
    @param string sId Section ID.
    @param boolean bExpanded New state.
    @param boolean|nil bNotify Emit expandedChanged and OnChange.
    @ret table oComponent This object.
    !]]
    function oComponent.setExpanded(sId, bExpanded, bNotify)
        assert(not oComponent.Disposed and type(bExpanded) == "boolean", "Invalid accordion state.");
        local oTarget = oComponent.getSection(sId);
        local tChanged = {};
        bChanging = true;
        if (bExpanded and tOptions.Exclusive ~= false) then
            for _, tSpec in ipairs(tSpecs) do
                local oSection = tSections[tSpec.Id];
                if (oSection ~= oTarget and oSection.isExpanded()) then
                    oSection.setExpanded(false);
                    tChanged[#tChanged + 1] = {Id = tSpec.Id, Expanded = false};
                end
            end
        end
        if (oTarget.isExpanded() ~= bExpanded) then
            oTarget.setExpanded(bExpanded);
            tChanged[#tChanged + 1] = {Id = sId, Expanded = bExpanded};
        end
        bChanging = false;
        fLayout();
        if (bNotify) then
            for _, tChange in ipairs(tChanged) do
                tEvents.emit("expandedChanged", tChange);
                if (tOptions.OnChange) then tOptions.OnChange(tChange.Id, tChange.Expanded, oComponent); end
            end
        end
        return oComponent;
    end
    local bOpened = false;
    for _, tSpec in ipairs(tSpecs) do
        local bExpanded = tSpec.Expanded and (tOptions.Exclusive == false or not bOpened);
        bOpened = bOpened or bExpanded;
        local oSection = _Panel.create(oScroll.Content, {Skin = tOptions.Skin, Text = tSpec.Text,
            ContentHeight = tSpec.Height, Expanded = bExpanded, Artwork = tOptions.SectionArtwork});
        tSections[tSpec.Id], tOrder[#tOrder + 1] = oSection, oSection;
        oSection.on("expandedChanged", function(oSource, tEvent)
            if (not bChanging) then
                -- The section already applied its input. Collapse siblings
                -- without hiding/showing the target a second time.
                if (tEvent.Expanded and tOptions.Exclusive ~= false) then
                    for _, tOther in ipairs(tSpecs) do
                        if (tOther.Id ~= tSpec.Id and tSections[tOther.Id].isExpanded()) then
                            oComponent.setExpanded(tOther.Id, false, true);
                        end
                    end
                end
                fLayout();
                tEvents.emit("expandedChanged", {Id = tSpec.Id, Expanded = tEvent.Expanded});
                if (tOptions.OnChange) then tOptions.OnChange(tSpec.Id, tEvent.Expanded, oComponent); end
            end
        end);
        for _, sEvent in ipairs({"pointerEnter", "pointerLeave", "leftDown", "leftUp", "rightDown", "rightUp", "leftClick", "rightClick"}) do
            oSection.on(sEvent, function(oSource, tEvent)
                tEvents.emit(sEvent, {Id = tSpec.Id, Child = oSource, NativeEvent = tEvent.NativeEvent});
            end);
        end
    end
    oComponent.onLayout = fLayout;
    oComponent.onEnable = function(bEnabled)
        oScroll.setEnabled(bEnabled);
        for _, oSection in ipairs(tOrder) do oSection.setEnabled(bEnabled); end
    end;
    oComponent.onDestroy = function()
        for _, oSection in ipairs(tOrder) do oSection.destroy(); end
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

return Accordion;
