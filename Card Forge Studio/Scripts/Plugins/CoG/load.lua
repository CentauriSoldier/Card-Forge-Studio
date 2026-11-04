-- ON-DEMAND CODE OF GAMING LOADER
-- Class declarations use .lxc; ordinary configuration/helper modules remain Lua.
local _sModule = ...;

local _G        = _G;
local assert    = assert;
local debug     = debug;
local error     = error;
local loadfile  = loadfile;
local package   = package;
local pcall     = pcall;
local rawset    = rawset;
local rawequal  = rawequal;
local select    = select;
local string    = string;
local tostring  = tostring;

local _nConfigParentLevels = 0;
local _bInitialized        = false;
local _cCoGBase;

--[[!
@fqxn CoG.isCoGStructure
@pulsarlua function type.isCoGStructure
@desc Recognizes native structure instances and descendants without relying on
    their concrete type name. Registered when the structure loader entry is enabled.
@param any vObject Candidate instance.
@ret boolean bStructure Whether it belongs to the CoGStructure hierarchy.
!]]
local function isCoGStructure(vObject)
    return class.isa(vObject, "CoG.CoGStructure");
end

--[[!
@fqxn CoG.init
@pulsarlua function init
@desc Initializes CoG configuration and the enabled public aliases after LuaEx.
    Requiring cog.load only returns this function. LuaEx must first discover the
    class declarations through package.path. Ordinary Lua modules retain require.
    During migration, unfinished entries stay commented out. After successful
    initialization, subsequent calls return the same CoGBase class without reconfiguration.
@param number|nil nConfigParentLevels Parent levels above the cog source folder
    for the user configuration overlay; defaults to zero for bundled defaults.
@param string|nil sConfigFilename User configuration basename without an
    extension. Non-string values default to config.
@ret class cCoGBase Initialized CoGBase class.
@throws Missing LuaEx/LXC dependencies, invalid options or enabled-module errors.
    Failed initialization may leave loaded modules and classes; package.path is
    restored before the error propagates.
@ex local init = require("cog.load"); local CoGBase = init();
!]]
local function init(...)
    assert(_G.LUAEX_INIT == true, "Initialize LuaEx before loading CoG.");

    if (_bInitialized) then
        return _cCoGBase;
    end

    assert(_G.class and _G.ClassRegistry and _G.Potentiometer and _G.Protean,
           "CoG requires LuaEx class-load level 3 or higher.");
    assert(_G.lxc and _G.lxc.class,
           "CoG requires LuaEx's embedded LXC runtime.");
    assert(select("#", ...) <= 2, "CoG init accepts at most two options.");

    local nConfigParentLevels, sConfigFilename = ...;
    local type = _G.type;

    if (nConfigParentLevels == nil) then
        nConfigParentLevels = _nConfigParentLevels;
    end
    if (type(sConfigFilename) ~= "string") then
        sConfigFilename = "config";
    end

    assert(type(nConfigParentLevels) == "number" and
           nConfigParentLevels >= 0 and nConfigParentLevels < math.huge and
           nConfigParentLevels % 1 == 0,
           "CoG config parent levels must be zero or a positive whole number.");
    assert(type(sConfigFilename) == "string" and #sConfigFilename > 0 and
           sConfigFilename:find("%S") and
           not sConfigFilename:find("[./\\:%z]"),
           "CoG config filename must be a nonblank name without an extension or directory components.");

    local pSourceDirectory = debug.getinfo(1, "S").source:match("^@(.+)[/\\][^/\\]+$") or ".";
    local pCoG = type(_sModule) == "string" and _sModule:match("^(.*)%.[^.]+$") or "cog";
    local sOriginalPackagePath = package.path;

    package.path = package.path..";"..pSourceDirectory.."/../?.lua";

    local bSuccess, cResult = pcall(function()
        --[[!
        @fqxn CoG.init.loadConfig
        @desc Executes the bundled configuration assembler with the selected
            overlay location and the foundation's purge helper. Caches the
            assembled result for ordinary require calls. Runs after LuaEx has
            discovered CoGBase.lxc, before any dependent CoG entry is enabled.
        @param function fPurge Configuration branch-replacement helper.
        @ret table tConfig Validated configuration returned by the assembler.
        !]]
        local function fLoadCoGConfig(fPurge)
            local pConfigFile = pSourceDirectory.."/config.lua";
            local fConfig, sReason = loadfile(pConfigFile);
            assert(fConfig, "Unable to load CoG config at '"..pConfigFile.."': "..tostring(sReason));

            local tOptions = {userFilename = sConfigFilename..".lua", purge = fPurge};

            if (nConfigParentLevels > 0) then
                tOptions.userDirectory = pSourceDirectory..
                                         string.rep("/..", nConfigParentLevels);
            end

            local tConfig = fConfig(pCoG..".config", tOptions);
            type.assert.custom(tConfig, "table", "CoG config must return a table.");

            package.loaded[pCoG..".config"] = tConfig;
            -- The public class captures this canonical cache entry once. Keep
            -- it identical even when this loader is required through another prefix.
            package.loaded["cog.config"] = tConfig;

            return tConfig;
        end

        --[[!
        @fqxn CoG.init.getClass
        @desc Resolves a class already discovered by LuaEx and publishes its
            established global/require alias. This initializer never discovers
            or loads class sources. Put CoG's root on package.path before
            initializing LuaEx. Pending entries remain commented out below.
        @param string pRelative Class source path relative to cog, ending in .lxc.
        @param string sClassName Public class name in CoG.
        @param string|nil sAlias Established global name; defaults to the class name.
        @ret class cClass The class already registered by LuaEx.
        @throws The class is missing or an alias belongs to another value.
        !]]
        local function fGetClass(pRelative, sClassName, sAlias)
            assert(pRelative:match("%.lxc$"), "CoG class sources must use .lxc.");
            local cClass = _G.lxc.class.getbyname("CoG."..sClassName);
            assert(cClass, "LuaEx has not discovered "..pRelative..
                ". Put CoG's root on package.path before initializing LuaEx.");

            sAlias = sAlias or sClassName;
            assert(_G[sAlias] == nil or rawequal(_G[sAlias], cClass),
                "CoG global is already bound: "..sAlias);

            local sRequireName = pCoG.."."..pRelative:gsub("%.lxc$", ""):gsub("/", ".");
            local vCached = package.loaded[sRequireName];
            assert(vCached == nil or rawequal(vCached, cClass),
                "CoG module is already loaded: "..sRequireName);

            rawset(_G, sAlias, cClass);
            package.loaded[sRequireName] = cClass;

            return cClass;
        end

        -- MIGRATION CHECKLIST
        -- Uncomment an entry only after its source and dependencies are ready.
        -- The foundation must initialize configuration before dependent modules.
        local cCoGBase;

        cCoGBase = fGetClass("CoGBase.lxc", "CoGBase");
        local tConfig = fLoadCoGConfig(cCoGBase.purge);

        -- Capture the locked configuration before returning control to callers.
        assert(rawequal(cCoGBase.config, tConfig), "CoG configuration reference mismatch.");

        -- Preserve the standalone helper exposed by the original foundation.
        BuildVersionID = cCoGBase.BuildVersionID;

        -- Foundational classes and utilities.
        -- scaler       = fGetClass("Scaler.lxc", "Scaler", "scaler");
        -- Shuffler     = fGetClass("Shuffler.lxc", "Shuffler");
        Rarity          = fGetClass("Rarity.lxc", "Rarity");
        -- Validate selected rarity settings now, before exposing initialized CoG.
        assert(lxe.isEnum(CoG.LEVEL), "CoG must provide its shared LEVEL enum.");
        Rarity.getName(Rarity.MinLevel); -- Validate selected settings without constructing enum identities.
        RNG             = fGetClass("RNG.lxc", "RNG");
        -- BaseMod      = fGetClass("ModSystem/BaseMod.lxc", "BaseMod");
        -- Factorium    = fGetClass("ModSystem/Factorium.lxc", "Factorium");
        -- Tiled        = fGetClass("Tiled.lxc", "Tiled");

        -- Existing lightweight factories are ordinary Lua modules, not classes.
        TagSystem    = require(pCoG..".TagSystem");
        -- Targetor     = require(pCoG..".Targetor");
        type.TagSystem = true;
        -- type.Targetor  = true;

        -- Components.
        AffixSystem  = fGetClass("AffixSystem.lxc", "AffixSystem");
        -- Register entry/journal/token adapters before any object is restored.
        assert(lxe.isEnum(AffixSystem.TYPE), "AffixSystem must provide its TYPE enum.");
        assert(lxe.isMember(AffixSystem.MAX_TIER, CoG.TIER), "AffixSystem must initialize its tier and persistence services.");
        Pool            = fGetClass("Pool.lxc", "Pool");
        assert(lxe.isEnum(Pool.ASPECT), "Pool must provide its declared ASPECT enum.");
        -- ASPECT is now ready before configuration; retain eager settings validation.
        local nReservationMax = tConfig.Pool.reservationMax;
        assert(rawtype(nReservationMax) == "number" and nReservationMax >= 0 and
            nReservationMax <= 0.9999999999999,
            "Pool reservationMax config must be within the supported nonnegative reservation range.");
        -- StatusTracker = require(pCoG..".StatusTracker");
        -- AStar        = fGetClass("AStar.lxc", "AStar");

        -- Object foundations, vehicles, structures and cards.
        CoGRegistry     = fGetClass("CoGRegistry.lxc", "CoGRegistry");
        CoGObject    = fGetClass("Objects/CoGObject.lxc", "CoGObject");
        CoGAbility      = fGetClass("Objects/CoGAbility.lxc", "CoGAbility");
        CoGVehicle      = fGetClass("Objects/VehicleSystem/CoGVehicle.lxc", "CoGVehicle");
        assert(lxe.isEnum(CoGVehicle.COMPONENT), "CoGVehicle must provide its configured COMPONENT enum.");
        CoGStructure    = fGetClass("Objects/StructureSystem/CoGStructure.lxc", "CoGStructure");
        -- Keep the structure marker predicate for concrete descendants.
        rawset(type, "isCoGStructure", isCoGStructure);
        -- BaseCard     = fGetClass("CardSystem/BaseCard.lxc", "BaseCard");
        -- BaseDeck     = fGetClass("CardSystem/BaseDeck.lxc", "BaseDeck");

        -- Inventory classes; ItemRules.lua and ItemPersistence.lua stay helpers.
        -- SlotPattern  = fGetClass("Objects/ItemSystem/SlotPattern.lxc", "SlotPattern");
        -- CoGItem      = fGetClass("Objects/ItemSystem/CoGItem.lxc", "CoGItem");
        -- ItemSlot     = fGetClass("Objects/ItemSystem/ItemSlot.lxc", "ItemSlot");
        -- ItemSlotSystem = fGetClass("Objects/ItemSystem/ItemSlotSystem.lxc", "ItemSlotSystem");
        -- ItemSystem   = fGetClass("Objects/ItemSystem/ItemSystem.lxc", "ItemSystem");
        -- ItemStashSystem = fGetClass("Objects/ItemSystem/ItemStashSystem.lxc", "ItemStashSystem");

        -- Progression precedes creature composition.
        -- XPSystem     = fGetClass("XPSystem.lxc", "XPSystem");
        -- CoGCreature  = fGetClass("Objects/CreatureSystem/CoGCreature.lxc", "CoGCreature");

        -- IEquippable, IConsumable and IBlueprintable are legacy interfaces.
        -- LXC excludes interfaces; their intended contracts must be addressed
        -- in the affected modules before enabling those modules.

        return cCoGBase;
    end);

    package.path = sOriginalPackagePath;

    if (not bSuccess) then
        error(cResult, 0);
    end

    if (cResult ~= nil) then
        _cCoGBase, _bInitialized = cResult, true;
    end

    return cResult;
end

return init;



