--[[!
@fqxn CFS.Modules.Globals.ProcessDox
@desc
<section aria-label="ProcessDox overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">ProcessDox</h2><p style="font-size:1.15rem;margin:0">Rebuilds the loaded game’s documentation using its saved Docs options.</p></div>
<h3>How it fits into your work</h3><p>Its source connects game metadata with Dox. Game > Rebuild Docs runs this builder; Game options control page and code themes and Card Forge Studio source inclusion.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Globals">Globals</a></h3><p style="margin:0">Globals connects the application services during startup.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Game">Game</a></h3><p style="margin:0">A game is the home for a whole project: its name, shared settings, and collection of card sets.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Save your source edits before rebuilding. Card Forge Studio and plugin inclusion default to off; failures appear in the Log window.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

--[[!
@fqxn CFS.Modules.Globals.ProcessDox.Functions.Build
@pulsarlua function ProcessDox
@desc Rebuilds the active game's HTML documentation with saved game-specific themes. Card Forge Studio and plugin sources are included only when enabled in Game options. Reads saved sources without executing them; failures are logged with tracebacks.
!]]
return function()
    local wx = require("wx");
    assert(Game.GetActive(), "Load a game first.");
    Log.Note("Building game docs");
    local bOK, sResult = xpcall(function()
        local oDox = DoxLua(INIFile.GetValue(FS.Game.Info, "SETTINGS", "Name"));
        local sTheme = INIFile.GetValue(FS.Game.Info, "SETTINGS", "DocsTheme");
        local sPrism = INIFile.GetValue(FS.Game.Info, "SETTINGS", "DocsPrismTheme");
        if (sTheme == "") then sTheme = "MIDNIGHT_BLUE"; end
        if (sPrism == "") then sPrism = "OKAIDIA"; end
        oDox.setTheme(Dox.THEME[sTheme]);
        oDox.setPrismTheme(Dox.PRISM[sPrism]);
        local bPlugins = INIFile.GetValue(FS.Game.Info, "SETTINGS", "IncludePlugins"):lower() == "true";
        local tFiles = {};
        --[[!
        @fqxn CFS.Modules.Globals.ProcessDox.Private.Functions.Collect
        @desc Collects saved Lua sources recursively while optionally excluding plugins and excluding generated exports, backups, and development metadata.
        @param string pFolder Source folder.
        @vis private
        !]]
        local function Collect(pFolder)
            local oFolder = wx.wxDir(pFolder);
            assert(oFolder:IsOpened(), "Cannot inspect documentation folder: "..pFolder);
            local bFound, sFile = oFolder:GetFirst("", wx.wxDIR_FILES + wx.wxDIR_DIRS);
            while (bFound) do
                local pFile = pFolder.."/"..sFile;
                if (wx.wxDirExists(pFile)) then
                    local sLower = sFile:lower();
                    if ((bPlugins or sLower ~= "plugins") and sLower ~= "exports" and sLower ~= "csvbackup" and sLower ~= ".git" and sLower ~= ".codex" and sLower ~= ".agents") then Collect(pFile); end
                elseif (sFile:lower():match("%.lua$")) then
                    tFiles[#tFiles + 1] = pFile;
                end
                bFound, sFile = oFolder:GetNext();
            end
            oFolder:delete();
        end
        if (INIFile.GetValue(FS.Game.Info, "SETTINGS", "DocsIncludeStudio"):lower() == "true") then Collect(_Scripts); end
        Collect(FS.Game.Root);
        table.sort(tFiles);
        for _, pFile in ipairs(tFiles) do oDox.importFile(pFile, true); end
        local pIntro = FS.Game.Docs.."/intro";
        if (wx.wxFileExists(pIntro)) then
            local hFile = assert(io.open(pIntro, "rb"));
            local sIntro = hFile:read("*a"); hFile:close(); oDox.setIntro(sIntro);
        end
        if (not wx.wxDirExists(FS.Game.Docs)) then assert(wx.wxFileName.Mkdir(FS.Game.Docs, 511, wx.wxPATH_MKDIR_FULL), "Cannot create game documentation folder."); end
        oDox.refresh(); oDox.setOutputPath(FS.Game.Docs);
        return oDox.export(DOX_EXPORT_FILENAME);
    end, debug.traceback);
    if (not bOK) then Log.Error("Game docs build failed: "..tostring(sResult)); return false, sResult; end
    Log.Note("Game docs build complete");
    return true, sResult;
end
