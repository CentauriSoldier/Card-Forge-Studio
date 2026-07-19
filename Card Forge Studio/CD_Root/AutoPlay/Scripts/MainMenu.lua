local eMenu                 = Menu.EVENT;
local _sSection             = ""; --set this at each section below to direct INI access
local _pINI                 = FS.AppCFG;
local _sSub                 = ":>";
local _nExportRadioGroupID  = 1;

--happens only during startup
local function Load(sValue, vType)
    local vRet;
    --local sValue = sValueName:gsub(' ', '');
    local zType         = type(vType);
    local bTypeIsString = zType == "string";

    if (bTypeIsString and vType == "boolean") then
        vRet = INIFile.GetValueBoolean(_pINI, _sSection, sValue);
    else
        vRet = INIFile.GetValue(_pINI, _sSection, sValue);
    end

    return vRet;
end

local function LoadB(sValue)
    return Load(sValue, "boolean");
end

local function Save(sValue, sData)
    INIFile.SetValue(_pINI, _sSection, sValue, tostring(sData));
end



local TheMenu = Menu();
TheMenu.SetAutoUpdate(false);

--------------------------------------------------------------
local _nIconID                          = -1;
local _bEnabled, _bChecked, _bCheckable = true, true, true;
local _tNoCallbacks                     = nil;
--------------------------------------------------------------

--[[
███████╗██╗██╗     ███████╗
██╔════╝██║██║     ██╔════╝
█████╗  ██║██║     █████╗
██╔══╝  ██║██║     ██╔══╝
██║     ██║███████╗███████╗
╚═╝     ╚═╝╚══════╝╚══════╝  ]]
_sSection = "ExporterType";

TheMenu.Add("File",                             _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   _tNoCallbacks).
        Add("File:>Export",                     _nIconID,   -_bEnabled,   -_bChecked,   -_bCheckable,   _tNoCallbacks).
        --Add("File:>---",                        _nIconID,   -_bEnabled,   -_bChecked,   -_bCheckable,   _tNoCallbacks).
        --Add("File:>Export Type",                _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   _tNoCallbacks).
        Add("File:>---",                        _nIconID,   -_bEnabled,   -_bChecked,   -_bCheckable,   _tNoCallbacks).
        Add("File:>Exit",                       _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   {[eMenu.OnSelected] = function(tItem)
            Application.Exit(0); --TODO check for savability
        end});
--[[
██████╗  █████╗ ███╗   ███╗███████╗
██╔════╝ ██╔══██╗████╗ ████║██╔════╝
██║  ███╗███████║██╔████╔██║█████╗
██║   ██║██╔══██║██║╚██╔╝██║██╔══╝
╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗
╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝ ]]
TheMenu.Add("Game",           _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Game:>New",      _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   {[eMenu.OnSelected] = function(tItem)
            NewGame(); --TODO check for savability
        end}).
        Add("Game:>---",      _nIconID,   -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Game:>Load",     _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Game:>---",      _nIconID,   -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Game:>Browse",   _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks);
--[[
███████╗███████╗████████╗
██╔════╝██╔════╝╚══██╔══╝
███████╗█████╗     ██║
╚════██║██╔══╝     ██║
███████║███████╗   ██║
╚══════╝╚══════╝   ╚═╝   ]]
TheMenu.Add("CardSet",           _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("CardSet:>New",      _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("CardSet:>---",      _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("CardSet:>Load",     _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("CardSet:>Save",     _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   {[eMenu.OnSelected] = function() ProcSys.SaveCSVs(); end}).
        Add("CardSet:>---",      _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("CardSet:>Browse",   _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("CardSet:>---",      _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("CardSet:>Edit CSV", _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   {[eMenu.OnSelected] = function()
            local oCardSet = ProcSys.GetActiveCardSet();

            if (type(oCardSet) == "CardSet") then
                local pCSV = oCardSet.GetDataPath();
                File.Open(pCSV, "", SW_SHOWNORMAL);
            end

        end});

--[[
███████╗██╗██╗  ████████╗███████╗██████╗ ███████╗
██╔════╝██║██║  ╚══██╔══╝██╔════╝██╔══██╗██╔════╝
█████╗  ██║██║     ██║   █████╗  ██████╔╝███████╗
██╔══╝  ██║██║     ██║   ██╔══╝  ██╔══██╗╚════██║
██║     ██║███████╗██║   ███████╗██║  ██║███████║
╚═╝     ╚═╝╚══════╝╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝]]
TheMenu.Add("Filters",          _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks);

--[[
 ██████╗ ██████╗ ████████╗██╗ ██████╗ ███╗   ██╗███████╗
██╔═══██╗██╔══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
██║   ██║██████╔╝   ██║   ██║██║   ██║██╔██╗ ██║███████╗
██║   ██║██╔═══╝    ██║   ██║██║   ██║██║╚██╗██║╚════██║
╚██████╔╝██║        ██║   ██║╚██████╔╝██║ ╚████║███████║
╚═════╝ ╚═╝        ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ]]
TheMenu.Add("Options",      _nIconID,       _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks);

--[[
████▄  ▄▄▄▄   ▄▄▄  ▄▄   ▄▄
██  ██ ██▄█▄ ██▀██ ██ ▄ ██
████▀  ██ ██ ██▀██  ▀█▀█▀  ]]
_sSection     = "Options";

local sOD  = "Options:>Draw";
local sUO  = "Utility Overlay";
local sUOO = "UTILITY OVERLAY OPTIONS";
local sHRE = "Horizontal Ruler";
local sVRE = "Vertical Ruler";
local sHCE = "Horizontal Centerline";
local sVCE = "Vertical Centerline";
local sESC = "Export Selected Card"; --TODO REMOVE THIS!!!!!!!!
--local sRCC = "Redraw On Cell Changed";
local sDSP = "---";

TheMenu.Add(sOD,                 _nIconID,       _bEnabled,     -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sUO,     _nIconID,       _bEnabled,     LoadB(sUO:collapse()),           _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sUO:collapse(),  tItem.IsChecked); Forge.SetUtilVisible(tItem.IsChecked); end}).
        Add(sOD.._sSub..sDSP,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sUOO,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sDSP,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sHRE,    _nIconID,       _bEnabled,     LoadB(sHRE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sHRE:collapse(), tItem.IsChecked); Forge.RequestUtilRedraw(); end}).
        Add(sOD.._sSub..sVRE,    _nIconID,       _bEnabled,     LoadB(sVRE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sVRE:collapse(), tItem.IsChecked); Forge.RequestUtilRedraw(); end}).
        Add(sOD.._sSub..sHCE,    _nIconID,       _bEnabled,     LoadB(sHCE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sHCE:collapse(), tItem.IsChecked); Forge.RequestUtilRedraw(); end}).
        Add(sOD.._sSub..sVCE,    _nIconID,       _bEnabled,     LoadB(sVCE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sVCE:collapse(), tItem.IsChecked); Forge.RequestUtilRedraw(); end}).
        Add(sOD.._sSub..sDSP,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sESC,    _nIconID,       _bEnabled,     LoadB(sESC:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sESC:collapse(), tItem.IsChecked) end}).
        Add(sOD.._sSub..sDSP,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks);
        --Add(sOD.._sSub..sRCC,    _nIconID,       _bEnabled,     LoadB(sRCC:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sRCC:collapse(), tItem.IsChecked) end});
        --TODO add disable UTIL canvas here and move export somewhere else


--[[
████████╗ ██████╗  ██████╗ ██╗     ███████╗
╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
   ██║   ██║   ██║██║   ██║██║     ███████╗
   ██║   ██║   ██║██║   ██║██║     ╚════██║
   ██║   ╚██████╔╝╚██████╔╝███████╗███████║
   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝]]
TheMenu.Add("Tools:>Rebuild Dox",      _nIconID,       -_bEnabled,     -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) Log.ClearWindow(); ProcessDox(Game.GetActive().GetName()) end}).
        Add("Tools:>Style Editor",     _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("Style Editor",       false, nil, nil); end}).  --TODO save coords
        Add("Tools:>Mechanics Viewer", _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("Mechanics Viewer",   false, nil, nil); end}).  --TODO save coords
        Add("Tools:>---",              _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks);


--[[
██╗    ██╗██╗███╗   ██╗██████╗  ██████╗ ██╗    ██╗
██║    ██║██║████╗  ██║██╔══██╗██╔═══██╗██║    ██║
██║ █╗ ██║██║██╔██╗ ██║██║  ██║██║   ██║██║ █╗ ██║
██║███╗██║██║██║╚██╗██║██║  ██║██║   ██║██║███╗██║
╚███╔███╔╝██║██║ ╚████║██████╔╝╚██████╔╝╚███╔███╔╝
 ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝  ╚══╝╚══╝ ]]
TheMenu.Add("Window",                   _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Window:>Base Data",        _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] =
        function(tItem)
            ProcSys.SetWindowVisible(PANE.DATA_EDIT, true);
            _sSection = "DATA_EDIT";
            Save("Visible", "true");
        end}).
        Add("Window:>Final Data",       _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] =
        function(tItem)
            ProcSys.SetWindowVisible(PANE.DATA_VIEW, true);
            _sSection = "DATA_VIEW";
            Save("Visible", "true");
        end}).
        Add("Window:>---",              _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Window:>Log",              _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) Log.Show(); end}).  --TODO save coords
        Add("Window:>Clear Log Window", _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) Log.ClearWindow(); end});

--TODO ADD game website and author stuff...
--[[
██╗  ██╗███████╗██╗     ██████╗
██║  ██║██╔════╝██║     ██╔══██╗
███████║█████╗  ██║     ██████╔╝
██╔══██║██╔══╝  ██║     ██╔═══╝
██║  ██║███████╗███████╗██║
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ]]
TheMenu.Add("Help",                     _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Help:>Game Documentation", _nIconID,       -_bEnabled,     -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.Open(FS.Game.."\\Docs\\"..DOX_EXPORT_FILENAME..".html", "", SW_SHOWNORMAL); end}).
        Add("Help:>Draw API",           _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.Open(_Docs.."\\Draw.chm", "", SW_SHOWNORMAL); end}).
        Add("Help:>---",                _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Help:>Tutorials",          _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.Open(FS.AppDir.."\\index.html", "", SW_SHOWNORMAL); end}).
        Add("Help:>---",                _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Help:>Patreon",            _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.OpenURL(APP_PATREON,   SW_SHOWNORMAL); end}).
        Add("Help:>GitHub",             _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.OpenURL(APP_GITHUB,    SW_SHOWNORMAL); end}).
        Add("Help:>Visit Website",      _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.OpenURL(APP_WEBSITE,   SW_SHOWNORMAL); end}).
        Add("Help:>---",                _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Help:>License",            _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("License", true, nil, nil); end}).
        Add("Help:>About",              _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("About", true, nil, nil); end});--TODO

TheMenu.SetAutoUpdate(true);
TheMenu.Refresh();

local tSupport;
tSupport = {
    RefreshGameExporters = function(sPage)--TODO FIX FINISH USE the Game class to help with this
        --clear the games list
        TheMenu.ClearChildren("File:>Export");

        for _, sExporter in Exporter.GetAllNames() do
            TheMenu.Add("File:>Export Type:>"..tExporter.Name, _nIconID, _bEnabled, LoadB(sValueName), _bCheckable, {
                [eMenu.OnSelected] = function(tItem)
                    --Exporter.SetActiveType(eExporter);
                    --Save(sValueName, tostring(tItem.IsSelected));
                end
        },
        _nExportRadioGroupID);
        end

        TheMenu.Refresh();
    end,
    RefreshGamesList = function(sPage)--TODO FIX FINISH USE the Game class to help with this
        --clear the games list
        TheMenu.ClearChildren("Game:>Load");

        for _, oGame in ipairs(Game.GetAll()) do
            local sGame = oGame.GetName();

            local sMenuPath = "Game:>Load:>"..sGame;
                TheMenu.Add(sMenuPath, _nIconID, _bEnabled, not _bChecked, not _bCheckable, {
                    [eMenu.OnSelected] = function(tItem)
                        --TODO check that the current Game isn't loaded first and that there are no unssaved changes
                        Game.Activate(oGame);
                        Page.Jump("Forge");
                    end
            });
        end

        TheMenu.Refresh();
    end,
    RereshCardSetsList = function(sPage)
        --clear the cards list
        TheMenu.ClearChildren("CardSet:>Load");

        --get all the CardSet folders
        local tCardSets = Game.GetActive().GetAllCardSets();

        for _, oCardSet in ipairs(tCardSets) do
            local sCardSet      = oCardSet.GetName();
            local sMenuPath = "CardSet:>Load:>"..sCardSet;
            TheMenu.Add(sMenuPath, _nIconID, _bEnabled, not _bChecked, not _bCheckable, _tNoCallbacks);


            TheMenu.SetCallback(sMenuPath, Menu.EVENT.OnSelected, function(tItem)
                ProcSys.LoadCardSet(oCardSet);
                INIFile.SetValue(FS.Info, "SESSION", "LastCardSet", oCardSet.GetUUID());
            end);

        end

    end,
    OnPreload = function(sPage)
        local sWindow = "Window".._sSub;

        if (sPage == "Welcome") then
            tSupport.RefreshGamesList();
            --options:>draw items
            TheMenu.SetEnabled(sOD.._sSub..sUO,             false);
            --TheMenu.SetEnabled(sOD.._sSub..sUOO,            false);
            TheMenu.SetEnabled(sOD.._sSub..sHRE,            false);
            TheMenu.SetEnabled(sOD.._sSub..sVRE,            false);
            TheMenu.SetEnabled(sOD.._sSub..sHCE,            false);
            TheMenu.SetEnabled(sOD.._sSub..sVCE,            false);
            TheMenu.SetEnabled(sOD.._sSub..sESC,            false);
            --TheMenu.SetEnabled(sOD.._sSub..sRCC,            false);
            --Game items
            TheMenu.SetEnabled("Game:>Browse",              false);
            --card set items
            TheMenu.SetEnabled("CardSet:>New",             false);
            TheMenu.SetEnabled("CardSet:>Load",            false);
            --tools items
            TheMenu.SetEnabled("Tools:>Rebuild Dox",        false);
            TheMenu.SetEnabled("Tools:>Style Editor",       false);
            TheMenu.SetEnabled("Tools:>Mechanics Viewer",   false);
            --help items
            TheMenu.SetEnabled("Help:>Game Documentation",  false);
            --window items
            TheMenu.SetEnabled(sWindow.."Base Data",        false);
            TheMenu.SetEnabled(sWindow.."Final Data",       false);
            --TheMenu.Refresh();

        elseif (sPage == "Forge") then
            --options:>draw items
            TheMenu.SetEnabled(sOD.._sSub..sUO,             true);
            --TheMenu.SetEnabled(sOD.._sSub..sUOO,            true);
            TheMenu.SetEnabled(sOD.._sSub..sHRE,            true);
            TheMenu.SetEnabled(sOD.._sSub..sVRE,            true);
            TheMenu.SetEnabled(sOD.._sSub..sHCE,            true);
            TheMenu.SetEnabled(sOD.._sSub..sVCE,            true);
            TheMenu.SetEnabled(sOD.._sSub..sESC,            true);
            --TheMenu.SetEnabled(sOD.._sSub..sRCC,            true);
            --Game items
            TheMenu.SetEnabled("Game:>Load:>".._sGame,      false);
            TheMenu.SetEnabled("Game:>Browse",              true);
            TheMenu.SetCallback("Game:>Browse", eMenu.OnSelected, function(tItem) Shell.Execute(FS.Game, "open", "", "", SW_SHOWNORMAL); end);
            --card set items
            TheMenu.SetEnabled("CardSet:>New",             true);
            TheMenu.SetEnabled("CardSet:>Load",            true);
            TheMenu.SetCallback("CardSet:>Browse", eMenu.OnSelected, function(tItem) Shell.Execute(FS.CardSets.."\\"..INIFile.GetValue(FS.Info, "SESSION", "LastCardSet"), "open", "", "", SW_SHOWNORMAL); end); --TODO GET ACTIVE SET
            --tools items
            TheMenu.SetEnabled("Tools:>Rebuild Dox",        true);
            TheMenu.SetEnabled("Tools:>Style Editor",       true);
            TheMenu.SetEnabled("Tools:>Mechanics Viewer",   true);
            --help items
            TheMenu.SetEnabled("Help:>Game Documentation",  true);
            --window items
            TheMenu.SetEnabled(sWindow.."Base Data",        true);
            TheMenu.SetEnabled(sWindow.."Final Data",       true);

            tSupport.RereshCardSetsList();
            --TheMenu.Refresh();
        end

    end,
};
local tMeta = {
    __index = function(t, k)

        if tSupport[k] ~= nil then  --try the Menu class first
            return tSupport[k];

        end

        return TheMenu[k];
    end,
};
local tDecoy = {};

setmetatable(tDecoy, tMeta);

return tDecoy;
