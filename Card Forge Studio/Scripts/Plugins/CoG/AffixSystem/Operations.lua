--[[!
@fqxn CoG.AffixSystem.Internal.Operations
@desc Creates private component operations around entry services. Owns eligibility,
    callback lifecycle/recovery, naming and snapshot validation. LXC methods pass
    their private component-state table here; it is never exposed to callers.
@param table Entries Private entry services created for the native class.
@param class Rarity Native Rarity utility class.
@ret table Service Private operations used only by the LXC class.
!]]
return function(Entries, Rarity)
    local _eType = Entries.TYPE;
    local _tOwners, _tSystems = Entries.owners, Entries.systems;
    local _tTokenMeta, _tJournalMeta = Entries.TokenMeta, Entries.JournalMeta;
    local fEntry, fOwner, fDummy = Entries.entry, Entries.owner, Entries.dummy;
    local fDefinitionKey, fDenseLength = Entries.definitionKey, Entries.denseLength;
    local fRegisterOwnerClass = Entries.registerOwnerClass;

    --[[!
    @fqxn CoG.AffixSystem.Internal.Functions.errorText
    @desc Converts callback errors to text without letting a broken __tostring interrupt recovery.
    !]]
    local function fErrorText(vError)
        local bFormatted, sError = pcall(tostring, vError);
        return bFormatted and sError or "Unformattable callback error.";
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.find
        @pulsarlua function find
        @desc Finds an applied instance by identity, never by display text.
        @param table tRecords Application records.
        @param AffixSystemEntry oAffix Affix instance.
        @ret number|nil nIndex Matching record position, or nil.
        @ret table|nil tRecord Matching application record.
        @scope local
        @vis Private
    !]]
    local function fFind(tRecords, oAffix)

        for nIndex, tRecord in ipairs(tRecords) do
            if (rawequal(tRecord.affix, oAffix)) then
                return nIndex, tRecord;
            end
        end
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.count
        @pulsarlua function count
        @desc Counts one affix group, optionally excluding an outgoing instance.
        @param table tRecords Application records.
        @param AffixSystem.TYPE eType Prefix or suffix group; nil includes both when supported.
        @param AffixSystemEntry|nil oExcluded Outgoing instance excluded from duplicate/count checks.
        @ret number nCount Validated or matching entry count.
        @scope local
        @vis Private
    !]]
    local function fCount(tRecords, eType, oExcluded)
        local nCount = 0;
        for _, tRecord in ipairs(tRecords) do
            if (not rawequal(tRecord.affix, oExcluded) and (eType == nil or tRecord.affix.getType() == eType)) then
                nCount = nCount + 1;
            end
        end

        return nCount;
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.hooks
        @pulsarlua function hooks
        @desc Validates a complete enum-keyed hook map before registering any hook.
        @param eventrix kEvents Dispatcher checked for existing hooks.
        @param table|nil vHooks Enum-keyed hook functions or ordered function lists.
        @ret table tHooks Validated event/callback records.
        @scope local
        @vis Private
    !]]
    local function fHooks(kEvents, vHooks)
        local tHooks = {};
        if (vHooks == nil) then
            return tHooks;
        end

        type.assert.table(vHooks);

        for eEvent, vFunctions in pairs(vHooks) do
            assert(subtype(eEvent) == "enumitem", "Affix event keys must be enum members.");

            local tFunctions = rawtype(vFunctions) == "function" and {vFunctions} or vFunctions;
            local nCount = fDenseLength(tFunctions);
            local tSeen = {};
            for nIndex = 1, nCount do
                local fHook = tFunctions[nIndex];
                type.assert["function"](fHook);
                assert(not tSeen[fHook] and kEvents.getHookOrdinal(eEvent, fHook) == -1, "Affix hook is already registered.");
                tSeen[fHook] = true;
                tHooks[#tHooks + 1] = {event = eEvent, callback = fHook};
            end
        end

        return tHooks;
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.add
        @pulsarlua function add
        @desc Claims an instance before calling onAdd(affix, journal, ...), making its
        owner/system inspectable. On error attempts onRemove compensation. If undo
        also fails, retains the application and returns it for explicit recovery.
        @param AffixSystem oSystem System performing the application.
        @param table pri System private state.
        @param AffixSystemEntry oAffix Affix instance.
        @param function fAdd Captured add callback.
        @param function fRemove Captured removal callback.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret boolean bSuccess True when the lifecycle operation succeeds.
        @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
        @ret string|nil sReason Failure/recovery explanation; nil on success.
        @scope local
        @vis Private
    !]]
    local function fAdd(oSystem, pri, oAffix, fAdd, fRemove, ...)
        local tState = fEntry(oAffix);
        tState.token = pri.token;
        tState.journal = setmetatable({}, _tJournalMeta);

        local tRecord = {
            affix    = oAffix,
            hooks    = {},
            onAdd    = fAdd,
            onRemove = fRemove,
            arguments = table.pack(...)
        };
        pri.records[#pri.records + 1] = tRecord;
        pri.nameCache = {};

        local bAdded, vHooks = pcall(fAdd, oAffix, tState.journal, ...);
        if (bAdded) then
            bAdded, vHooks = pcall(fHooks, pri.events, vHooks);
        end

        if (bAdded) then
            tRecord.hooks = vHooks;

            for _, tHook in ipairs(vHooks) do
                pri.events.addHook(tHook.event, tHook.callback);
            end

            return true, oAffix, nil;
        end

        local bUndone, sUndoError = pcall(fRemove, oAffix, tState.journal, ...);
        if (not bUndone) then
            return false, oAffix, "Add failed: "..fErrorText(vHooks).."; undo failed: "..fErrorText(sUndoError);
        end

        table.remove(pri.records, #pri.records);
        tState.token = false;
        tState.journal = setmetatable({}, _tJournalMeta);

        return false, nil, "Add failed: "..fErrorText(vHooks);
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.remove
        @pulsarlua function remove
        @desc Calls captured onRemove while ownership/hooks remain available. Success
        unregisters only this entry's hooks and releases ownership; errors retain state.
        @param table pri System private state.
        @param number nIndex Application record index.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret boolean bSuccess True when the lifecycle operation succeeds.
        @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
        @ret string|nil sReason Failure/recovery explanation; nil on success.
        @scope local
        @vis Private
    !]]
    local function fRemove(pri, nIndex, ...)
        local tRecord = pri.records[nIndex];
        local tState = fEntry(tRecord.affix);
        local bRemoved, sError = pcall(tRecord.onRemove, tRecord.affix, tState.journal, ...);
        if (not bRemoved) then
            return false, nil, "Remove failed: "..fErrorText(sError);
        end

        for _, tHook in ipairs(tRecord.hooks) do
            pri.events.removeHook(tHook.event, tHook.callback);
        end

        table.remove(pri.records, nIndex);
        pri.nameCache = {};
        tState.token = false;
        tState.journal = setmetatable({}, _tJournalMeta);

        return true, tRecord.affix, nil;
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.each
        @pulsarlua function each
        @desc Iterates a copied list, preserving internal collection ownership.
        @param table tRecords Application records.
        @param AffixSystem.TYPE eType Prefix or suffix group; nil includes both when supported.
        @ret function fIterator Iterator function.
        @ret table tValues Copied values used as iterator state.
        @ret number nIndex Initial iterator index.
        @scope local
        @vis Private
    !]]
    local function fEach(tRecords, eType)
        local tEntries = {};
        for _, tRecord in ipairs(tRecords) do
            if (eType == nil or tRecord.affix.getType() == eType) then
                tEntries[#tEntries + 1] = tRecord.affix;
            end
        end

        return ipairs(tEntries);
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.selected
        @pulsarlua function selected
        @desc Selects one naming candidate by tier, priority, then stable definition ID.
        @param table tRecords Application records.
        @param AffixSystem.TYPE eType Prefix or suffix group; nil includes both when supported.
        @ret string|nil sText Selected group display text, or nil.
        @scope local
        @vis Private
    !]]
    local function fSelected(tRecords, eType)
        local oSelected;
        for _, tRecord in ipairs(tRecords) do
            local oAffix = tRecord.affix;
            if (oAffix.getType() == eType) then
                local bSelect = oSelected == nil;
                if (oSelected) then
                    local nTier, nOtherTier = oAffix.getTier().Ordinal, oSelected.getTier().Ordinal;
                    local nPriority, nOtherPriority = oAffix.getNamingPriority(), oSelected.getNamingPriority();
                    local bEarlierID = fDefinitionKey(oAffix.getDefinitionID()) < fDefinitionKey(oSelected.getDefinitionID());
                    bSelect = nTier > nOtherTier or (nTier == nOtherTier and (nPriority > nOtherPriority or
                              (nPriority == nOtherPriority and bEarlierID)));
                end

                if (bSelect) then
                    oSelected = oAffix;
                end
            end
        end

        return oSelected and oSelected.getName() or nil;
    end


    local Service = {methods = {}};

    --[[!
        @fqxn CoG.AffixSystem.Methods.AffixSystem
        @pulsarlua function AffixSystem
        @desc Creates an independent component with local dummy callbacks. Owner
        must be a CoGObject; nil creates a detached system. Defaults use owner rarity
        or the first configured rarity. The dispatcher uses the optional environment.
        @param CoGObject|nil oOwner External host, or nil to detach.
        @param CoG.LEVEL|nil eRarity Initial rarity; defaults to owner rarity or the first level.
        @param string|nil sEnvironment Registered environment name for the owned eventrix.
        @param boolean|nil bOwnerLocked True for an owned CoGObject component.
    !]]
    Service.create = function(this, oOwner, eRarity, sEnvironment, bOwnerLocked)
        local tPrivate = {
            token = null, records = {}, events = null, rarity = null,
            explicitName = "", busy = false, nameCache = {},
            callbacks = {onAdd = fDummy, onRemove = fDummy},
        };
        local pri = tPrivate;
        assert(oOwner == nil or class.isa(oOwner, "CoG.CoGObject"), "AffixSystem owner must be a CoGObject.");
        assert(bOwnerLocked == nil or rawtype(bOwnerLocked) == "boolean", "Invalid owner lock.");
        -- Ownership needs only a name; do not recover an out-of-scope class object.
        local sOwnerClass = oOwner and bOwnerLocked and class.getname(oOwner) or "";
        pri.token = setmetatable({ownerClass = sOwnerClass, locked = bOwnerLocked == true}, _tTokenMeta);
        pri.events = eventrix(sEnvironment);
        pri.rarity = eRarity or (oOwner and oOwner.getRarity()) or Rarity.MinLevel;
        assert(lxe.isMember(pri.rarity, CoG.LEVEL), "Invalid affix rarity.");
        Rarity.getName(pri.rarity); -- Require a configured ordinal before retaining this level.

        -- The host installs its component only after this constructor returns.
        _tOwners[pri.token] = setmetatable({oOwner}, {__mode = "v"});
        _tSystems[pri.token] = setmetatable({this}, {__mode = "v"});
        if (sOwnerClass ~= "") then
            fRegisterOwnerClass(sOwnerClass);
        end
        return tPrivate;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getOwner
        @pulsarlua function AffixSystem.getOwner
        @desc Returns the external CoGObject owner, or nil for a detached component.
        @ret CoGObject|nil oOwner Live external owner.
    !]]
    Service.methods.getOwner = function(this, tPrivate)
        return fOwner(tPrivate.token);
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.setOwner
        @pulsarlua function AffixSystem.setOwner
        @desc Reconnects a detached/restored system after validating every entry.
        An owned component accepts only its exact owning CoGObject. An unlocked
        standalone system may transfer only after all effects have been removed.
        Returns this, success, owner or nil, reason.
        @param CoGObject|nil oOwner External host, or nil to detach.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the change is accepted.
        @ret CoGObject|nil oOwner Accepted external owner.
        @ret string|nil sReason Rejection reason; nil on success.
    !]]
    Service.methods.setOwner = function(this, tPrivate, oOwner)
        assert(oOwner == nil or class.isa(oOwner, "CoG.CoGObject"), "AffixSystem owner must be a CoGObject.");

        local pri = tPrivate;
        if (pri.busy) then
            return this, false, nil, "Affix operation is in progress.";
        end

        local oCurrent = fOwner(pri.token);
        if (pri.token.locked and (oOwner == nil or not oOwner.ownsAffixSystem(this) or
            (oCurrent and not rawequal(oCurrent, oOwner)))) then

            return this, false, nil, "Owned components cannot be detached or rebound.";
        end

        if (#pri.records > 0 and oCurrent and not rawequal(oCurrent, oOwner)) then
            return this, false, nil, "Remove applied affixes before changing owners.";
        end

        if (oOwner) then
            local eRarity = oOwner.getRarity();
            if (fCount(pri.records, _eType.PREFIX) > Rarity.getMaxPrefixCount(eRarity) or
                fCount(pri.records, _eType.SUFFIX) > Rarity.getMaxSuffixCount(eRarity)) then

                return this, false, nil, "Owner rarity cannot accommodate applied affixes.";
            end

            for _, tRecord in ipairs(pri.records) do
                if (not tRecord.affix.isCompatibleWithClass(class.getname(oOwner)) or
                    tRecord.affix.getTier().Ordinal > Rarity.getMaxAffixTier(eRarity).Ordinal) then

                    return this, false, nil, "Owner cannot accommodate an applied affix.";
                end
            end
        end

        _tOwners[pri.token] = setmetatable({oOwner}, {__mode = "v"});
        _tSystems[pri.token] = setmetatable({this}, {__mode = "v"});

        -- Lock a component when its actual host reconnects it.
        -- Standalone systems retain their transferable ownership.
        if (oOwner and oOwner.ownsAffixSystem(this)) then
            pri.token.locked = true;
            pri.token.ownerClass = class.getname(oOwner);
            fRegisterOwnerClass(pri.token.ownerClass);
        end

        return this, true, oOwner, nil;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getOnAddCallback
        @pulsarlua function AffixSystem.getOnAddCallback
        @desc Returns the callback used for future applications.
        @ret function fCallback Add callback used for future applications.
    !]]
    Service.methods.getOnAddCallback = function(this, tPrivate)
        return tPrivate.callbacks.onAdd;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.setOnAddCallback
        @pulsarlua function AffixSystem.setOnAddCallback
        @desc Sets onAdd(affix, journal, ...); nil resets the file-local dummy.
        Return nil or enum-keyed hook lists. Throw an error to signal failure.
        @param function|nil fCallback Replacement callback, or nil to restore dummy.
        @ret AffixSystem this This system.
    !]]
    Service.methods.setOnAddCallback = function(this, tPrivate, fCallback)
        if (fCallback ~= nil) then
            type.assert["function"](fCallback);
        end

        tPrivate.callbacks.onAdd = fCallback or fDummy;

        return this;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getOnRemoveCallback
        @pulsarlua function AffixSystem.getOnRemoveCallback
        @desc Returns the undo callback captured by future applications.
        @ret function fCallback Removal callback captured by future applications.
    !]]
    Service.methods.getOnRemoveCallback = function(this, tPrivate)
        return tPrivate.callbacks.onRemove;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.setOnRemoveCallback
        @pulsarlua function AffixSystem.setOnRemoveCallback
        @desc Sets onRemove(affix, journal, ...); nil resets dummy. Existing entries
        retain their original callback pair. Callback return values are ignored.
        @param function|nil fCallback Replacement callback, or nil to restore dummy.
        @ret AffixSystem this This system.
    !]]
    Service.methods.setOnRemoveCallback = function(this, tPrivate, fCallback)
        if (fCallback ~= nil) then
            type.assert["function"](fCallback);
        end

        tPrivate.callbacks.onRemove = fCallback or fDummy;

        return this;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getRarity
        @pulsarlua function AffixSystem.getRarity
        @desc Uses live owner rarity, or saved/configured rarity while detached.
        @ret CoG.LEVEL eRarity Live owner rarity or detached fallback.
    !]]
    Service.methods.getRarity = function(this, tPrivate)
        local oOwner = this.getOwner();

        return oOwner and oOwner.getRarity() or tPrivate.rarity;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.canSetRarity
        @pulsarlua function AffixSystem.canSetRarity
        @desc Checks maximum tier and independent prefix/suffix limits. Minimum
        generation tiers/counts do not prohibit incremental application or removal.
        @param CoG.LEVEL eRarity Proposed or initial rarity member.
        @ret boolean bAllowed True when the operation is eligible.
        @ret string|nil sReason Rejection reason; nil when eligible.
    !]]
    Service.methods.canSetRarity = function(this, tPrivate, eRarity)
        assert(lxe.isMember(eRarity, CoG.LEVEL), "Expected a configured rarity member.");
        Rarity.getName(eRarity); -- Bounds checking belongs to the rarity query service.

        local pri = tPrivate;
        if (pri.busy) then
            return false, "Affix operation is in progress.";
        end

        if (this.getPrefixCount() > Rarity.getMaxPrefixCount(eRarity) or this.getSuffixCount() > Rarity.getMaxSuffixCount(eRarity)) then
            return false, "Applied affix count exceeds the proposed rarity limit.";
        end

        for _, tRecord in ipairs(pri.records) do
            if (tRecord.affix.getTier().Ordinal > Rarity.getMaxAffixTier(eRarity).Ordinal) then
                return false, "Applied affix tier exceeds the proposed rarity limit.";
            end
        end

        return true, nil;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.setRarity
        @pulsarlua function AffixSystem.setRarity
        @desc Validates limits and delegates an attached change to the owner.
        Returns this, success, rarity or nil, reason. Rejection changes no state.
        @param CoG.LEVEL eRarity Proposed or initial rarity member.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the change is accepted.
        @ret CoG.LEVEL|nil eRarity Accepted rarity; nil on rejection.
        @ret string|nil sReason Rejection reason; nil on success.
    !]]
    Service.methods.setRarity = function(this, tPrivate, eRarity)
        local bAllowed, sReason = this.canSetRarity(eRarity);
        if (not bAllowed) then
            return this, false, nil, sReason;
        end

        local oOwner = this.getOwner();
        if (oOwner) then
            local _, bChanged, _, sError = oOwner.setRarity(eRarity);
            if (bChanged == false) then
                return this, false, nil, sError;
            end
        end

        tPrivate.rarity = eRarity;

        return this, true, eRarity, nil;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.canApplyAffix
        @pulsarlua function AffixSystem.canApplyAffix
        @desc Checks ownership, duplicate ID, compatibility, tier and group capacity.
        Optional outgoing instance is used internally by replacement checks.
        @param AffixSystemEntry oAffix Affix instance.
        @param AffixSystemEntry|nil oExcluded Outgoing instance excluded from duplicate/count checks.
        @ret boolean bAllowed True when the operation is eligible.
        @ret string|nil sReason Rejection reason; nil when eligible.
    !]]
    Service.methods.canApplyAffix = function(this, tPrivate, oAffix, oExcluded)
        fEntry(oAffix);

        local pri = tPrivate;
        if (pri.busy) then
            return false, "Affix operation is in progress.";
        end

        if (oAffix.isApplied()) then
            return false, "Affix already belongs to a system.";
        end

        local oOwner = this.getOwner();
        if (not oOwner) then
            return false, "AffixSystem has no owner.";
        end

        if (not oAffix.isCompatibleWithClass(class.getname(oOwner))) then
            return false, "Affix is incompatible with its owner.";
        end

        for _, tRecord in ipairs(pri.records) do
            if (not rawequal(tRecord.affix, oExcluded) and fDefinitionKey(tRecord.affix.getDefinitionID()) == fDefinitionKey(oAffix.getDefinitionID())) then
                return false, "Affix definition is already applied.";
            end
        end

        local eRarity = this.getRarity();
        if (oAffix.getTier().Ordinal > Rarity.getMaxAffixTier(eRarity).Ordinal) then
            return false, "Affix tier exceeds rarity limit.";
        end

        local nLimit = oAffix.isPrefix() and Rarity.getMaxPrefixCount(eRarity) or Rarity.getMaxSuffixCount(eRarity);
        if (fCount(pri.records, oAffix.getType(), oExcluded) >= nLimit) then
            return false, "Affix count exceeds rarity limit.";
        end

        return true, nil;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.canReplaceAffix
        @pulsarlua function AffixSystem.canReplaceAffix
        @desc Checks replacement eligibility with the outgoing definition/count excluded.
        @param AffixSystemEntry oOld Applied instance to replace.
        @param AffixSystemEntry oNew Detached replacement instance.
        @ret boolean bAllowed True when the operation is eligible.
        @ret string|nil sReason Rejection reason; nil when eligible.
    !]]
    Service.methods.canReplaceAffix = function(this, tPrivate, oOld, oNew)
        fEntry(oOld);
        fEntry(oNew);

        if (not fFind(tPrivate.records, oOld)) then
            return false, "Outgoing affix is not applied.";
        end

        return this.canApplyAffix(oNew, oOld);
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.applyAffix
        @pulsarlua function AffixSystem.applyAffix
        @desc Returns this, success, affix or nil, reason. Eligibility rejection
        leaves state unchanged. A failed compensation returns the retained affix.
        @param AffixSystemEntry oAffix Affix instance.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the operation succeeds.
        @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
        @ret string|nil sReason Failure/recovery explanation; nil on success.
    !]]
    Service.methods.applyAffix = function(this, tPrivate, oAffix, ...)
        local bAllowed, sReason = this.canApplyAffix(oAffix);
        if (not bAllowed) then
            return this, false, nil, sReason;
        end

        local pri = tPrivate;
        pri.busy = true;

        local bAdded, oResult, sError = fAdd(this, pri, oAffix, pri.callbacks.onAdd, pri.callbacks.onRemove, ...);
        pri.busy = false;

        return this, bAdded, oResult, sError;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.removeAffix
        @pulsarlua function AffixSystem.removeAffix
        @desc Returns this, success, removed affix or nil, reason. Absent entries
        never invoke callbacks. A throwing undo preserves ownership, journal and hooks.
        @param AffixSystemEntry oAffix Affix instance.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the operation succeeds.
        @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
        @ret string|nil sReason Failure/recovery explanation; nil on success.
    !]]
    Service.methods.removeAffix = function(this, tPrivate, oAffix, ...)
        fEntry(oAffix);

        local pri = tPrivate;
        if (pri.busy) then
            return this, false, nil, "Affix operation is in progress.";
        end

        local nIndex = fFind(pri.records, oAffix);
        if (not nIndex) then
            return this, false, nil, "Affix is not applied.";
        end

        pri.busy = true;

        local bRemoved, oResult, sError = fRemove(pri, nIndex, ...);
        pri.busy = false;

        return this, bRemoved, oResult, sError;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.replaceAffix
        @pulsarlua function AffixSystem.replaceAffix
        @desc Preflights, removes, then applies. A failed new add with successful
        compensation attempts the original callback pair using its original arguments.
        Recovery is reapplication, not exact rollback of arbitrary effects or journal
        history. A retained failed replacement leaves the original detached.
        @param AffixSystemEntry oOld Applied instance to replace.
        @param AffixSystemEntry oNew Detached replacement instance.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret AffixSystem this This system.
        @ret boolean bSuccess True when the operation succeeds.
        @ret AffixSystemEntry|nil oResult Affected or retained recovery affix.
        @ret string|nil sReason Failure/recovery explanation; nil on success.
    !]]
    Service.methods.replaceAffix = function(this, tPrivate, oOld, oNew, ...)
        local bAllowed, sReason = this.canReplaceAffix(oOld, oNew);
        if (not bAllowed) then
            return this, false, nil, sReason;
        end

        local pri = tPrivate;
        local nIndex, tOld = fFind(pri.records, oOld);
        pri.busy = true;

        local bRemoved, _, sError = fRemove(pri, nIndex, ...);
        if (not bRemoved) then
            pri.busy = false;

            return this, false, nil, sError;
        end

        local bAdded, oResult, sAddError = fAdd(this, pri, oNew, pri.callbacks.onAdd, pri.callbacks.onRemove, ...);
        if (not bAdded and oResult == nil) then
            local tArguments = tOld.arguments;
            local bRecovered, oRecovery, sRecovery = fAdd(this, pri, oOld, tOld.onAdd, tOld.onRemove,
                                                        table.unpack(tArguments, 1, tArguments.n));
            oResult = bRecovered and oOld or oRecovery;
            sAddError = sAddError..(bRecovered and "; original reapplied." or "; recovery failed: "..fErrorText(sRecovery));
        end

        pri.busy = false;

        return this, bAdded, oResult, sAddError;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.hasAffix
        @pulsarlua function AffixSystem.hasAffix
        @desc Tests instance identity without exposing application records.
        @param AffixSystemEntry oAffix Affix instance.
        @ret boolean bResult True when the documented condition holds.
    !]]
    Service.methods.hasAffix = function(this, tPrivate, oAffix)
        return fFind(tPrivate.records, oAffix) ~= nil;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getAffixByDefinitionID
        @pulsarlua function AffixSystem.getAffixByDefinitionID
        @desc Returns the unique applied definition instance, ignoring ID case, or nil.
        @param string sID Stable definition identity to find.
        @ret AffixSystemEntry|nil oAffix Matching applied definition, or nil.
    !]]
    Service.methods.getAffixByDefinitionID = function(this, tPrivate, sID)
        local sKey = fDefinitionKey(sID);

        for _, tRecord in ipairs(tPrivate.records) do
            if (fDefinitionKey(tRecord.affix.getDefinitionID()) == sKey) then
                return tRecord.affix;
            end
        end
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.eachAffix
        @pulsarlua function AffixSystem.eachAffix
        @desc Iterates index/affix pairs from a copied application-order list.
        @ret function fIterator Iterator function.
        @ret table tValues Copied values used as iterator state.
        @ret number nIndex Initial iterator index.
    !]]
    Service.methods.eachAffix = function(this, tPrivate)
        return fEach(tPrivate.records);
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.eachPrefix
        @pulsarlua function AffixSystem.eachPrefix
        @desc Iterates index/affix pairs for applied prefixes from a copy.
        @ret function fIterator Iterator function.
        @ret table tValues Copied values used as iterator state.
        @ret number nIndex Initial iterator index.
    !]]
    Service.methods.eachPrefix = function(this, tPrivate)
        return fEach(tPrivate.records, _eType.PREFIX);
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.eachSuffix
        @pulsarlua function AffixSystem.eachSuffix
        @desc Iterates index/affix pairs for applied suffixes from a copy.
        @ret function fIterator Iterator function.
        @ret table tValues Copied values used as iterator state.
        @ret number nIndex Initial iterator index.
    !]]
    Service.methods.eachSuffix = function(this, tPrivate)
        return fEach(tPrivate.records, _eType.SUFFIX);
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getAffixCount
        @pulsarlua function AffixSystem.getAffixCount
        @desc Returns the total number of applied affixes.
        @ret number nCount Applied affix count.
    !]]
    Service.methods.getAffixCount = function(this, tPrivate)
        return #tPrivate.records;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getPrefixCount
        @pulsarlua function AffixSystem.getPrefixCount
        @desc Returns the applied prefix count.
        @ret number nCount Applied prefix count.
    !]]
    Service.methods.getPrefixCount = function(this, tPrivate)
        return fCount(tPrivate.records, _eType.PREFIX);
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getSuffixCount
        @pulsarlua function AffixSystem.getSuffixCount
        @desc Returns the applied suffix count.
        @ret number nCount Applied suffix count.
    !]]
    Service.methods.getSuffixCount = function(this, tPrivate)
        return fCount(tPrivate.records, _eType.SUFFIX);
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getMaxPrefixes
        @pulsarlua function AffixSystem.getMaxPrefixes
        @desc Returns the current rarity's maximum prefix count.
        @ret number nMaximum Current rarity prefix limit.
    !]]
    Service.methods.getMaxPrefixes = function(this, tPrivate)
        return Rarity.getMaxPrefixCount(this.getRarity());
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getMaxSuffixes
        @pulsarlua function AffixSystem.getMaxSuffixes
        @desc Returns the current rarity's maximum suffix count.
        @ret number nMaximum Current rarity suffix limit.
    !]]
    Service.methods.getMaxSuffixes = function(this, tPrivate)
        return Rarity.getMaxSuffixCount(this.getRarity());
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getName
        @pulsarlua function AffixSystem.getName
        @desc Composes selected prefix/base/suffix without changing host metadata.
        All affixes retain effects regardless of which text wins naming selection.
        An optional base name supports detached systems; otherwise uses owner name.
        @param string|nil sBaseName Base name; omission uses the live owner name.
        @ret string sName Display name.
    !]]
    Service.methods.getName = function(this, tPrivate, sBaseName)
        local pri = tPrivate;
        if (this.getRarity() == CoG.LEVEL.SIX and pri.explicitName ~= "") then
            return pri.explicitName;
        end

        if (sBaseName == nil) then
            local oOwner = this.getOwner();
            assert(oOwner, "Detached naming requires a base name.");
            sBaseName = oOwner.getName();
        end

        type.assert.string(sBaseName, "%S+");
        local tCache = pri.nameCache;
        if (tCache.base == sBaseName) then
            return tCache.name;
        end

        local tParts = {};
        local sPrefix, sSuffix = fSelected(pri.records, _eType.PREFIX), fSelected(pri.records, _eType.SUFFIX);
        if (sPrefix) then
            tParts[#tParts + 1] = sPrefix;
        end

        tParts[#tParts + 1] = sBaseName;

        if (sSuffix) then
            tParts[#tParts + 1] = sSuffix;
        end

        local sName = table.concat(tParts, " ");
        pri.nameCache = {base = sBaseName, name = sName};
        return sName;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getExplicitName
        @pulsarlua function AffixSystem.getExplicitName
        @desc Returns the stored SINGULAR override, or nil when unset.
        @ret string|nil sName Stored SINGULAR override, or nil.
    !]]
    Service.methods.getExplicitName = function(this, tPrivate)
        return tPrivate.explicitName ~= "" and tPrivate.explicitName or nil;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.setExplicitName
        @pulsarlua function AffixSystem.setExplicitName
        @desc Stores a nonblank SINGULAR display override; nil clears it.
        @param string|nil sName Nonblank display text; nil clears an optional override.
        @ret AffixSystem this This system.
    !]]
    Service.methods.setExplicitName = function(this, tPrivate, sName)
        if (sName ~= nil) then
            type.assert.string(sName, "%S+");
        end

        tPrivate.explicitName = sName or "";
        tPrivate.nameCache = {};

        return this;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.fireEvent
        @pulsarlua function AffixSystem.fireEvent
        @desc Fires the component's affix hooks. Hosts choose which gameplay events
        to forward; no event forwarding behavior is imposed on CoGObject.
        @param enumitem eEvent Event identifier.
        @param varargs ... Developer-defined arguments forwarded to lifecycle callbacks or event hooks.
        @ret table tResults Ordered eventrix hook results and errors.
    !]]
    Service.methods.fireEvent = function(this, tPrivate, eEvent, ...)
        return tPrivate.events.fire(eEvent, ...);
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.prepareSnapshot
        @pulsarlua function AffixSystem.prepareSnapshot
        @desc Rejects in-progress saves and captures current host rarity. External
        owners are intentionally absent from tokens, preventing inverse object cycles.
        @param table tState Definition, application or serializer state.
        @vis Private
    !]]
    Service.prepareSnapshot = function(this, tState)
        assert(not tState.busy, "Cannot save during an affix operation.");
        tState.nameCache = {};

        local oOwner = fOwner(tState.token);
        if (oOwner) then
            tState.rarity = oOwner.getRarity();
        end
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.validateSnapshot
        @pulsarlua function AffixSystem.validateSnapshot
        @desc Validates application identities, ownership, hooks, counts and tiers
        without running gameplay callbacks or changing loaded objects.
        @param table tState Definition, application or serializer state.
        @vis Private
    !]]
    Service.validateSnapshot = function(this, tState)
        local pri = tState;
        assert(type(pri.token) == "AffixSystemToken" and type(pri.events) == "eventrix", "Invalid affix component.");
        assert(pri.busy == false and lxe.isMember(pri.rarity, CoG.LEVEL), "Invalid saved affix limits.");
        type.assert.string(pri.explicitName);
        type.assert.table(pri.callbacks);
        type.assert["function"](pri.callbacks.onAdd);
        type.assert["function"](pri.callbacks.onRemove);

        local tIDs, tHooks = {}, {};
        for nIndex = 1, fDenseLength(pri.records) do
            local tRecord = pri.records[nIndex];
            type.assert.table(tRecord);

            local tEntry = fEntry(tRecord.affix);
            assert(rawequal(tEntry.token, pri.token), "Saved affix ownership mismatch.");
            local sKey = fDefinitionKey(tEntry.id);
            assert(not tIDs[sKey], "Duplicate saved affix definition.");
            tIDs[sKey] = true;
            assert(tEntry.tier.Ordinal <= Rarity.getMaxAffixTier(pri.rarity).Ordinal, "Saved affix exceeds rarity tier.");
            type.assert["function"](tRecord.onAdd);
            type.assert["function"](tRecord.onRemove);
            type.assert.table(tRecord.arguments);
            local nArguments = tRecord.arguments.n;
            assert(rawtype(nArguments) == "number" and nArguments >= 0 and nArguments % 1 == 0,
                   "Invalid saved affix arguments.");
            for nArgument in pairs(tRecord.arguments) do
                assert(nArgument == "n" or (rawtype(nArgument) == "number" and nArgument >= 1 and
                       nArgument <= nArguments and nArgument % 1 == 0), "Invalid saved affix argument index.");
            end

            for nHook = 1, fDenseLength(tRecord.hooks) do
                local tHook = tRecord.hooks[nHook];
                assert(pri.events.getHookOrdinal(tHook.event, tHook.callback) > 0, "Saved affix hook is missing.");
                tHooks[tHook.event] = tHooks[tHook.event] or {};
                assert(not tHooks[tHook.event][tHook.callback], "Saved hook has multiple owners.");
                tHooks[tHook.event][tHook.callback] = true;
            end
        end

        assert(fCount(pri.records, _eType.PREFIX) <= Rarity.getMaxPrefixCount(pri.rarity), "Too many saved prefixes.");
        assert(fCount(pri.records, _eType.SUFFIX) <= Rarity.getMaxSuffixCount(pri.rarity), "Too many saved suffixes.");
        _tSystems[pri.token] = setmetatable({this}, {__mode = "v"});
    end;

    return Service;
end;

