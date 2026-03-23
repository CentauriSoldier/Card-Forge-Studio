--[[TODO DOX
    @section Exporter Targets

    Core
        - Print & Play (sheet layout, bleed, cut lines)
        - Plain Image (per-card PNG/JPG)
        - CSV / JSON (data export)
        - TTS (Tabletop Simulator decks)

    Game Platforms
        - Tabletop Playground export
        - Screentop.gg export
        - PlayingCards.io export

    Print / Manufacturing
        - The Game Crafter format
        - MakePlayingCards format
        - PDF sheets (print-ready, embedded guides)

    Dev / Pipeline
        - Asset manifest (JSON index)
        - Atlas / spritesheet export
        - Unity import package

    Preview / Sharing
        - HTML preview site
        - Static gallery export
        - ZIP bundle (full pack)
]]
local bImplemented = true;
local _tExporters = {
    --Core
    [1] = {Name = "CSV",                    Implemented = -bImplemented,    ClassName = "ExporterCSV",                  Class = nil},
    [2] = {Name = "Lua",                    Implemented = -bImplemented,    ClassName = "ExporterLua",                  Class = nil},
    [3] = {Name = "JSON",                   Implemented = -bImplemented,    ClassName = "ExporterJSON",                 Class = nil},
    [4] = {Name = "Image",                  Implemented = bImplemented,     ClassName = "ExporterImage",                Class = nil},
    [5] = {Name = "Print & Play",           Implemented = -bImplemented,    ClassName = "ExporterPrintAndPlay",         Class = nil},
    --Game Platforms
    [6] = {Name = "PlayingCards.io",        Implemented = -bImplemented,    ClassName = "ExporterPlayingCardsIO",       Class = nil},
    [7] = {Name = "Screentop",              Implemented = -bImplemented,    ClassName = "ExporterScreentop",            Class = nil},
    [8] = {Name = "Tabletop Playground",    Implemented = -bImplemented,    ClassName = "ExporterTabletopPlayground",   Class = nil},
    [9] = {Name = "Table Top Simulator",    Implemented = -bImplemented,    ClassName = "ExporterTableTopSimulator",    Class = nil},
    --Print / Manufacturing
    [12] = {Name = "PDF Sheets",            Implemented = -bImplemented,    ClassName = "ExporterPDFSheets",            Class = nil},
    --Dev / Pipeline
    [13] = {Name = "Atlas",                 Implemented = -bImplemented,    ClassName = "ExporterAtlas",                Class = nil},
    [14] = {Name = "UnityPackage",          Implemented = -bImplemented,    ClassName = "ExporterUnityPackage",         Class = nil},
    --Preview / Sharing
    [15] = {Name = "HTML Preview",          Implemented = -bImplemented,    ClassName = "ExporterHTMLPreview",          Class = nil},
    [16] = {Name = "HTML Static Gallery",   Implemented = -bImplemented,    ClassName = "ExporterHTMLStaticGallery",    Class = nil},
    [17] = {Name = "ZIP",                   Implemented = -bImplemented,    ClassName = "ExporterZIP",                  Class = nil},
};

local function GetExporterEntryByClassName(sName)
    local tRet;

    for _, tExporter in ipairs(_tExporters) do

        if (tExporter.ClassName == sName) then
            tRet = tExporter;
            break;
        end

    end

    return tRet;
end

local _eActiveExporter;

Exporter = class("Exporter",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        __INIT = function(stapub)--static initializer (runs before class object creation)
            local tEnumNames    = {};
            local tEnumValues   = {};
            local nIndex        = 0;

            for _, tModule in ipairs(_tExporters) do

                if (tModule.Implemented) then
                    nIndex              = nIndex + 1;
                    tEnumNames[nIndex]  = tModule.Name:collapse();

                    local tEntryMeta    = {
                        __newindex = function(t, k, v)
                            error("Cannot write to read-only Exporter info table.", 3);
                        end,
                        __index = tModule,
                    };
                    local tEntryDecoy   = {};
                    setmetatable(tEntryDecoy, tEntryMeta);

                    tEnumValues[nIndex] = tEntryDecoy;
                end

            end

            stapub.TYPE = enum("Exporter.TYPE", tEnumNames, tEnumValues, true);
        end,
        --Exporter = function(cMe, sAuthCode)


        --end, --static constructor (runs after class object creation)
        GetActive = function()
            return _tExporters[_eActiveExporter];
        end,
        GetActiveType = function(eExporterType)
            return _eActiveExporter;
        end,
        GetAll = function()
            local tRet = {};

            --TODO
        end,
        SetActiveType = function(eExporterType)
            type.assert.custom(eExporterType, "Exporter.TYPE");
            _eActiveExporter = eExporterType;
        end,
    },
    {--PRIVATE

    },
    {--PROTECTED
        OutputPath  = "",
        PerRow      = true,
        Rows        = null;
        Exporter  = function(this, cdat, tRow, pOutput)

        end,
    },
    {},--PUBLIC
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);

--import all exporter classes
local sFileError = "Exporter.Init: Could not find any Exporter subclass files.";
local tExporters = File.Find(FS.Exporters.."\\", "*.lua", false, false, nil, nil);

if not (type(tExporters) == "table") then
    error(sFileError, 2);
end

if (#tExporters < 1) then
    error(sFileError, 2);
end

for _, pFile in pairs(tExporters) do
    local sModule   = String.SplitPath(pFile).Filename
    local tExporter = GetExporterEntryByClassName(sModule);

    if not (tExporter) then
        error("Exporter: could not load exporter module, \""..sModule.."\". No such exporter module whitelisted.", 2);
    end

    local cExporter = require("Exporters."..sModule);--TODO check class is good

    if not (class.isdirectchild(cExporter, Exporter)) then
        error("Exporter: Could not load Exporter module, \""..sModule.."\". - "..class.getname(cExporter).." must be a direct child of "..class.getname(Exporter));
    end

    tExporter.Class = cExporter;
end
