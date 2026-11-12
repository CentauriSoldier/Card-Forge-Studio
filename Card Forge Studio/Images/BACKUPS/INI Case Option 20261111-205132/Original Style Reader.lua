return function(FontStyle,pFile)

            local tSections = {};
            local tNames    = {};
            local oConfig   = FontStyle.wx.wxFileConfig("", "", pFile, "", FontStyle.wx.wxCONFIG_USE_LOCAL_FILE);
            oConfig:DisableAutoSave();
            oConfig:SetExpandEnvVars(false);
            local bOK, sError = xpcall(function()
                local bGroup, sSection, nGroup = oConfig:GetFirstGroup();
                while (bGroup) do
                    tNames[#tNames + 1] = sSection;
                    tSections[sSection] = {};
                    oConfig:SetPath("/"..sSection);
                    local bEntry, sKey, nEntry = oConfig:GetFirstEntry();
                    while (bEntry) do
                        local bFound, sValue = oConfig:Read(sKey, "");
                        tSections[sSection][sKey] = bFound and sValue or "";
                        bEntry, sKey, nEntry = oConfig:GetNextEntry(nEntry);
                    end
                    oConfig:SetPath("/");
                    bGroup, sSection, nGroup = oConfig:GetNextGroup(nGroup);
                end
            end, debug.traceback);
            oConfig:delete();
            assert(bOK, sError);

            return {
                --[[!
                @fqxn CFS.Classes.FontStyle.Private.Functions.GetValue
                @desc Reads a style key, following inheritance until a value is found or a section repeats.
                @param any sSection Section.
                @param any sKey Key.
                @param any bInherit Inherit.
                @vis private
                !]]
                GetValue = function(sSection, sKey, bInherit)
                    local tSeen = {};
                    while (not tSeen[sSection]) do
                        tSeen[sSection] = true;
                        local sValue = tSections[sSection] and tSections[sSection][sKey] or "";
                        local sReference = sValue:match("^%s*<%s*(.-)%s*>%s*$");
                        if (not bInherit or not sReference) then return sValue end
                        sSection = sReference;
                    end
                    return "";
                end,
                --[[!
                @fqxn CFS.Classes.FontStyle.Private.Functions.GetValueNames
                @desc Returns sorted keys for a style section.
                @param any sSection Section.
                @vis private
                !]]
                GetValueNames = function(sSection)
                    local tKeys = {};
                    for sKey in pairs(tSections[sSection] or {}) do tKeys[#tKeys + 1] = sKey; end
                    table.sort(tKeys);
                    return tKeys;
                end,
                --[[!
                @fqxn CFS.Classes.FontStyle.Private.Functions.GetSectionNames
                @desc Returns the style section names.
                @vis private
                !]]
                GetSectionNames = function() return tNames end,
            };
        
end
