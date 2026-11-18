-- Aliases identify existing styles; they never create or inherit style settings.
local StyleAliases = {};

--[[!
@fqxn CFS.Modules.StyleAliases.Functions.build
@desc Validates alias ownership without creating styles. Rejects malformed names, duplicate aliases and collisions with canonical names. Empty comma-separated entries are ignored.
@param table tNames Canonical section names.
@param function fValue Reads the raw, non-inherited Aliases value for a section.
@return table tAliases Uppercase alias keys mapped to canonical section spelling.
!]]
function StyleAliases.build(tNames, fValue)
    local tNamesByKey, tAliases = {}, {};
    for _, sName in ipairs(tNames) do
        local sKey = sName:upper();
        assert(not tNamesByKey[sKey], "Style names differ only by case: "..sName);
        tNamesByKey[sKey] = sName;
    end
    for _, sName in ipairs(tNames) do
        for sAlias in ((fValue(sName) or "")..","):gmatch("(.-),") do
            sAlias = sAlias:match("^%s*(.-)%s*$");
            if (sAlias ~= "") then
                assert(sAlias:match("^[A-Za-z_][A-Za-z0-9_-]*$"), "Invalid alias for "..sName..": "..sAlias);
                local sKey = sAlias:upper();
                assert(not tNamesByKey[sKey], "Style alias conflicts with a style name: "..sAlias);
                assert(not tAliases[sKey], "Duplicate style alias: "..sAlias);
                tAliases[sKey] = sName;
            end
        end
    end
    return tAliases;
end

--[[!
@fqxn CFS.Modules.StyleAliases.Functions.read
@desc Builds aliases from an INI reader. Readers without section enumeration retain canonical-only lookup.
@param table oReader Existing style reader.
@return table tAliases Validated alias mapping.
!]]
function StyleAliases.read(oReader)
    if (not oReader or not oReader.GetSectionNames) then return {}; end
    return StyleAliases.build(oReader.GetSectionNames(), function(sName)
        return oReader.GetValue(sName, "Aliases", false);
    end);
end

return StyleAliases;
