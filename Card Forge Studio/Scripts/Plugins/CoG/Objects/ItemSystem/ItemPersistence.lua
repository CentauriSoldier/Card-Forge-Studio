--[[!
    @fqxn CoG.ItemSystem.ItemPersistence
    @desc Internal runtime identity bookkeeping. Native graph persistence handles shared registries, callbacks and references. Owners remain external.
!]]
-- Native persistence does not register legacy serializer factories.
local M = {};

-- These weak indexes do not keep otherwise unreachable objects or load tokens alive.
-- IDs identify saved inventory members; contexts keep separate loads from sharing members.
local tIDs = setmetatable({}, {__mode = "k"});
local tContexts = setmetatable({}, {__mode = "k"});
local nNextID = 0;

--[[!
    @fqxn CoG.ItemSystem.ItemPersistence.identify
    @desc Assigns an inventory-local identity for registry references in snapshots.
!]]
function M.identify(oObject)

    -- Repeated references reuse the same ID instead of creating multiple saved identities.
    if (not tIDs[oObject]) then
        nNextID = nNextID + 1;
        tIDs[oObject] = nNextID;
    end

    return tIDs[oObject];
end

-- Optional caller-supplied tokens isolate explicit reconnection sessions.
-- Registries can load before their referenced containers, so each token owns a waiting list.
local function context(tToken)

    if (not tContexts[tToken]) then
        tContexts[tToken] = {objects = {}, pending = {}};
    end

    return tContexts[tToken];
end

--[[!
    @fqxn CoG.ItemSystem.ItemPersistence.reconnect
    @desc Resolves registry entries against objects from this load operation only.
!]]
function M.reconnect(nID, oObject, tToken)
    type.assert.number(nID);
    local tContext = context(tToken);

    -- Reconnection can be reached through an explicit token or a containing inventory.
    for _, oExisting in pairs(tContext.objects) do
        if (rawequal(oExisting, oObject)) then
            return;
        end
    end

    -- A different object cannot claim an ID that this load operation already resolved.
    assert(not tContext.objects[nID], "Duplicate saved inventory identity.");
    tContext.objects[nID] = oObject;

    -- Complete registry entries deferred while this object had not yet been constructed.
    for _, oRegistry in ipairs(tContext.pending[nID] or {}) do
        oRegistry.add(oObject);
    end

    tContext.pending[nID] = nil;
    M.identify(oObject);
end

--[[!
    @fqxn CoG.ItemSystem.ItemPersistence.registry
    @desc Native registries serialize their callbacks and graph references directly.
        Retaining the object preserves shared registry identity.
!]]
function M.registry(oRegistry)
    return oRegistry;
end

return M;
