--[[!
@fqxn wxLuma.State
@desc Serializer-independent state snapshots for existing wxLuma object trees.
    Flat node records and iterative walks support arbitrary finite nesting without
    consuming the Lua call stack. Loading never constructs UI or item objects.
!]]
local _Object = require("wxLuma.Core.ControlObject");
local _tAdapters = {};
local State = {};

-- Ordered setters restore capacity/geometry before values and selection. Only
-- explicit public state APIs are included; constructors, item definitions,
-- event subscriptions and native transient interaction are never inspected.
local _tProperties = {
    {"LogOptions"}, {"ChartOptions"}, {"Entries"}, {"Series"},
    {"Precision"}, {"Range"}, {"Step"}, {"Continuity"}, {"Rate"}, {"MotionDirection"},
    {"Severity"}, {"Duration"}, {"DockState"}, {"Reserved"}, {"Orientation"}, {"Reversed"},
    {"Glow"}, {"GlowRadius"}, {"Glass"}, {"Brightness"}, {"Size"}, {"Color"}, {"Origin"},
    {"Direction"}, {"StartAngle"}, {"ReserveOrigin"}, {"ReserveDirection"},
    {"ReserveStartAngle"}, {"Radii"}, {"Appearance"}, {"ReserveRenderer"},
    {"Supersampling"}, {"BladeCount"}, {"Rotation"}, {"BackgroundImage"},
    {"BackgroundImageFit"}, {"AutoComplete"}, {"ScaleMode"}, {"Position"}, {"LayoutMode"},
    {"MultiSelectEnabled", "isMultiSelectEnabled"}, {"CheckboxesEnabled", "isCheckboxesEnabled"},
    {"CheckPropagationEnabled", "isCheckPropagationEnabled"}, {"Value"}, {"Selected"},
    {"CheckedItems", "getChecked"}, {"ReadOnly", "isReadOnly"}, {"TextSelection"}, {"FollowingTail"}
};

--[[!
@fqxn wxLuma.State.copy
@desc Copies plain state data iteratively. Rejects functions, userdata, threads,
    custom metatables and nonfinite numbers instead of leaking runtime resources.
    Shared plain tables are copied once; their identity is preserved in the result.
!]]
local function copy(vSource)
    local tCopies, tPending = {}, {};

    --[[!
    @fqxn wxLuma.State.copy.value
    @desc Validates one data value and queues unseen tables without recursion.
    !]]
    local function fValue(vValue)
        local sType = type(vValue);

        if (sType == "table") then
            assert(getmetatable(vValue) == nil, "State values must be plain data tables.");

            if (not tCopies[vValue]) then
                tCopies[vValue] = {};
                tPending[#tPending + 1] = vValue;
            end

            return tCopies[vValue];
        end

        assert(sType == "nil" or sType == "string" or sType == "boolean" or
            sType == "number" and vValue == vValue and math.abs(vValue) < math.huge,
            "State values must be finite data, not native resources or callbacks.");
        return vValue;
    end

    local vResult = fValue(vSource);
    local nNext = 1;

    while (nNext <= #tPending) do
        local tSource = tPending[nNext];
        nNext = nNext + 1;

        for vKey, vValue in pairs(tSource) do
            assert(type(vKey) == "string" or type(vKey) == "number", "State keys must be strings or numbers.");
            tCopies[tSource][fValue(vKey)] = fValue(vValue);
        end
    end

    return vResult;
end

-- The public copier follows the same plain-data contract as snapshots. Widgets
-- use it for independent data/settings payloads without exposing native objects.
State.copy = copy;

--[[!
@fqxn wxLuma.State.hierarchy
@desc Discovers existing native and explicit logical ownership once per operation.
    Native intermediate panels are traversed without becoming saved objects.
    Explicit links override native ownership; each object has one state parent.
!]]
local function hierarchy()
    local tInstances = _Object.instances();
    local tChildren, tWindows, tExplicit = {}, {}, {};

    for oObject in pairs(tInstances) do
        if (not oObject.Disposed) then
            tChildren[oObject] = {};
            local oNative = oObject.Frame or oObject.Dialog or oObject.Control;

            if (oNative and oNative.GetId) then
                local nId = oNative:GetId();
                assert(not tWindows[nId] or tWindows[nId] == oObject, "Ambiguous native state owner.");
                tWindows[nId] = oObject;
            end
        end
    end

    for oParent, tInfo in pairs(tInstances) do
        if (tChildren[oParent]) then
            for sId, oChild in pairs(tInfo.Children) do
                if (tChildren[oChild]) then
                    assert(not tExplicit[oChild], "An object cannot have multiple explicit state parents.");
                    tExplicit[oChild] = oParent;
                    tChildren[oParent][sId] = oChild;
                end
            end
        end
    end

    for oObject, tInfo in pairs(tInstances) do
        if (tChildren[oObject] and not tExplicit[oObject]) then
            local oNative = oObject.Frame or oObject.Dialog or oObject.Control;
            local oParent = oNative and oNative.GetParent and oNative:GetParent();

            while (oParent) do
                local oOwner = tWindows[oParent:GetId()];

                if (oOwner) then
                    assert(not tChildren[oOwner][tInfo.Id] or tChildren[oOwner][tInfo.Id] == oObject,
                        "Sibling state IDs must be unique.");
                    tChildren[oOwner][tInfo.Id] = oObject;
                    break;
                end

                oParent = oParent:GetParent();
            end
        end
    end

    return tChildren;
end

--[[!
@fqxn wxLuma.State.captureProperties
@desc Captures supported mutable public properties. Property-grid IDs are data
    identities; row/editor definitions are retained by the existing application.
!]]
local function captureProperties(oObject, sType)
    local tAdapter = _tAdapters[sType];

    if (tAdapter) then
        return {Custom = tAdapter.capture(oObject)};
    end

    local tProperties = {};

    for _, tProperty in ipairs(_tProperties) do
        local sName = tProperty[1];
        local fGet = oObject[tProperty[2] or "get"..sName];

        if (type(fGet) == "function" and type(oObject["set"..sName]) == "function") then
            tProperties[sName] = table.pack(fGet());
        end
    end

    if (oObject.Control and type(oObject.setEnabled) == "function") then
        local oControl = oObject.Frame or oObject.Dialog or oObject.Control;
        local bEnabled;

        if (sType == "wxLuma.UI.Tooltip") then
            -- Tooltip availability is a logical policy; the popup window is not
            -- disabled natively. Preserve that policy independently of its owner.
            bEnabled = oObject.Enabled;
        elseif (oControl.IsThisEnabled) then
            bEnabled = oControl:IsThisEnabled();
        else
            bEnabled = oControl:IsEnabled();
        end

        tProperties.Enabled = {n = 1, bEnabled};
    end

    if (sType == "wxLuma.UI.Tabs" and tProperties.Value and tProperties.Value[1] ~= 0) then
        local tItems = oObject.getItems();
        tProperties.Value[1] = tItems[tProperties.Value[1]].Id;
    end

    if (sType == "wxLuma.UI.Tree" or sType == "wxLuma.UI.TreeEx") then
        local tPending = oObject.getChildren();
        local tExpanded = {};
        local nNext = 1;

        while (nNext <= #tPending) do
            local sId = tPending[nNext];
            nNext = nNext + 1;
            tExpanded[sId] = oObject.getNode(sId).Expanded;

            for _, sChild in ipairs(oObject.getChildren(sId)) do
                tPending[#tPending + 1] = sChild;
            end
        end

        tProperties.ExpandedNodes = tExpanded;
    end

    for _, sName in ipairs({"Text", "Title", "Subtitle"}) do
        if (type(oObject[sName]) == "string") then
            tProperties["Field"..sName] = oObject[sName];
        end
    end

    return tProperties;
end

--[[!
@fqxn wxLuma.State.applyProperties
@desc Restores existing state through setters in dependency order. Saved object
    definitions are never installed. Missing property-grid rows are skipped too.
!]]
local function applyProperties(oObject, sType, tProperties)
    local tAdapter = _tAdapters[sType];

    if (tProperties.Custom ~= nil) then
        assert(tAdapter, "Saved custom state requires its registered adapter: "..sType);
        tAdapter.restore(oObject, tProperties.Custom);
        return;
    end

    for sId, bExpanded in pairs(tProperties.ExpandedNodes or {}) do
        if (oObject.getNode(sId)) then
            oObject.setExpanded(sId, bExpanded, false);
        end
    end

    for _, tProperty in ipairs(_tProperties) do
        local sName = tProperty[1];
        local tValue = tProperties[sName];
        local fSet = oObject["set"..sName];

        if (tValue and type(fSet) == "function") then
            if (sName == "Value" and sType == "wxLuma.UI.PropertyGrid") then
                local tExisting = oObject.getValue();

                for sId, vValue in pairs(tValue[1]) do
                    if (tExisting[sId] ~= nil) then
                        fSet(sId, vValue, false);
                    end
                end
            elseif (sName == "Value" and sType == "wxLuma.UI.Tabs") then
                local bFound = tValue[1] ~= 0 and pcall(oObject.getPage, tValue[1]);

                if (bFound) then
                    fSet(tValue[1], false);
                end
            elseif ((sType == "wxLuma.UI.Tree" or sType == "wxLuma.UI.TreeEx") and sName == "Value") then
                if (tValue[1] == nil or oObject.getNode(tValue[1])) then
                    fSet(tValue[1], false);
                end
            elseif (sName == "Value" and sType == "wxLuma.UI.Breadcrumb") then
                local bFound = tValue[1] == nil;
                for _, tItem in ipairs(oObject.getItems()) do bFound = bFound or tItem.Id == tValue[1]; end
                if (bFound) then fSet(tValue[1], false); end
            elseif (sType == "wxLuma.UI.LogViewer" and sName == "Selected") then
                -- Preserve the separately saved primary entry while the public
                -- selected array remains sorted in insertion/display order.
                local sPrimary = tProperties.Value and tProperties.Value[1]; local tIds = {};
                for _, sId in ipairs(tValue[1]) do if (sId ~= sPrimary) then tIds[#tIds + 1] = sId; end end
                if (sPrimary) then tIds[#tIds + 1] = sPrimary; end
                fSet(tIds, false);
            elseif (oObject.getNode and (sName == "Selected" or sName == "CheckedItems")) then
                local tIds = {};

                for _, sId in ipairs(tValue[1]) do
                    if (oObject.getNode(sId)) then
                        tIds[#tIds + 1] = sId;
                    end
                end

                if (#tIds > 0 or #tValue[1] == 0) then
                    fSet(tIds, false);
                end
            else
                local tArguments = {};

                for nIndex = 1, tValue.n do
                    tArguments[nIndex] = tValue[nIndex];
                end

                tArguments[tValue.n + 1] = false;
                fSet(table.unpack(tArguments, 1, tValue.n + 1));
            end
        end
    end

    for _, sName in ipairs({"Text", "Title", "Subtitle"}) do
        if (tProperties["Field"..sName] ~= nil) then
            oObject[sName] = tProperties["Field"..sName];
        end
    end

    if (tProperties.Enabled and type(oObject.setEnabled) == "function") then
        oObject.setEnabled(tProperties.Enabled[1]);
    end

    if (type(oObject.refresh) == "function") then
        oObject.refresh();
    end
end

--[[!
@fqxn wxLuma.State.register
@desc Registers application state for one exact object type. Adapters read/write
    existing objects only and must return plain data; they never create children.
@param string sType Full object type, such as wxLuma.UI.CustomControl.
@param table tAdapter capture(object), restore(object,data), optional validate(data).
!]]
function State.register(sType, tAdapter)
    assert(type(sType) == "string" and type(tAdapter) == "table" and type(tAdapter.capture) == "function"
        and type(tAdapter.restore) == "function" and (tAdapter.validate == nil or type(tAdapter.validate) == "function"),
        "State adapter requires capture/restore and optional validate functions.");
    assert(not _tAdapters[sType] or _tAdapters[sType] == tAdapter, "State adapter already registered.");
    _tAdapters[sType] = tAdapter;
end

--[[!
@fqxn wxLuma.State.capture
@desc Captures an object tree into flat versioned data. Stable child identities
    match across application sessions when setStateId is used. Shared/cyclic UI
    ownership is rejected; nesting itself imposes no fixed limit or recursion.
@param table oRoot Existing root object.
@ret table tState Format, Version and an Objects array rooted at index one.
!]]
function State.capture(oRoot)
    local tInstances = _Object.instances();
    assert(tInstances[oRoot] and not oRoot.Disposed, "State requires a live wxLuma root.");
    local tChildren = hierarchy();
    local tState = {Format = "wxLuma.State", Version = 1, Objects = {}};
    local tPending, tSeen = {oRoot}, {[oRoot] = true};
    local nNext = 1;

    while (nNext <= #tPending) do
        local oObject = tPending[nNext];
        local sType = tInstances[oObject].Type;
        local tNode = {Type = sType, Properties = captureProperties(oObject, sType), Children = {}};
        tState.Objects[nNext] = tNode;
        nNext = nNext + 1;
        local tIds = {};

        for sId in pairs(tChildren[oObject]) do
            tIds[#tIds + 1] = sId;
        end

        table.sort(tIds);

        for _, sId in ipairs(tIds) do
            local oChild = tChildren[oObject][sId];
            assert(not tSeen[oChild], "Cyclic/shared state ownership is not a tree.");
            tSeen[oChild] = true;
            tPending[#tPending + 1] = oChild;
            tNode.Children[sId] = #tPending;
        end
    end

    return copy(tState);
end

--[[!
@fqxn wxLuma.State.validate
@desc Validates flat ownership before touching live state. Every node has one
    incoming edge, root has none, and all nodes must be reachable without cycles.
!]]
local function validate(tState)
    assert(tState.Format == "wxLuma.State" and tState.Version == 1 and type(tState.Objects) == "table",
        "Unsupported wxLuma state format/version.");
    local tNodes, tIncoming = tState.Objects, {};
    local nCount = 0;

    for nIndex, tNode in pairs(tNodes) do
        nCount = nCount + 1;
        assert(type(nIndex) == "number" and nIndex % 1 == 0 and nIndex >= 1 and type(tNode) == "table"
            and type(tNode.Type) == "string" and type(tNode.Properties) == "table" and type(tNode.Children) == "table",
            "Malformed state object record.");
    end

    assert(nCount >= 1 and #tNodes == nCount, "State objects must be a nonempty dense array.");

    for _, tNode in ipairs(tNodes) do
        for sId, nChild in pairs(tNode.Children) do
            assert(type(sId) == "string" and sId:find("%S") and type(nChild) == "number"
                and nChild % 1 == 0 and nChild > 1 and nChild <= nCount and not tIncoming[nChild],
                "Invalid/shared state child reference.");
            tIncoming[nChild] = true;
        end
    end

    local tPending, tSeen = {1}, {[1] = true};
    local nNext = 1;

    while (nNext <= #tPending) do
        local nNode = tPending[nNext];
        nNext = nNext + 1;

        for _, nChild in pairs(tNodes[nNode].Children) do
            assert(not tSeen[nChild], "Cyclic state ownership.");
            tSeen[nChild] = true;
            tPending[#tPending + 1] = nChild;
        end
    end

    assert(#tPending == nCount, "Unreachable state object records.");
end

--[[!
@fqxn wxLuma.State.restore
@desc Applies saved state to existing matching nodes. Missing/disposed children
    and type replacements skip their entire saved subtree. Extra live children
    remain untouched. Values use silent setters; normal lifecycle events can fire.
    Invalid matched state raises an error; already applied nodes are rolled back
    using their captured state where their public setters permit restoration.
@param table oRoot Existing root; never replaced or constructed.
@param table tSource Previously captured snapshot.
@ret table tReport Applied and Skipped saved-object counts.
!]]
function State.restore(oRoot, tSource)
    local tInstances = _Object.instances();
    assert(tInstances[oRoot] and not oRoot.Disposed, "State requires a live wxLuma root.");
    local tState = copy(tSource);
    assert(type(tState) == "table", "State must be a data table.");
    validate(tState);
    local tChildren = hierarchy();
    local tPending = {{Object = oRoot, Node = 1}};
    local tMatched, tSeen = {}, {};
    local nNext = 1;

    while (nNext <= #tPending) do
        local tMatch = tPending[nNext];
        nNext = nNext + 1;
        local oObject, tNode = tMatch.Object, tState.Objects[tMatch.Node];

        if (tInstances[oObject].Type == tNode.Type) then
            assert(not tSeen[oObject], "Cyclic/shared live state ownership.");
            tSeen[oObject] = true;
            tMatch.Before = copy(captureProperties(oObject, tNode.Type));
            local tAdapter = _tAdapters[tNode.Type];

            if (tAdapter and tAdapter.validate) then
                tAdapter.validate(tNode.Properties.Custom);
            end

            tMatched[#tMatched + 1] = tMatch;

            for sId, nChild in pairs(tNode.Children) do
                local oChild = tChildren[oObject][sId];

                if (oChild) then
                    tPending[#tPending + 1] = {Object = oChild, Node = nChild};
                end
            end
        end
    end

    local nApplied = 0;
    local bOK, sError = pcall(function()
        for nIndex, tMatch in ipairs(tMatched) do
            nApplied = nIndex;
            local tNode = tState.Objects[tMatch.Node];
            applyProperties(tMatch.Object, tNode.Type, tNode.Properties);
        end
    end);

    if (not bOK) then
        for nIndex = nApplied, 1, -1 do
            local tMatch = tMatched[nIndex];
            pcall(applyProperties, tMatch.Object, tInstances[tMatch.Object].Type, tMatch.Before);
        end

        error(sError, 0);
    end

    return {Applied = #tMatched, Skipped = #tState.Objects - #tMatched};
end

return State;
