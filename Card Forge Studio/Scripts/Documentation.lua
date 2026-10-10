--[[!
@fqxn CFS.Modules.Documentation
@desc Updates matching existing generated Dox namespaces as part of metadata save transactions.
!]]

local wx            = require("wx");
local Documentation = {};


--[[!
@fqxn CFS.Modules.Documentation.Stage
@pulsarlua function Documentation.Stage
@desc Adds only existing, changed Dox files to the metadata save transaction. No missing file or comment is created.
@param table tModel Existing staged metadata model.
@param string sGameUUID Game identifier.
@param string sOldGame Previous game name.
@param string sNewGame Requested game name.
@param string pActiveInfo Active card-set metadata path, or nil.
@param string sOldSet Previous active card-set name, or nil.
@param string sNewSet Requested active card-set name, or nil.
@note Handles all sets for a game rename and only the active set for a set rename. Changes share the metadata rollback and external-edit checks.
!]]
function Documentation.Stage(tModel, sGameUUID, sOldGame, sNewGame, pActiveInfo, sOldSet, sNewSet)
    if (sOldGame == sNewGame and sOldSet == sNewSet) then return; end

    for _, sUUID in ipairs(FS.Game.GetCardSetUUIDs(sGameUUID)) do
        local pRoot = FS.CardSet.GetRoot(sGameUUID, sUUID);
        local pInfo = FS.CardSet.GetInfoINIPath(sGameUUID, sUUID);
        local sName = INIFile.GetValue(pInfo, "SETTINGS", "Name");
        local bActive = pActiveInfo and io.normalizepath(pInfo) == io.normalizepath(pActiveInfo);
        local sBefore = bActive and sOldSet or sName;
        local sAfter  = bActive and sNewSet or sName;

        if (sOldGame ~= sNewGame or sBefore ~= sAfter) then
            for _, sFilename in ipairs({"Draw.lua", "DrawBack.lua", "RowProc.lua"}) do
                local pFile = pRoot.."/"..sFilename;

                if (wx.wxFileExists(pFile)) then
                    local tFile;

                    for _, tExisting in ipairs(tModel.files) do
                        if (io.normalizepath(tExisting.path) == io.normalizepath(pFile)) then
                            tFile = tExisting;
                            break;
                        end
                    end

                    if (not tFile) then
                        local tSource = require("Windows.Editors.Common").model({{name = sFilename, path = pFile, kind = "lua"}});

                        tFile = tSource.files[1];
                    end

                    local sUpdated = Documentation.UpdateText(tFile.original, sOldGame.."."..sBefore, sNewGame.."."..sAfter);

                    if (sUpdated ~= tFile.original) then
                        local bPresent = false;

                        for _, tExisting in ipairs(tModel.files) do
                            if (tExisting == tFile) then bPresent = true; end
                        end
                        if (not bPresent) then tModel.files[#tModel.files + 1] = tFile; end
                        tFile.text = sUpdated;
                    end
                end
            end
        end
    end
end


--[[!
@fqxn CFS.Modules.Documentation.UpdateText
@pulsarlua function Documentation.UpdateText
@desc Replaces an exact old namespace only on qualified-name lines inside Dox comments, including the legacy generated card-set namespace.
@param string sText Existing script text.
@param string sOld Previous game and card-set namespace.
@param string sNew Requested namespace.
@return string Updated script text with all other content preserved.
!]]
function Documentation.UpdateText(sText, sOld, sNew)
    return (sText:gsub("%-%-%[%[!.-%]%]", function(sComment)
        return (sComment:gsub("(@fqxn[ \t]+)([^\r\n]+)", function(sTag, sQualified)
            for _, sPrefix in ipairs({sOld..".", "CFS.User.CardSet."}) do
                if (sQualified:sub(1, #sPrefix) == sPrefix) then
                    return sTag..sNew.."."..sQualified:sub(#sPrefix + 1);
                end
            end

            return sTag..sQualified;
        end));
    end));
end


return Documentation;
