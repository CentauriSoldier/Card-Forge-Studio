--[[!
@fqxn CFS.Modules.Documentation
@desc
<section aria-label="Documentation overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Documentation</h2><p style="font-size:1.15rem;margin:0">This helper keeps generated documentation names aligned when a game or card set is renamed.</p></div>
<h3>How it fits into your work</h3><p>Metadata editing stages matching Dox updates alongside the name change. Game renames check their sets; set renames affect the active set.</p>
<h3>Follow the handoffs</h3><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">What this helper changes</h3><p style="margin:0">When Options saves a renamed game or card set, this helper stages matching generated documentation-name changes in the existing script files. That keeps generated drawing and processing entries connected to the renamed project without requiring authors to repair each generated heading by hand.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">What stays under the author’s control</h3><p style="margin:0">Only matching documentation entries that already exist are candidates for the rename update. Missing comments are not created, and ordinary script code is not rewritten to match a documentation heading. The changes participate in the metadata save transaction and its outside-edit checks. This helper is separate from the pages that introduce Studio’s documentation.</p></article>
</div>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Options">Options</a></h3><p style="margin:0">Options puts application preferences and project information in one place.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.FS">File System</a></h3><p style="margin:0">FS is Studio's map of where project files belong.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Editors.Common">Editors.Common</a></h3><p style="margin:0">The shared editor helper supplies consistent drafts and save protections.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Only matching existing qualified-name lines in Dox comments change. Missing files or comments are not created and ordinary script text is not renamed.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual functions, inputs, and results.</p>
</section>
!]]

local wx            = require("wx");
local Documentation = {};


--[[!
@fqxn CFS.Modules.Documentation.Functions.Stage
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
@fqxn CFS.Modules.Documentation.Functions.UpdateText
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
