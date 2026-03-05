return function()
    local sName           = INIFile.GetValue(FS.Info, "SETTINGS", "Name");
    sName                 = (type.isstring(sName) and not sName:isempty()) and sName or APP_NAME;
    local bIncludePlugins = INIFile.GetValueBoolean(FS.Info, "SETTINGS", "IncludePlugins");

    local oDoxLua = DoxLua(sName);

    local sScriptsRoot = (_Scripts or ""):gsub("/", "\\"):gsub("\\+$", "");
    local sPluginsRoot = (sScriptsRoot .. "\\Plugins"):gsub("\\+", "\\");
    local nPluginsLen  = #sPluginsRoot;

    local function IsUnderPlugins(pFilePath)

        if not (type.isstring(pFilePath)) then
            return false;
        end

        -- normalize path separators
        local sNormalizedPath = pFilePath:gsub("/", "\\");

        -- check whether the file path resides under the Scripts\Plugins root
        return sNormalizedPath:sub(1, nPluginsLen) == sPluginsRoot;

    end

    local function ImportFile(pFile)

        if (not bIncludePlugins and IsUnderPlugins(pFile)) then
            return true; -- skip plugin files
        end

        oDoxLua.importFile(pFile, true);
        --p(pFile) -- optional debug
        return true;
    end

    -- Import ALL app scripts under _Scripts (recursively)
    File.Find(sScriptsRoot .. "\\", "*.lua", true, false, nil, ImportFile);

    -- Import ALL game scripts (recursively)
    File.Find(FS.Game .. "\\", "*.lua", true, false, nil, ImportFile);

    -- Optional intro
    local pIntro = FS.Docs .. "\\intro";
    if (File.DoesExist(pIntro)) then
        oDoxLua.setIntro(TextFile.ReadToString(pIntro));
    end

    File.Delete(FS.Docs.."\\"..DOX_EXPORT_FILENAME);

    oDoxLua.refresh();
    oDoxLua.setOutputPath(FS.Docs);
    oDoxLua.export(DOX_EXPORT_FILENAME);
    Log.Note("Dox Build Complete.");
end
