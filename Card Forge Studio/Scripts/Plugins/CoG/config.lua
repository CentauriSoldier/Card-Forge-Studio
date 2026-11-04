--[[!
    @fqxn CoG.Config
    @pulsarlua table CoGBase.config
    @desc Assembles bundled CoG defaults, then overlays an optional user config.lua.
    The loader always calls this bundled file. A positive config-parent level locates
    the user's config.lua above the Cog root directory; zero uses bundled defaults alone.
    User files return ordinary tables containing only the settings they override.
    Ordinary overrides apply recursively to existing keys only, including list indices.
    A user table whose metatable contains __purge = true replaces that branch with its supplied
    contents, allowing new keys and shorter lists. The marker is not runtime data.
    StatusTracker effect declarations belong in the selected CoG.EFFECT enum.
    The final table and its ordinary subtables are read-only at runtime.
    TIER references the canonical CoG.TIER declaration loaded before classes. Enum
    overrides are selected during discovery, before these settings are assembled.
    The bundled Rarity section receives that selected enum explicitly.
!]]
local _sConfigModule, _tConfigOptions = ...; -- require may supply a filename as its second argument.
local _pUserDirectory = rawtype(_tConfigOptions) == "table" and _tConfigOptions.userDirectory or nil;

-- __purge is an optional boolean metavalue on the user table's actual metatable.
-- false behaves like omission; other values are rejected rather than treated as truthy.
local function purgesDefaults(tInput)
    -- Read the actual metatable even when __metatable protects normal inspection.
    -- rawget avoids interpreting an inherited __index result as a declared metavalue.
    local tMeta = debug.getmetatable(tInput);
    local bPurge = tMeta and rawget(tMeta, "__purge");

    return rawtype(bPurge) == "boolean" and bPurge or false;
end

-- Copy data without changing cached defaults or caller-owned user tables.
-- Typed values, including enum members, retain their own framework identity.
-- User metatables are not copied, so purge instructions do not become runtime settings.
local function copySettings(vInput, tCopies, bUserConfig)

    if (type(vInput) ~= "table") then
        return vInput;
    end

    if (not tCopies[vInput]) then
        local tOutput = {};
        tCopies[vInput] = tOutput;

        if (bUserConfig) then
            purgesDefaults(vInput);
        end

        for k, v in pairs(vInput) do

            tOutput[k] = copySettings(v, tCopies, bUserConfig);
        end
    end

    return tCopies[vInput];
end

-- Merge into a copy of the defaults. Ordinary tables affect matching keys only;
-- a marked child may introduce a new branch because it supplies that branch in full.
-- Track source/destination pairs so cyclic or shared settings can be visited safely.
local function applySettings(tConfig, tUserConfig, tCopies, tMerged)

    if (purgesDefaults(tUserConfig) or type(tConfig) ~= "table") then
        return copySettings(tUserConfig, tCopies, true);
    end

    local tDestinations = tMerged[tUserConfig];

    if (not tDestinations) then
        tDestinations = {};
        tMerged[tUserConfig] = tDestinations;
    elseif (tDestinations[tConfig]) then
        return tConfig;
    end

    tDestinations[tConfig] = true;

    for k, v in pairs(tUserConfig) do

        local vCurrent = tConfig[k];
        local bUserTable = type(v) == "table";

        -- Test against nil so an existing false setting still counts as a matching key.
        if (vCurrent ~= nil or (bUserTable and purgesDefaults(v))) then

            if (bUserTable) then
                tConfig[k] = applySettings(vCurrent, v, tCopies, tMerged);
            else
                tConfig[k] = v;
            end
        end
    end

    return tConfig;
end

-- Load the project table once before constructing defaults which depend on TIER.
local tUserConfig = {};
if (_pUserDirectory ~= nil) then
    local sUserFilename = _tConfigOptions.userFilename or "config.lua";
    local pUserConfigFile = _pUserDirectory.."/"..sUserFilename;
    -- CoGBase.purge is needed before the class exists. Expose the same helper only
    -- inside this configuration chunk; no temporary global namespace is created.
    local tUserEnvironment = setmetatable({
        CoGBase = table.readonly({purge = _tConfigOptions.purge}),
    }, {__index = _G});
    local userConfigLoader, sError = loadfile(pUserConfigFile, "t", tUserEnvironment);
    assert(userConfigLoader, "Unable to load CoG user config at '"..pUserConfigFile.."': "..tostring(sError));
    tUserConfig = userConfigLoader(_sConfigModule, {directory = _pUserDirectory});
    type.assert.custom(tUserConfig, "table", "CoG user config at '"..pUserConfigFile.."' must return a table.");
end

-- Declaration identities are fixed before classes; configuration selects settings.
assert(not (rawtype(tUserConfig.Rarity) == "table" and tUserConfig.Rarity.LEVEL ~= nil),
    "Rarity uses the shared CoG.LEVEL enum; use NAME for configured rarity rows.");
assert(not (rawtype(tUserConfig.CoGVehicle) == "table" and tUserConfig.CoGVehicle.COMPONENT ~= nil),
    "CoGVehicle COMPONENT declarations belong in CoGVehicle.lxc, not configuration.");
assert(tUserConfig.StatusTracker == nil,
    "StatusTracker effect declarations belong in CoG.EFFECT, not configuration.");
-- Enum selection is complete before configuration; use the published identity directly.
local eTier = CoG.TIER;

-- Always load framework-adjacent defaults; Rarity must use the selected tier.
local tConfig = {
    TIER          = eTier,
    app           = require(_sConfigModule..".app"),
    AStar         = require(_sConfigModule..".AStar"),
    Pool          = require(_sConfigModule..".Pool"),
    Scaler        = require(_sConfigModule..".Scaler"),
    CoGObject    = require(_sConfigModule..".CoGObject"),
    CoGVehicle   = require(_sConfigModule..".CoGVehicle"),
    BaseMod       = require(_sConfigModule..".BaseMod"),
    Rarity        = require(_sConfigModule..".Rarity")(eTier),
    StatusTracker = require(_sConfigModule..".StatusTracker"),
};
tConfig = applySettings(copySettings(tConfig, {}, false), tUserConfig, {}, {});
assert(tConfig.Rarity.LEVEL == nil,
    "Rarity uses the shared CoG.LEVEL enum; use NAME for configured rarity rows.");
assert(tConfig.CoGVehicle.COMPONENT == nil,
    "CoGVehicle COMPONENT declarations belong in CoGVehicle.lxc, not configuration.");

-- Reject incomplete timer adapters during configuration, rather than failing
-- later while an application is adjusting its interface.
type.assert.custom(tConfig.Scaler, "table", "CoG Scaler config must be a table.");
type.assert.custom(tConfig.Scaler.Debounce, "table", "CoG Scaler.Debounce must be a table.");
local tDebounce = tConfig.Scaler.Debounce;
assert(rawtype(tDebounce.DelayMS) == "number" and tDebounce.DelayMS == tDebounce.DelayMS
    and tDebounce.DelayMS >= 0 and tDebounce.DelayMS < math.huge,
    "Scaler Debounce.DelayMS must be finite and nonnegative.");
local bSchedule = rawtype(tDebounce.Schedule) == "function";
local bCancel = rawtype(tDebounce.Cancel) == "function";
local bScheduleUnset = tDebounce.Schedule == nil or type.isnull(tDebounce.Schedule);
local bCancelUnset = tDebounce.Cancel == nil or type.isnull(tDebounce.Cancel);
assert((bSchedule and bCancel) or (bScheduleUnset and bCancelUnset),
    "Scaler debounce requires both Schedule and Cancel functions, or neither.");

-- Keep typed enums intact while locking ordinary configuration tables.
return table.readonly(tConfig);



