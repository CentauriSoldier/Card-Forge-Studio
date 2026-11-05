--[[!
@fqxn wxLuma.UI.ControlObject
@desc Shared actual/decoy/metatable construction for UI instances. Module tables
    and temporary data remain ordinary tables. Component fields stay writable
    to preserve existing widget extension hooks and application behavior.
!]]
local ControlObject = {};
local _tInstances = setmetatable({}, {__mode = "k"});
local _nNextId = 0;
local _sSession = tostring({});

--[[!
@fqxn wxLuma.UI.ControlObject.instances
@desc Returns live object identities and private persistence metadata. The weak
    registry does not extend native/object lifetime. Used by the state layer to
    discover existing containment without reading arbitrary object fields.
@ret table tInstances Object/metadata pairs; callers must not mutate metadata.
!]]
function ControlObject.instances()
    return _tInstances;
end

--[[!
@fqxn wxLuma.UI.ControlObject.create
@desc Creates an empty public decoy over the supplied actual storage. Reads and
    writes reach that storage through the metatable; methods retain their normal
    dot-call signatures. Each call creates an independent decoy and metatable.
@param table tActual The component's fields and methods.
@param string sType The descriptive object name used to protect its metatable.
@ret table oObject The public object. Iteration exposes its stored fields.
!]]
function ControlObject.create(tActual, sType)
    assert(type(tActual) == "table", "Object storage must be a table.");
    assert(type(sType) == "string", "Object type must be a string.");

    local tDecoy = {};
    local tMeta  = {

        -- Read optional hooks as nil rather than rejecting absent properties.
        __index = function(tObject, vKey)
            return tActual[vKey];
        end,

        -- Keep all regular assignments out of the public decoy itself.
        __newindex = function(tObject, vKey, vValue)
            tActual[vKey] = vValue;
        end,

        -- Preserve pairs-based inspection of the former component tables.
        __pairs = function()
            return next, tActual, nil;
        end,

        __metatable = sType,
    };

    setmetatable(tDecoy, tMeta);
    _nNextId = _nNextId + 1;
    local tIdentity = {Type = sType, Id = _sSession..":".._nNextId, Children = {}};
    _tInstances[tDecoy] = tIdentity;

    --[[!
    @fqxn wxLuma.UI.ControlObject.getStateId
    @desc Returns this object's state identity. Generated IDs identify this live
        instance only; applications assign stable IDs for saves across sessions.
    @ret string sId State identity within its containing object.
    !]]
    function tActual.getStateId()
        return tIdentity.Id;
    end

    --[[!
    @fqxn wxLuma.UI.ControlObject.setStateId
    @desc Assigns a stable application ID for matching state after reconstruction.
        IDs must be unique among siblings; no native name or parent is changed.
    @param string sId Nonempty application identity.
    @ret table oObject This object.
    !]]
    function tActual.setStateId(sId)
        assert(type(sId) == "string" and sId:find("%S"), "State ID must be a nonblank string.");
        tIdentity.Id = sId;
        return tDecoy;
    end

    --[[!
    @fqxn wxLuma.UI.ControlObject.addStateChild
    @desc Includes an existing logical child not represented by native parenting.
        This registers state ownership only; it never creates or reparents objects.
    @param string sId Stable child identity within this object.
    @param table oChild Existing wxLuma object.
    @ret table oObject This object.
    !]]
    function tActual.addStateChild(sId, oChild)
        assert(type(sId) == "string" and sId:find("%S") and _tInstances[oChild]
            and oChild ~= tDecoy, "Invalid state child.");
        assert(not tIdentity.Children[sId] or tIdentity.Children[sId] == oChild, "Duplicate state child ID.");
        tIdentity.Children[sId] = oChild;
        return tDecoy;
    end

    --[[!
    @fqxn wxLuma.UI.ControlObject.removeStateChild
    @desc Removes an explicit state link without destroying its object. Native
        children remain discoverable while they are still natively contained.
    @param string sId Previously registered logical child identity.
    @ret table oObject This object.
    !]]
    function tActual.removeStateChild(sId)
        tIdentity.Children[sId] = nil;
        return tDecoy;
    end

    --[[!
    @fqxn wxLuma.UI.ControlObject.getObjectState
    @desc Captures this object and contained children as a detached data table.
        No serializer, native handles, callbacks or object constructors are used.
    @ret table tState Versioned state snapshot.
    !]]
    function tActual.getObjectState()
        return require("wxLuma.State").capture(tDecoy);
    end

    --[[!
    @fqxn wxLuma.UI.ControlObject.setObjectState
    @desc Restores matching existing objects silently. Missing children and their
        descendants are skipped; extra live objects remain untouched.
    @param table tState Previously captured data table.
    @ret table oObject This object.
    @ret table tReport Applied and skipped object counts.
    !]]
    function tActual.setObjectState(tState)
        return tDecoy, require("wxLuma.State").restore(tDecoy, tState);
    end

    return tDecoy;
end

return ControlObject;
