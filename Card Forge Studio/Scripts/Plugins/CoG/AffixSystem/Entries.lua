--[[!
@fqxn CoG.AffixSystem.Internal.Entries
@desc Creates private affix definitions, entries, journals and ownership-token
    services. Each factory call owns independent weak maps; requiring this module
    never exposes the service held by the LXC class. Only the class retains it.
@param class CoGBase Initialized native base class.
@param class Rarity Initialized native Rarity class.
@param class cSystem Native AffixSystem class used for chaining.
@ret table Service Private entry/definition services for the component runtime.
!]]
return function(CoGBase, Rarity, cSystem)
    local _eTier           = CoGBase.config.TIER;
    local _eMaxTier        = CoGBase.config.Rarity.Affix.maxTier;
    local _eType           = cSystem.TYPE;
    local _mSerializer     = require("LuaEx.lib.serializer");
    local _tEntries        = setmetatable({}, {__mode = "k"});
    local _tOwners         = setmetatable({}, {__mode = "k"});
    local _tSystems        = setmetatable({}, {__mode = "k"});
    local _tMethods        = setmetatable({}, {__mode = "k"});
    local _tDefinitions    = {};
    local _cSystem         = cSystem;
    local _tEntryMeta;
    local _tJournalMeta;
    local _tTokenMeta;

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.dummy
        @pulsarlua function dummy
        @desc Shared no-op used to initialize callbacks and reset them when a setter receives nil.
        @scope local
        @vis Private
    !]]
    local function fDummy()
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.errorText
        @pulsarlua function errorText
        @desc Formats arbitrary callback errors without allowing a failing __tostring
        metamethod to interrupt compensation or leave a lifecycle operation locked.
        @param any vError Callback error value.
        @ret string sError Safe error description.
        @scope local
        @vis Private
    !]]
    local function fErrorText(vError)
        local bFormatted, sError = pcall(tostring, vError);
        return bFormatted and sError or "Unformattable callback error.";
    end

    --[[!
    @fqxn CoG.AffixSystem.Internal.Functions.registerOwnerClass
    @desc Validates a saved owner class against the native CoGObject hierarchy.
        LXC owns class persistence; no legacy class serializer factory is installed.
    @param string sName Qualified owner class name.
    !]]
    local function fRegisterOwnerClass(sName)
        local cOwner = class.getbyname(sName);
        local cBase = class.getbyname("CoG.CoGObject");
        assert(cOwner and cBase and (rawequal(cOwner, cBase) or class.ischild(cOwner, cBase)),
            "Unknown affix owner class.");
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.denseLength
        @pulsarlua function denseLength
        @desc Validates a dense list without accepting holes or nonnumeric keys.
        @param table tList Candidate dense list.
        @ret number nCount Validated or matching entry count.
        @scope local
        @vis Private
    !]]
    local function fDenseLength(tList)
        type.assert.table(tList);

        local nCount = 0;
        for nIndex in pairs(tList) do
            assert(rawtype(nIndex) == "number" and nIndex > 0 and nIndex % 1 == 0, "Expected a dense list.");
            nCount = nCount + 1;
        end

        for nIndex = 1, nCount do
            assert(tList[nIndex] ~= nil, "List contains a hole.");
        end

        return nCount;
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.entry
        @pulsarlua function entry
        @desc Gets private affix state or rejects an unrelated object.
        @param AffixSystemEntry oAffix Affix instance.
        @ret table tState Private affix state.
        @scope local
        @vis Private
    !]]
    local function fEntry(oAffix)
        local tState = _tEntries[oAffix];
        assert(tState, "Expected an affix created by AffixSystem.createAffix.");

        return tState;
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.definitionKey
        @pulsarlua function definitionKey
        @desc Validates an opaque ID and folds case with Lua's string.lower. No tier,
        namespace or gameplay meaning is inferred; spaces and punctuation are retained.
        @param string sID Identifier containing non-whitespace text.
        @ret string sKey Case-insensitive registry/application lookup key.
    !]]
    local function fDefinitionKey(sID)
        type.assert.string(sID, "%S+");
        return sID:lower();
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.copyValues
        @pulsarlua function copyValues
        @desc Copies generic plain Lua data without interpreting its keys or values.
        Preserves aliases/cycles; rejects functions, typed objects and metatables so
        mutable application objects cannot become shared definition state.
        @param any vValue Plain table or primitive data.
        @param table|nil tCopies Internal source-to-copy map.
        @ret any vCopy Independent data graph.
    !]]
    local function fCopyValues(vValue, tCopies)
        local sType = rawtype(vValue);
        if (sType ~= "table") then
            assert(sType == "nil" or sType == "boolean" or sType == "number" or sType == "string", "Affix values must be plain Lua data.");
            return vValue;
        end
        assert(getmetatable(vValue) == nil, "Affix values cannot have a metatable.");

        tCopies = tCopies or {};
        if (not tCopies[vValue]) then
            local tCopy = {};
            tCopies[vValue] = tCopy;
            for k, v in pairs(vValue) do
                local sKeyType = rawtype(k);
                assert(sKeyType == "string" or sKeyType == "number" or sKeyType == "boolean", "Affix value keys must be strings, numbers or booleans.");
                tCopy[k] = fCopyValues(v, tCopies);
            end
        end
        return tCopies[vValue];
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.owner
        @pulsarlua function owner
        @desc Resolves an external host without introducing a saved object cycle.
        @param AffixSystemToken tToken External ownership token.
        @ret CoGObject|nil oOwner Live external host.
        @scope local
        @vis Private
    !]]
    local function fOwner(tToken)
        local tReference = _tOwners[tToken];
        return tReference and tReference[1] or nil;
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.validateEntry
        @pulsarlua function validateEntry
        @desc Checks fixed metadata and saved application state. Configured tiers must retain their canonical LXE identity after loading.
        @param table tState Definition, application or serializer state.
        @param boolean bRestoring Whether saved private tiers may be rebound to configuration.
        @scope local
        @vis Private
    !]]
    local function fValidateEntry(tState, bRestoring)
        type.assert.table(tState);
        assert(lxe.isMember(tState.kind, _eType), "Invalid affix type.");

        -- LXE restores canonical identities. Foreign/lookalike tiers are rejected.
        assert(lxe.isMember(tState.tier, _eTier) and
            tState.tier.Ordinal <= _eMaxTier.Ordinal, "Invalid affix tier.");
        type.assert.string(tState.id, "%S+");
        type.assert.string(tState.name, "%S+");
        assert(tState.name == tState.name:match("^%s*(.-)%s*$"), "Affix text has surrounding whitespace.");
        type.assert.string(tState.description, "%S+");
        assert(rawtype(tState.priority) == "number" and tState.priority == tState.priority and
               math.abs(tState.priority) < math.huge, "Naming priority must be finite.");
        assert(fDenseLength(tState.classes) > 0, "Affix requires a compatible class.");

        for _, cClass in ipairs(tState.classes) do
            assert(class.is(cClass), "Invalid compatible class.");
        end

        assert(tState.token == false or type(tState.token) == "AffixSystemToken", "Invalid affix ownership.");
        assert(type(tState.journal) == "AffixSystemJournal", "Invalid affix journal.");
        type.assert.table(tState.values);
        fCopyValues(tState.values);
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.prepareDefinition
        @pulsarlua function prepareDefinition
        @desc Validates/copies an entire pattern before registry mutation. Tier keys
        must be actual configured enum members and each payload is developer data.
        @param string sID Opaque definition ID; registered spelling is preserved.
        @param table tPattern Type, name, classes, tiers and optional priority/description.
        @ret table tDefinition Private validated definition.
    !]]
    local function fPrepareDefinition(sID, tPattern)
        fDefinitionKey(sID);
        type.assert.table(tPattern);
        local tAllowed = {type = true, name = true, classes = true, tiers = true, priority = true, description = true};
        for sField in pairs(tPattern) do
            assert(tAllowed[sField], "Unknown affix definition field: "..tostring(sField));
        end

        local tClasses = {};
        for nIndex = 1, fDenseLength(tPattern.classes) do
            tClasses[nIndex] = tPattern.classes[nIndex];
        end
        type.assert.table(tPattern.tiers);
        local tDefinition = {
            kind        = tPattern.type,
            name        = tPattern.name,
            classes     = tClasses,
            id          = sID,
            priority    = tPattern.priority == nil and 0 or tPattern.priority,
            description = tPattern.description == nil and tPattern.name or tPattern.description,
            tiers       = {},
        };
        local nCount = 0;
        local tValueCopies = {};
        for eTier, tValues in pairs(tPattern.tiers) do
            assert(lxe.isMember(eTier, _eTier) and eTier.Ordinal <= _eMaxTier.Ordinal, "Definition tier must be a supported configured tier enum member.");
            type.assert.table(tValues);
            local tCopy = fCopyValues(tValues, tValueCopies);
            fValidateEntry({
                kind        = tDefinition.kind,
                name        = tDefinition.name,
                classes     = tClasses,
                id          = sID,
                priority    = tDefinition.priority,
                description = tDefinition.description,
                tier        = eTier,
                values      = tCopy,
                token       = false,
                journal     = setmetatable({}, _tJournalMeta),
            }, false);
            tDefinition.tiers[eTier] = tCopy;
            nCount = nCount + 1;
        end
        assert(nCount > 0, "Affix definition requires at least one tier.");
        return tDefinition;
    end

    --[[!
        @fqxn CoG.AffixSystem.Internal.Functions.newEntry
        @pulsarlua function newEntry
        @desc Builds a read-only affix object around private metadata/application state.
        Its journal is deliberately mutable; metadata and ownership have no setters.
        @param table tState Definition, application or serializer state.
        @ret AffixSystemEntry oAffix Independent read-only affix object.
        @scope local
        @vis Private
    !]]
    local function fNewEntry(tState)
        local oAffix = {};
        _tEntries[oAffix] = tState;
        _tMethods[oAffix] = {};

        return setmetatable(oAffix, _tEntryMeta);
    end

    local _tEntryMethods = {
        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getDefinitionID
            @pulsarlua function AffixSystemEntry.getDefinitionID
            @desc Returns the stable identity shared by instances of this affix definition.
            @ret string sDefinitionID Stable definition identity.
        !]]
        getDefinitionID = function(oAffix)
            return fEntry(oAffix).id;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getName
            @pulsarlua function AffixSystemEntry.getName
            @desc Returns this affix's display text without composing the owner's name.
            @ret string sName Display name.
        !]]
        getName = function(oAffix)
            return fEntry(oAffix).name;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getDescription
            @pulsarlua function AffixSystemEntry.getDescription
            @desc Returns this affix's immutable description.
            @ret string sDescription Affix description.
        !]]
        getDescription = function(oAffix)
            return fEntry(oAffix).description;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getType
            @pulsarlua function AffixSystemEntry.getType
            @desc Returns the immutable prefix/suffix classification.
            @ret AffixSystem.TYPE eType Prefix or suffix member.
        !]]
        getType = function(oAffix)
            return fEntry(oAffix).kind;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getTier
            @pulsarlua function AffixSystemEntry.getTier
            @desc Returns the immutable configured tier member.
            @ret TIER eTier Configured affix tier.
        !]]
        getTier = function(oAffix)
            return fEntry(oAffix).tier;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getValues
            @pulsarlua function AffixSystemEntry.getValues
            @desc Returns an independent copy of this entry's selected tier payload.
            The host interprets its meaning. Edits cannot alter this entry or registry.
            @ret table tValues Generic selected-tier data with aliases/cycles preserved.
        !]]
        getValues = function(oAffix)
            return fCopyValues(fEntry(oAffix).values);
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getNamingPriority
            @pulsarlua function AffixSystemEntry.getNamingPriority
            @desc Returns the priority used to resolve display selection when tiers tie.
            @ret number nPriority Finite naming priority.
        !]]
        getNamingPriority = function(oAffix)
            return fEntry(oAffix).priority;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getJournal
            @pulsarlua function AffixSystemEntry.getJournal
            @desc Returns the mutable journal for this application. The system replaces it on a fresh application and after successful removal.
            @ret AffixSystemJournal tJournal Mutable application state.
        !]]
        getJournal = function(oAffix)
            return fEntry(oAffix).journal;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getOwner
            @pulsarlua function AffixSystemEntry.getOwner
            @desc Returns the live external owner, or nil when detached or not yet reconnected after loading.
            @ret CoGObject|nil oOwner Live external owner.
        !]]
        getOwner = function(oAffix)
            local tToken = fEntry(oAffix).token;

            return tToken and fOwner(tToken) or nil;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.getSystem
            @pulsarlua function AffixSystemEntry.getSystem
            @desc Returns the live owning system, or nil when detached or not yet reconnected after loading.
            @ret AffixSystem|nil oSystem Live owning system.
        !]]
        getSystem = function(oAffix)
            local tToken = fEntry(oAffix).token;
            local tReference = tToken and _tSystems[tToken];

            return tReference and tReference[1] or nil;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.isApplied
            @pulsarlua function AffixSystemEntry.isApplied
            @desc Determines whether this affix is currently applied to a system.
            @ret boolean bResult True when the documented condition holds.
        !]]
        isApplied = function(oAffix)
            return fEntry(oAffix).token ~= false;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.isPrefix
            @pulsarlua function AffixSystemEntry.isPrefix
            @desc Determines whether this affix is a prefix.
            @ret boolean bResult True when the documented condition holds.
        !]]
        isPrefix = function(oAffix)
            return fEntry(oAffix).kind == _eType.PREFIX;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.isSuffix
            @pulsarlua function AffixSystemEntry.isSuffix
            @desc Determines whether this affix is a suffix.
            @ret boolean bResult True when the documented condition holds.
        !]]
        isSuffix = function(oAffix)
            return fEntry(oAffix).kind == _eType.SUFFIX;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.isCompatibleWithClass
            @pulsarlua function AffixSystemEntry.isCompatibleWithClass
            @desc Tests a listed compatible class or its descendant by class object or registered name.
            Invalid class arguments return false. Name queries do not expose class objects.
            @param class|string cClass Candidate owner class or registered name.
            @ret boolean bResult True when the documented condition holds.
        !]]
        isCompatibleWithClass = function(oAffix, cClass)
            if (class.is(cClass) or (rawtype(cClass) == "string" and class.getbyname(cClass) ~= nil)) then
                for _, cAllowed in ipairs(fEntry(oAffix).classes) do
                    if ((rawequal(cClass, cAllowed) or cClass == class.getname(cAllowed) or class.ischild(cClass, cAllowed))) then
                        return true;
                    end
                end
            end

            return false;
        end,

        --[[!
            @fqxn CoG.AffixSystem.Affix.Methods.eachCompatibleClass
            @pulsarlua function AffixSystemEntry.eachCompatibleClass
            @desc Returns an index/class iterator over a copy of this definition's compatibility list.
            @ret function fIterator Iterator function.
            @ret table tValues Copied values used as iterator state.
            @ret number nIndex Initial iterator index.
        !]]
        eachCompatibleClass = function(oAffix)
            local tClasses = {};
            for nIndex, cClass in ipairs(fEntry(oAffix).classes) do
                tClasses[nIndex] = cClass;
            end

            return ipairs(tClasses);
        end,
    };

    _tEntryMeta = {
        __type = "AffixSystemEntry",

        --[[!
            @fqxn CoG.AffixSystem.Internal.EntryMeta.Methods.__index
            @pulsarlua function EntryMeta.__index
            @desc Returns a cached method bound to this exact affix instance.
            Unknown member names raise an error; cached functions remain private.
            @param AffixSystemEntry oAffix Affix instance.
            @param string sKey Requested method name.
            @ret function fMethod Method bound to this affix.
        !]]
        __index = function(oAffix, sKey)
            local fMethod = _tEntryMethods[sKey];
            if (fMethod) then
                -- Keep bound methods outside the public table, preserving read-only
                -- members while avoiding one new closure on every getter lookup.
                local tMethods = _tMethods[oAffix];
                if (not tMethods[sKey]) then
                    tMethods[sKey] = function(...)
                        return fMethod(oAffix, ...);
                    end;
                end

                return tMethods[sKey];
            end

            error("Unknown affix member: "..tostring(sKey), 2);
        end,

        --[[!
            @fqxn CoG.AffixSystem.Internal.EntryMeta.Methods.__newindex
            @pulsarlua function EntryMeta.__newindex
            @desc Rejects direct modification of affix metadata and ownership.
        !]]
        __newindex = function()
            error("Affix metadata and ownership are read-only.", 2);
        end,

        --[[!
            @fqxn CoG.AffixSystem.Internal.EntryMeta.Methods.__serialize
            @pulsarlua function EntryMeta.__serialize
            @desc Provides detached metadata while retaining journal/token identity for
            hook upvalues and ownership. Snapshot consumers cannot mutate shared definitions.
            @param AffixSystemEntry oAffix Affix instance.
            @ret table tState Serializer state; external owner references are omitted from tokens.
        !]]
        __serialize = function(oAffix)
            local tState = fEntry(oAffix);
            local tClasses = {};
            for nIndex, cClass in ipairs(tState.classes) do
                tClasses[nIndex] = cClass;
            end
            return {
                kind        = tState.kind,
                name        = tState.name,
                tier        = tState.tier,
                classes     = tClasses,
                id          = tState.id,
                priority    = tState.priority,
                description = tState.description,
                values      = fCopyValues(tState.values),
                token       = tState.token,
                journal     = tState.journal,
            };
        end,

        --[[!
            @fqxn CoG.AffixSystem.Internal.EntryMeta.Methods.__tostring
            @pulsarlua function EntryMeta.__tostring
            @desc Returns this affix's display text.
            @param AffixSystemEntry oAffix Affix instance.
            @ret string sName Affix display text.
        !]]
        __tostring = function(oAffix)
            return fEntry(oAffix).name;
        end,
    };

    _tJournalMeta = {
        __type = "AffixSystemJournal",

        --[[!
            @fqxn CoG.AffixSystem.Internal.JournalMeta.Methods.__serialize
            @pulsarlua function JournalMeta.__serialize
            @desc Provides serializer state while preserving the supported shared object relationships.
            @param AffixSystemJournal tJournal Mutable application journal.
            @ret table tState Serializer state; external owner references are omitted from tokens.
        !]]
        __serialize = function(tJournal)
            local tState = {};
            for k, v in pairs(tJournal) do
                tState[k] = v;
            end

            return tState;
        end,
    };

    _tTokenMeta = {
        __type = "AffixSystemToken",

        --[[!
            @fqxn CoG.AffixSystem.Internal.TokenMeta.Methods.__serialize
            @pulsarlua function TokenMeta.__serialize
            @desc Provides serializer state while preserving the supported shared object relationships.
            @param AffixSystemToken tToken Shared component ownership token.
            @ret table tState Owner class and lock flag; the external host is omitted.
        !]]
        __serialize = function(tToken)
            return {ownerClass = tToken.ownerClass, locked = tToken.locked};
        end,
    };

    -- Private callable factories reuse the serializer's existing extension protocol.
    -- Tokens preserve sharing, journals preserve hook upvalues, and entries preserve identity.
    local _oEntryFactory = setmetatable({}, {
        --[[!
            @fqxn CoG.AffixSystem.Internal.EntryFactory.Methods.__call
            @pulsarlua function EntryFactory.__call
            @desc Private callable marker required by serializer registration; the restore adapter creates runtime values.
            @vis Private
        !]]
        __call = function()
        end
    });

    local _oJournalFactory = setmetatable({}, {
        --[[!
            @fqxn CoG.AffixSystem.Internal.JournalFactory.Methods.__call
            @pulsarlua function JournalFactory.__call
            @desc Private callable marker required by serializer registration; the restore adapter creates runtime values.
            @vis Private
        !]]
        __call = function()
        end
    });

    local _oTokenFactory = setmetatable({}, {
        --[[!
            @fqxn CoG.AffixSystem.Internal.TokenFactory.Methods.__call
            @pulsarlua function TokenFactory.__call
            @desc Private callable marker required by serializer registration; the restore adapter creates runtime values.
            @vis Private
        !]]
        __call = function()
        end
    });
    _mSerializer.registerFactory(_oEntryFactory, {
        name  = "AffixSystemEntry",
        types = {"AffixSystemEntry"},

        --[[!
            @fqxn CoG.AffixSystem.Internal.EntryFactory.Methods.restore
            @pulsarlua function EntryFactory.restore
            @desc Validates and reconstructs decoded serializer state without invoking gameplay callbacks.
            @param table tState Definition, application or serializer state.
            @ret AffixSystemEntry oRestored Restored runtime value.
            @vis Private
        !]]
        restore = function(tState)
            fValidateEntry(tState, true);

            return fNewEntry(tState);
        end,
    });
    _mSerializer.registerFactory(_oJournalFactory, {
        name  = "AffixSystemJournal",
        types = {"AffixSystemJournal"},

        --[[!
            @fqxn CoG.AffixSystem.Internal.JournalFactory.Methods.restore
            @pulsarlua function JournalFactory.restore
            @desc Validates and reconstructs decoded serializer state without invoking gameplay callbacks.
            @param table tState Definition, application or serializer state.
            @ret AffixSystemJournal oRestored Restored runtime value.
            @vis Private
        !]]
        restore = function(tState)
            type.assert.table(tState);

            return setmetatable(tState, _tJournalMeta);
        end,
    });
    _mSerializer.registerFactory(_oTokenFactory, {
        name  = "AffixSystemToken",
        types = {"AffixSystemToken"},

        --[[!
            @fqxn CoG.AffixSystem.Internal.TokenFactory.Methods.restore
            @pulsarlua function TokenFactory.restore
            @desc Validates and reconstructs decoded serializer state without invoking gameplay callbacks.
            @param table tState Definition, application or serializer state.
            @ret AffixSystemToken oRestored Restored runtime value.
            @vis Private
        !]]
        restore = function(tState)
            type.assert.table(tState);
            local sOwnerClass = tState.ownerClass;
            local bLocked = tState.locked;
            type.assert.string(sOwnerClass);
            assert(rawtype(tState.locked) == "boolean", "Invalid owner lock.");
            for sKey in pairs(tState) do
                assert(sKey == "ownerClass" or sKey == "locked", "Invalid affix ownership token.");
            end

            if (sOwnerClass ~= "") then
                fRegisterOwnerClass(sOwnerClass);
            end

            return setmetatable({ownerClass = sOwnerClass, locked = bLocked}, _tTokenMeta);
        end,
    });

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
    local Service = {};

    --[[!
        @fqxn CoG.AffixSystem.Methods.registerDefinition
        @pulsarlua function AffixSystem.registerDefinition
        @desc Copies a validated definition into the static registry. Rejects
        duplicate IDs regardless of case; registration never replaces a definition.
        @param string sID Opaque ID containing non-whitespace text.
        @param table tPattern Required type, name, classes and tiers. tiers maps
        configured tier enum members to generic plain-data tables. Optional
        priority defaults to zero; description defaults to name.
        @ret class cSystem AffixSystem for chaining.
        @throws Invalid pattern or duplicate ID; registry remains unchanged.
    !]]
    Service.registerDefinition = function(sID, tPattern)
        local sKey = fDefinitionKey(sID);
        assert(not _tDefinitions[sKey], "Affix definition ID is already registered.");
        local tDefinition = fPrepareDefinition(sID, tPattern);
        _tDefinitions[sKey] = tDefinition;
        return _cSystem;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.registerDefinitions
        @pulsarlua function AffixSystem.registerDefinitions
        @desc Atomically imports an ID-keyed table of patterns. Validates every
        pattern and case-insensitive collision before committing any definition.
        @param table tPatterns Definition ID to pattern map, e.g. require output.
        @ret class cSystem AffixSystem for chaining.
        @throws Invalid input or duplicate ID; no partial registration occurs.
    !]]
    Service.registerDefinitions = function(tPatterns)
        type.assert.table(tPatterns);
        local tPending = {};
        for sID, tPattern in pairs(tPatterns) do
            local sKey = fDefinitionKey(sID);
            assert(not _tDefinitions[sKey] and not tPending[sKey], "Affix definition ID is already registered.");
            tPending[sKey] = fPrepareDefinition(sID, tPattern);
        end
        for sKey, tDefinition in pairs(tPending) do
            _tDefinitions[sKey] = tDefinition;
        end
        return _cSystem;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.hasDefinition
        @pulsarlua function AffixSystem.hasDefinition
        @desc Tests whether an opaque ID is registered, ignoring its case.
        @param string sID Definition ID.
        @ret boolean bRegistered Whether the ID exists.
    !]]
    Service.hasDefinition = function(sID)
        return _tDefinitions[fDefinitionKey(sID)] ~= nil;
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.getDefinition
        @pulsarlua function AffixSystem.getDefinition
        @desc Returns a detached pattern copy, preserving canonical class/enum
        references. Modifying it cannot change the registered definition.
        @param string sID Case-insensitive definition ID.
        @ret table|nil tPattern Pattern copy, or nil when unregistered.
    !]]
    Service.getDefinition = function(sID)
        local tDefinition = _tDefinitions[fDefinitionKey(sID)];
        if (not tDefinition) then
            return nil;
        end
        local tClasses, tTiers = {}, {};
        local tValueCopies = {};
        for nIndex, cClass in ipairs(tDefinition.classes) do
            tClasses[nIndex] = cClass;
        end
        for eTier, tValues in pairs(tDefinition.tiers) do
            tTiers[eTier] = fCopyValues(tValues, tValueCopies);
        end
        return {
            type        = tDefinition.kind,
            name        = tDefinition.name,
            classes     = tClasses,
            tiers       = tTiers,
            priority    = tDefinition.priority,
            description = tDefinition.description,
        };
    end;

    --[[!
        @fqxn CoG.AffixSystem.Methods.createAffix
        @pulsarlua function AffixSystem.createAffix
        @desc Creates an independent detached entry from a registered definition
        and an explicitly selected enum tier. IDs carry no tier/gameplay meaning.
        Entries privately share validated immutable metadata; owner/journal state
        remains independent. Saves contain selected metadata/values, not a live
        registry lookup, so restoring never substitutes current definition data.
        @param string sID Registered ID, matched case-insensitively.
        @param TIER eTier Configured enum member present in this definition.
        @ret AffixSystemEntry oAffix New entry with getValues and existing getters.
        @throws Unknown ID, invalid/unavailable tier or wrong argument count.
    !]]
    Service.createAffix = function(...)
        assert(select("#", ...) == 2, "createAffix expects exactly an ID and a tier enum member.");
        local sID, eTier = ...;
        local tDefinition = assert(_tDefinitions[fDefinitionKey(sID)], "Unknown affix definition ID.");
        assert(lxe.isMember(eTier, _eTier) and eTier.Ordinal <= _eMaxTier.Ordinal, "Expected a supported configured tier enum member.");
        local tValues = assert(tDefinition.tiers[eTier], "Affix definition does not provide the requested tier.");
        return fNewEntry({
            kind        = tDefinition.kind,
            name        = tDefinition.name,
            tier        = eTier,
            classes     = tDefinition.classes,
            id          = tDefinition.id,
            priority    = tDefinition.priority,
            description = tDefinition.description,
            values      = tValues,
            token       = false,
            journal     = setmetatable({}, _tJournalMeta),
        });
    end;

    return {
        TYPE = _eType, MAX_TIER = _eMaxTier,
        entry = fEntry, owner = fOwner, dummy = fDummy,
        owners = _tOwners, systems = _tSystems,
        TokenMeta = _tTokenMeta, JournalMeta = _tJournalMeta,
        definitionKey = fDefinitionKey, denseLength = fDenseLength,
        registerOwnerClass = fRegisterOwnerClass,
        registerDefinition = Service.registerDefinition,
        registerDefinitions = Service.registerDefinitions,
        hasDefinition = Service.hasDefinition,
        getDefinition = Service.getDefinition,
        createAffix = Service.createAffix,
    };
end;
