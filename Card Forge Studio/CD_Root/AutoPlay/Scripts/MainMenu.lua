local eMenu         = Menu.EVENT;
local _sSection     = "";
local _pINI         = "";
local _sSub         = ":>";

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

local _nIconID = -1;
local _bEnabled, _bChecked, _bCheckable = true, true, true;
local _tNoCallbacks = nil;
--local _tGamePaths   = {};
--local _tSetPaths    = {};


--[[
███████╗██╗██╗     ███████╗
██╔════╝██║██║     ██╔════╝
█████╗  ██║██║     █████╗
██╔══╝  ██║██║     ██╔══╝
██║     ██║███████╗███████╗
╚═╝     ╚═╝╚══════╝╚══════╝  ]]
TheMenu.Add("File",          _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   _tNoCallbacks).
        --Add("File:>New",     _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   _tNoCallbacks).
        --Add("File:>---",     _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   _tNoCallbacks).
        Add("File:>Exit",    _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   {[eMenu.OnSelected] = function(tItem)
            Application.Exit(0); --TODO check for savability
        end});


--[[
██████╗ ██████╗  ██████╗      ██╗███████╗ ██████╗████████╗
██╔══██╗██╔══██╗██╔═══██╗     ██║██╔════╝██╔════╝╚══██╔══╝
██████╔╝██████╔╝██║   ██║     ██║█████╗  ██║        ██║
██╔═══╝ ██╔══██╗██║   ██║██   ██║██╔══╝  ██║        ██║
██║     ██║  ██║╚██████╔╝╚█████╔╝███████╗╚██████╗   ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚════╝ ╚══════╝ ╚═════╝   ╚═╝  ]]
TheMenu.Add("Project",           _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Project:>New",      _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   {[eMenu.OnSelected] = function(tItem)
            NewGame(); --TODO check for savability
        end}).
        Add("Project:>Load",     _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Project:>Browse",   _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks);
--[[
███████╗███████╗████████╗
██╔════╝██╔════╝╚══██╔══╝
███████╗█████╗     ██║
╚════██║██╔══╝     ██║
███████║███████╗   ██║
╚══════╝╚══════╝   ╚═╝   ]]
TheMenu.Add("Set",           _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Set:>New",      _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Set:>Load",     _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Set:>Save",     _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   {[eMenu.OnSelected] = function() ProcSys.SaveCSVs(); end}).
        Add("Set:>Browse",   _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks);
        --Add("Set:>Save",     _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks);

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
_pINI         = FS.AppCFG;

local sOD  = "Options:>Draw";
local sHRE = "Horizontal Ruler Enabled";
local sVRE = "Vertical Ruler Enabled";
local sHCE = "Horizontal Centerline Enabled";
local sVCE = "Vertical Centerline Enabled";
local sOE  = "Overlay Enabled";
local sBE  = "Border Enabled";
local sESC = "Export Selected Card";
local sRCC = "Redraw On Cell Changed";
--; UserEnv.ProcSysUpdateRoot {_bDrawOverlay = -tItem.IsChecked};
--; UserEnv.ProcSysUpdateRoot {_bDrawOverlay = -tItem.IsChecked};
TheMenu.Add(sOD,                 _nIconID,       _bEnabled,    -_bChecked,                      -_bCheckable,    _tNoCallbacks).
        Add(sOD.._sSub..sHRE,    _nIconID,       _bEnabled,     LoadB(sHRE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sHRE:collapse(), -tItem.IsChecked) end}).
        Add(sOD.._sSub..sVRE,    _nIconID,       _bEnabled,     LoadB(sVRE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sVRE:collapse(), -tItem.IsChecked) end}).
        Add(sOD.._sSub..sHCE,    _nIconID,       _bEnabled,     LoadB(sHCE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sHCE:collapse(), -tItem.IsChecked) end}).
        Add(sOD.._sSub..sVCE,    _nIconID,       _bEnabled,     LoadB(sVCE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sVCE:collapse(), -tItem.IsChecked) end}).
        Add(sOD.._sSub..sOE,     _nIconID,       _bEnabled,     LoadB(sOE:collapse()),           _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sOE:collapse(),  -tItem.IsChecked) end}).
        Add(sOD.._sSub..sBE,     _nIconID,       _bEnabled,     LoadB(sBE:collapse()),           _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sBE:collapse(),  -tItem.IsChecked) end}).
        Add(sOD.._sSub..sESC,    _nIconID,       _bEnabled,     LoadB(sESC:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sESC:collapse(), -tItem.IsChecked) end}).
        Add(sOD.._sSub..sRCC,    _nIconID,       _bEnabled,     LoadB(sRCC:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sRCC:collapse(), -tItem.IsChecked) end});


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
        Add("Window:>Style Editor",     _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("Style Editor",       false, nil, nil); end}).  --TODO save coords
        Add("Window:>Mechanics Viewer", _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("Mechanics Viewer",   false, nil, nil); end})   --TODO save coords



--[[
██╗  ██╗███████╗██╗     ██████╗
██║  ██║██╔════╝██║     ██╔══██╗
███████║█████╗  ██║     ██████╔╝
██╔══██║██╔══╝  ██║     ██╔═══╝
██║  ██║███████╗███████╗██║
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ]]
TheMenu.Add("Help",                     _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Help:>Documentation",      _nIconID,       -_bEnabled,     -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.Open(FS.Game.."\\Docs\\"..Game.GetActive().GetName().." API.html", "", SW_SHOWNORMAL); end}).
        Add("Help:>Tutorials",          _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.Open(FS.AppDir.."\\index.html", "", SW_SHOWNORMAL); end}).
        Add("Help:>Visit Website",      _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.OpenURL("https://www.cardforge.studio/", SW_SHOWNORMAL); end}).
        Add("Help:>---",                _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Help:>License",            _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("License", true, nil, nil); end}).
        --Add("Help:>---",                _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Help:>About",              _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) end});--TODO

TheMenu.SetAutoUpdate(true);
TheMenu.Refresh();

local tSupport;
tSupport = {
    RefreshGamesList = function(sPage)--TODO FIX FINISH USE the Game class to help with this
        --clear the games list
        TheMenu.ClearChildren("Project:>Load");

        for _, oGame in ipairs(Game.GetAll()) do
            local sGame = oGame.GetName();

            local sMenuPath = "Project:>Load:>"..sGame;
                TheMenu.Add(sMenuPath, _nIconID, _bEnabled, not _bChecked, not _bCheckable, {
                    [eMenu.OnSelected] = function(tItem)
                        --TODO check that the current project isn't loaded first and that there are no unssaved changes
                        Game.Prep(sGame);
                        Page.Jump("Forge");
                    end
            });
        end

        TheMenu.Refresh();
    end,
    RereshSetsList = function(sPage)--TODO FIX FINISH USE the Game class to help with this
        --clear the cards list
        TheMenu.ClearChildren("Set:>Load");

        --get all the set folders
        local tCardSets = Game.GetActive().GetAllCardSets();

        for _, oCardSet in ipairs(tCardSets) do
            --local bIsValid, sSetID = ProcSys.SetIsValid(pSet);
                local sSet      = oCardSet.GetName();
                local sMenuPath = "Set:>Load:>"..sSet;
                TheMenu.Add(sMenuPath, _nIconID, _bEnabled, not _bChecked, not _bCheckable, _tNoCallbacks);
                --_tSetPaths[sSet] = pSet; --TODO QUESTION FOR WHAT IS THIS BEING USED?

                TheMenu.SetCallback(sMenuPath, Menu.EVENT.OnSelected, function(tItem)
                    ProcSys.LoadCardSet(oCardSet);
                    INIFile.SetValue(FS.Info, "SESSION", "LastSet", oCardSet.GetUUID());
                end);

        end

    end,
    OnPreload = function(sPage)
        local sWindow = "Window".._sSub;

        if (sPage == "Welcome") then
            tSupport.RefreshGamesList();
            --options:>draw items
            TheMenu.SetEnabled(sOD.._sSub..sHRE,            false);
            TheMenu.SetEnabled(sOD.._sSub..sVRE,            false);
            TheMenu.SetEnabled(sOD.._sSub..sHCE,            false);
            TheMenu.SetEnabled(sOD.._sSub..sVCE,            false);
            TheMenu.SetEnabled(sOD.._sSub..sOE,             false);
            TheMenu.SetEnabled(sOD.._sSub..sBE,             false);
            TheMenu.SetEnabled(sOD.._sSub..sESC,            false);
            TheMenu.SetEnabled(sOD.._sSub..sRCC,            false);
            --project items
            TheMenu.SetEnabled("Project:>Browse",           false);
            --set items
            TheMenu.SetEnabled("Set:>New",                  false);
            TheMenu.SetEnabled("Set:>Load",                 false);
            --TheMenu.SetEnabled("Set:>Save",               false);
            TheMenu.SetEnabled("Help:>Documentation",       false);
            --window items
            TheMenu.SetEnabled(sWindow.."Base Data",        false);
            TheMenu.SetEnabled(sWindow.."Final Data",       false);
            TheMenu.SetEnabled(sWindow.."Style Editor",     false);
            TheMenu.SetEnabled(sWindow.."Mechanics Viewer", false);
            --TheMenu.Refresh();

        elseif (sPage == "Forge") then
            --options:>draw items
            TheMenu.SetEnabled(sOD.._sSub..sHRE,            true);
            TheMenu.SetEnabled(sOD.._sSub..sVRE,            true);
            TheMenu.SetEnabled(sOD.._sSub..sHCE,            true);
            TheMenu.SetEnabled(sOD.._sSub..sVCE,            true);
            TheMenu.SetEnabled(sOD.._sSub..sOE,             true);
            TheMenu.SetEnabled(sOD.._sSub..sBE,             true);
            TheMenu.SetEnabled(sOD.._sSub..sESC,            true);
            TheMenu.SetEnabled(sOD.._sSub..sRCC,            true);
            --project items
            TheMenu.SetEnabled("Project:>Load:>".._sGame,   false);
            TheMenu.SetEnabled("Project:>Browse",           true);
            TheMenu.SetCallback("Project:>Browse", eMenu.OnSelected, function(tItem) Shell.Execute(FS.Game, "open", "", "", SW_SHOWNORMAL); end);
            --set items
            TheMenu.SetEnabled("Set:>New",                  true);
            TheMenu.SetEnabled("Set:>Load",                 true);
            TheMenu.SetEnabled("Help:>Documentation",       true);
            --window items
            TheMenu.SetEnabled(sWindow.."Base Data",        true);
            TheMenu.SetEnabled(sWindow.."Final Data",       true);
            TheMenu.SetEnabled(sWindow.."Style Editor",     true);
            TheMenu.SetEnabled(sWindow.."Mechanics Viewer", true);

            tSupport.RereshSetsList();
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
