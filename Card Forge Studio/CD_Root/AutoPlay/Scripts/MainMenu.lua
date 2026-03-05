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
TheMenu.Add("Card Set",           _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Card Set:>New",      _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Card Set:>---",      _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Card Set:>Load",     _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Card Set:>Save",     _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   {[eMenu.OnSelected] = function() ProcSys.SaveCSVs(); end}).
        Add("Card Set:>---",      _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Card Set:>Browse",   _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks);

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
local sUO  = "Utility Overlay";
local sUOO = "UTILITY OVERLAY OPTIONS";
local sHRE = "Horizontal Ruler";
local sVRE = "Vertical Ruler";
local sHCE = "Horizontal Centerline";
local sVCE = "Vertical Centerline";
local sESC = "Export Selected Card";
local sRCC = "Redraw On Cell Changed";
local sDSP = "---";

TheMenu.Add(sOD,                 _nIconID,       _bEnabled,     -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sUO,     _nIconID,       _bEnabled,     LoadB(sUO:collapse()),           _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sUO:collapse(),  tItem.IsChecked); ProcSys.ForceRedraw(); end}).
        Add(sOD.._sSub..sDSP,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sUOO,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sDSP,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sHRE,    _nIconID,       _bEnabled,     LoadB(sHRE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sHRE:collapse(), tItem.IsChecked); ProcSys.ForceRedraw(); end}).
        Add(sOD.._sSub..sVRE,    _nIconID,       _bEnabled,     LoadB(sVRE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sVRE:collapse(), tItem.IsChecked); ProcSys.ForceRedraw(); end}).
        Add(sOD.._sSub..sHCE,    _nIconID,       _bEnabled,     LoadB(sHCE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sHCE:collapse(), tItem.IsChecked); ProcSys.ForceRedraw(); end}).
        Add(sOD.._sSub..sVCE,    _nIconID,       _bEnabled,     LoadB(sVCE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sVCE:collapse(), tItem.IsChecked); ProcSys.ForceRedraw(); end}).
        Add(sOD.._sSub..sDSP,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sESC,    _nIconID,       _bEnabled,     LoadB(sESC:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sESC:collapse(), tItem.IsChecked) end}).
        Add(sOD.._sSub..sDSP,    _nIconID,       -_bEnabled,    -_bChecked,                      -_bCheckable,   _tNoCallbacks).
        Add(sOD.._sSub..sRCC,    _nIconID,       _bEnabled,     LoadB(sRCC:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sRCC:collapse(), tItem.IsChecked) end});
        --TODO add disable UTIL canvas here and move export somewhere else


--[[
████████╗ ██████╗  ██████╗ ██╗     ███████╗
╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
   ██║   ██║   ██║██║   ██║██║     ███████╗
   ██║   ██║   ██║██║   ██║██║     ╚════██║
   ██║   ╚██████╔╝╚██████╔╝███████╗███████║
   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝]]
TheMenu.Add("Tools:>Rebuild Dox",        _nIconID,       -_bEnabled,     -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) Log.ClearWindow(); ProcessDox(Game.GetActive().GetName()) end});


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
        Add("Help:>Documentation",      _nIconID,       -_bEnabled,     -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.Open(FS.Game.."\\Docs\\"..DOX_EXPORT_FILENAME..".html", "", SW_SHOWNORMAL); end}).
        Add("Help:>Tutorials",          _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.Open(FS.AppDir.."\\index.html", "", SW_SHOWNORMAL); end}).
        Add("Help:>---",                _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Help:>Visit Website",      _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.OpenURL("https://www.cardforge.studio/", SW_SHOWNORMAL); end}).
        Add("Help:>License",            _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("License", true, nil, nil); end}).
        Add("Help:>About",              _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("About", true, nil, nil); end});--TODO

TheMenu.SetAutoUpdate(true);
TheMenu.Refresh();

local tSupport;
tSupport = {
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
        TheMenu.ClearChildren("Card Set:>Load");

        --get all the CardSet folders
        local tCardSets = Game.GetActive().GetAllCardSets();

        for _, oCardSet in ipairs(tCardSets) do
            local sCardSet      = oCardSet.GetName();
            local sMenuPath = "Card Set:>Load:>"..sCardSet;
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
            TheMenu.SetEnabled(sOD.._sSub..sRCC,            false);
            --Game items
            TheMenu.SetEnabled("Game:>Browse",              false);
            --card set items
            TheMenu.SetEnabled("Card Set:>New",             false);
            TheMenu.SetEnabled("Card Set:>Load",            false);
            --tools items
            TheMenu.SetEnabled("Tools:>Rebuild Dox",        false);
            --help items
            TheMenu.SetEnabled("Help:>Documentation",       false);
            --window items
            TheMenu.SetEnabled(sWindow.."Base Data",        false);
            TheMenu.SetEnabled(sWindow.."Final Data",       false);
            TheMenu.SetEnabled(sWindow.."Style Editor",     false);
            TheMenu.SetEnabled(sWindow.."Mechanics Viewer", false);
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
            TheMenu.SetEnabled(sOD.._sSub..sRCC,            true);
            --Game items
            TheMenu.SetEnabled("Game:>Load:>".._sGame,      false);
            TheMenu.SetEnabled("Game:>Browse",              true);
            TheMenu.SetCallback("Game:>Browse", eMenu.OnSelected, function(tItem) Shell.Execute(FS.Game, "open", "", "", SW_SHOWNORMAL); end);
            --card set items
            TheMenu.SetEnabled("Card Set:>New",             true);
            TheMenu.SetEnabled("Card Set:>Load",            true);
            TheMenu.SetCallback("Card Set:>Browse", eMenu.OnSelected, function(tItem) Shell.Execute(FS.CardSets.."\\"..INIFile.GetValue(FS.Info, "SESSION", "LastCardSet"), "open", "", "", SW_SHOWNORMAL); end); --TODO GET ACTIVE SET
            --tools items
            TheMenu.SetEnabled("Tools:>Rebuild Dox",        true);
            --help items
            TheMenu.SetEnabled("Help:>Documentation",       true);
            --window items
            TheMenu.SetEnabled(sWindow.."Base Data",        true);
            TheMenu.SetEnabled(sWindow.."Final Data",       true);
            TheMenu.SetEnabled(sWindow.."Style Editor",     true);
            TheMenu.SetEnabled(sWindow.."Mechanics Viewer", true);

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
