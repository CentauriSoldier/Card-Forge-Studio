return function(pGame)
    local sName             = INIFile.GetValue(FS.Info, "SETTINGS", "Name");
    local sName             = (type.isstring(sName) and not sName:isempty()) and sName or APP_NAME;
    local bIncludePlugins   = INIFile.GetValueBoolean(FS.Info, "SETTINGS", "IncludePlugins");

    local oDoxLua = DoxLua(sName); --create the dox object

    local function ImportFile(pFile) --callback function for found files
        oDoxLua.importFile(pFile, true); p(pFile)
        return true;
    end

    --start with the app scripts
    local sPluginsRoot          = _Scripts.."\\Plugins";
    local nPluginsRootLength    = #sPluginsRoot;

    --add files from the app's Scripts subfolders
    for nIndex, pFolder in ipairs(Folder.Find(_Scripts, "*", true, nil)) do

        if (pFolder:sub(1, nPluginsRootLength) == sPluginsRoot) then

            --don't run Dox inside the Plugins dir unless it's explicitly permitted
            if (bIncludePlugins) then
                File.Find(pFolder.."\\", "*.lua", true, false, nil, ImportFile);
            end

        else
            File.Find(pFolder.."\\", "*.lua", true, false, nil, ImportFile);
        end

    end

    --now, add any of the game's scripts that exist QUESTION isn't this already done above? Commenting out for now.
    --File.Find(FS.Game.."\\", "*.lua", true, false, nil, ImportFile);
    File.Find(FS.Game.."\\", "*.lua", true, false, nil, ImportFile);

    --if the user has included an intro doc in the game, load it too
    local pIntro = FS.Docs.."\\intro"
    if (File.DoesExist(pIntro)) then
        oDoxLua.setIntro(TextFile.ReadToString(pIntro));
    end

    --refresh the dox content
    oDoxLua.refresh();
    --set the output path
    oDoxLua.setOutputPath(FS.Docs);
    --create the output
    oDoxLua.export(DOX_EXPORT_FILENAME);
end
