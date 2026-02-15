local eMenu         = Menu.EVENT;
local _sSection     = "";
local _pINI         = "";

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
local _tGamePaths   = {};
local _tSetPaths    = {};


--[[
███████╗██╗██╗     ███████╗
██╔════╝██║██║     ██╔════╝
█████╗  ██║██║     █████╗
██╔══╝  ██║██║     ██╔══╝
██║     ██║███████╗███████╗
╚═╝     ╚═╝╚══════╝╚══════╝  ]]
TheMenu.Add("File",          _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   _tNoCallbacks).
        Add("File:>New",     _nIconID,   -_bEnabled,   -_bChecked,   -_bCheckable,   _tNoCallbacks).
        Add("File:>---",     _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   _tNoCallbacks).
        Add("File:>Exit",    _nIconID,   _bEnabled,    -_bChecked,   -_bCheckable,   _tNoCallbacks);

local function FileOnSelected(oItem)
    Application.Exit(0);
end

TheMenu.SetCallback("File:>Exit", Menu.EVENT.OnSelected, FileOnSelected);


--[[
██████╗ ██████╗  ██████╗      ██╗███████╗ ██████╗████████╗
██╔══██╗██╔══██╗██╔═══██╗     ██║██╔════╝██╔════╝╚══██╔══╝
██████╔╝██████╔╝██║   ██║     ██║█████╗  ██║        ██║
██╔═══╝ ██╔══██╗██║   ██║██   ██║██╔══╝  ██║        ██║
██║     ██║  ██║╚██████╔╝╚█████╔╝███████╗╚██████╗   ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚════╝ ╚══════╝ ╚═════╝   ╚═╝  ]]
TheMenu.Add("Project",           _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Project:>New",      _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Project:>Load",     _nIconID,   _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Project:>Browse",   _nIconID,   -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks);

--[[
███████╗███████╗████████╗
██╔════╝██╔════╝╚══██╔══╝
███████╗█████╗     ██║
╚════██║██╔══╝     ██║
███████║███████╗   ██║
╚══════╝╚══════╝   ╚═╝   ]]
TheMenu.Add("Set",           _nIconID,      -_bEnabled,     -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Set:>New",      _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Set:>Load",     _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Set:>Save",     _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Set:>---",      _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks).
        Add("Set:>Delete",   _nIconID,      _bEnabled,      -_bChecked,     -_bCheckable,   _tNoCallbacks);

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
_pINI         = _pAppCFG;

local sOD  = "Options:>Draw";
local sHRE = "Horizontal Ruler Enabled";
local sVRE = "Vertical Ruler Enabled";
local sHCE = "Horizontal Centerline Enabled";
local sVCE = "Vertical Centerline Enabled";
local sOE  = "Overlay Enabled";
local sBE  = "Border Enabled";
local sESC = "Export Selected Card";
local sRCC = "Redraw On Cell Changed";

TheMenu.Add(sOD,                _nIconID,       _bEnabled,      -_bChecked,                     -_bCheckable,   _tNoCallbacks).
        Add(sOD..":>"..sHRE,    _nIconID,       _bEnabled,     LoadB(sHRE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sHRE:collapse(), -tItem.IsChecked) end}).
        Add(sOD..":>"..sVRE,    _nIconID,       _bEnabled,     LoadB(sVRE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sVRE:collapse(), -tItem.IsChecked) end}).
        Add(sOD..":>"..sHCE,    _nIconID,       _bEnabled,     LoadB(sHCE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sHCE:collapse(), -tItem.IsChecked) end}).
        Add(sOD..":>"..sVCE,    _nIconID,       _bEnabled,     LoadB(sVCE:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sVCE:collapse(), -tItem.IsChecked) end}).
        Add(sOD..":>"..sOE,     _nIconID,       _bEnabled,     LoadB(sOE:collapse()),           _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sOE:collapse(),  -tItem.IsChecked) end}).
        Add(sOD..":>"..sBE,     _nIconID,       _bEnabled,     LoadB(sBE:collapse()),           _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sBE:collapse(),  -tItem.IsChecked) end}).
        Add(sOD..":>"..sESC,    _nIconID,       _bEnabled,     LoadB(sESC:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sESC:collapse(), -tItem.IsChecked) end}).
        Add(sOD..":>"..sRCC,    _nIconID,       _bEnabled,     LoadB(sRCC:collapse()),          _bCheckable,    {[eMenu.OnSelected] = function(tItem) Save(sRCC:collapse(), -tItem.IsChecked) end});


TheMenu.Add("Window",                   _nIconID,       -_bEnabled,     -_bChecked,                    -_bCheckable,  _tNoCallbacks).
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
        Add("Help:>Documentation",      _nIconID,       -_bEnabled,     -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.Open(_pGame.."\\Docs\\".._sGame.." API.html", "", SW_SHOWNORMAL); end}).
        Add("Help:>Visit Website",      _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) File.OpenURL("https://www.cardforge.studio/", SW_SHOWNORMAL); end}).
        Add("Help:>---",                _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks).
        Add("Help:>License",            _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) DialogEx.Show("License", true, nil, nil); end}).
        Add("Help:>---",                _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  _tNoCallbacks). --TODO BUG FIX not showing a second divider, fix this in Menu
        Add("Help:>About",              _nIconID,       _bEnabled,      -_bChecked,                    -_bCheckable,  {[eMenu.OnSelected] = function(tItem) end});--TODO

TheMenu.SetAutoUpdate(true);
TheMenu.Refresh();

local tSupport;
tSupport = {
    RefreshGamesList = function(sPage)
        --clear the card set list TODO FINISH
        local tGames = Folder.Find(_pGames.."\\", "*", false, nil);

        if (tGames) then
            table.sort(tGames, Path.SortByEndFolder); --sort by game name

            for nIndex, pFolder in ipairs(tGames) do
                local sGame = Path.GetEndFolder(pFolder);
                local sMenuPath = "Project:>Load:>"..sGame;
                TheMenu.Add(sMenuPath, _nIconID, _bEnabled, not _bChecked, not _bCheckable, _tNoCallbacks);
                _tGamePaths[sGame] = pFolder;

                TheMenu.SetCallback(sMenuPath, Menu.EVENT.OnSelected, function(tItem)
                    --TODO check that the current project isn't loaded frst and that there are no unssaved changes
                    PrepGame(pFolder);
                    Page.Jump("Forge");
                end)
            end

            TheMenu.Refresh();
        end

    end,
    RereshSetsList = function(sPage)
        --clear the card sets list TODO FINISH ALSO enable the other menu items GHOST current project item
        local tCardSets = File.Find(_pCSVSource.."\\", "*.csv", true, false, nil, nil);

        if (tCardSets) then
            table.sort(tCardSets, PathSorter); --sort by game name

            for nIndex, pFile in ipairs(tCardSets) do

                if not (pFile:find(".ignore")) then
                    local sSet  = Path.GetEndFolder(pFile);
                    local sMenuPath = "Set:>Load:>"..sSet;
                    TheMenu.Add(sMenuPath, _nIconID, _bEnabled, not _bChecked, not _bCheckable, _tNoCallbacks);
                    _tSetPaths[sSet] = pFile;

                    TheMenu.SetCallback(sMenuPath, Menu.EVENT.OnSelected, function(tItem)
                        ProcSys.LoadSet(pFile);
                        INIFile.SetValue(_pInfo, "SESSION", "LastSet", String.SplitPath(pFile).Filename);
                    end);
                end

            end
            --[[TODO LEFT OFF HERE
                            local tLoadSet      = _tFile.SubMenu[3];
                            tLoadSet.Enabled    = true;
                            tLoadSet.SubMenu    = {};
                            local nMenuIndex    = 1;

                            for nIndex, pFolder in ipairs(tCardSets) do
                                local sSet = Path.GetEndFolder(pFolder):gsub("%.[cC][sS][vV]$", '');

                                if not (pFolder:find(".ignore")) then

                                    tLoadSet.SubMenu[nMenuIndex] = {
                                        ID      = tLoadSet.ID + nMenuIndex,
                                        Text    = sSet,
                                        IconID  = -1,
                                        Enabled = true,
                                        Checked = false,
                                    };

                                    --local pLogo 		= pFolder.."\\"..sSet..".png";
                                    _tSetPaths[sSet] = pFolder;
                                    --tGameLogos[#tGameLogos + 1] = pLogo;
                                    nMenuIndex = nMenuIndex + 1;
                                end

                            end
            ]]
        end

    end,
    OnPreload = function(sPage)

        if (sPage == "Welcome") then
            tSupport.RefreshGamesList();
            TheMenu.SetEnabled("Options:>Draw",         false);
            TheMenu.SetEnabled("Set",                   false);--TODO clear sets
            TheMenu.SetEnabled("Window",                false);
            TheMenu.SetEnabled("Help:>Documentation",   false);
            --TheMenu.Refresh();

        elseif (sPage == "Forge") then
            TheMenu.SetEnabled("Options:>Draw",         true);
            TheMenu.SetEnabled("Set",                   true);
            TheMenu.SetEnabled("Window",                true);
            TheMenu.SetEnabled("Help:>Documentation",   true);
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
