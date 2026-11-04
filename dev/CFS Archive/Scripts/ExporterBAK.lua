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
_tExportersMeta     = {};
_tExportersDecoy    = {};


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
]]



--[[
--Exporter object is created from user Exporter files

--User clicks Export->1/x:TYPE->1/x:Exporter


]]

local _tExporterSchema = schema.Record({
    Name        = schema.String,
    Class       = schema.String,
    RowHandler  = schema.Function,
    TestRow     = schema.Table,
});

local _tExporters = {};
local _eExporters;

--[[    _tExporters[sName] = {
        Class       = cCaller,
        Instances   = {},
        Returns     = {},
    };
]]

local function GetMenuName(sClass)
    return sClass:gsub("^Exporter", '');
end

local function BuildTypeEnum()
    --_eExporters = nil;
    local tEnumNames    = {};
    local tEnumValues   = {};
    local tTemp         = {};

    --create the list of enum names using the child class names
    for sType, tExporter in pairs(_tExporters) do
        tTemp[#tTemp + 1] = {
            Name    = sType, --TODO NOT CLASS, instance
            Value   = null,
        };

        --create the enum values (class objects)
        local tValues        = {};
        local tValuesDecoy   = {};
        local tValuesMeta    = {
            __newindex  = function() end, --TODO THROW ERROR
            __index     = tValues,
            __len       = function() return end,--TODO
        };
    end

    table.sort(tTemp,
        function(a, b)
            return a.Name < b.Name;
        end
    );

    --_eExporters = enum(tTemp, );
end

--local _eActiveExporter;
--NOTE on CodeColumns; DO NOT EXPORT, they are not designed for that nor will they be. Put that note in the Dox.

return class("Exporter",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        CATALOGUE = _eExporters,
        --__INIT = function(stapub) end--static initializer (runs before class object creation)
        --Exporter = function(cMe, sAuthCode) end, --static constructor (runs after class object creation)
        --[[GetActive = function()
            return _tExporters[_eActiveExporter];
        end,]]
        --[[GetAll = function()
            local tRet = {};

            for sName, oExporter in pairs(_tExporters) do
                tRet[sName] = oExporter;
            end

            return tRet;
        end,]]
        --[[GetMenuNames = function()--Used to build/access exporters subfolders
            local tRet = {};

            for sName, tExporter in pairs(_tExporters) do
                tRet[sName] = sName;
            end

            return tRet;
        end,]]
        RegisterChildClass = function(cCaller, sAuthCode, tReturns)
            type.assert.table(tReturns, "number", "table", 1); --there should be at least one return, a boolean if nothing else

            if not class.is(cCaller) then
                error("Exporter.RegisterChildClass: Argument 1 must be a class.", 2);
            end

            local cParent = class.getparent(cCaller);

            if not (cParent and class.getname(cParent) == "Exporter") then
                error("Exporter.RegisterChildClass: Argument 1 must be a child class of Exporter.", 2);
            end

            if not class.isstaticconstructorrunning(cCaller, sAuthCode) then
                error("Exporter.RegisterChildClass must be called from the static constructor of an Exporter child class.", 2);
            end

            local sClassName = class.getname(cCaller);

            if not sClassName:match("^Exporter[%w_]+$") then
                error("Exporter.RegisterChildClass: '"..sClassName.."' is an invalid class name. Must be 'Exporter<Something>'.", 2);
            end

            --create the base table entry for the child class in the _tExporters table
            _tExporters[sClassName] = {
                Class       = cCaller,                  --the actual class object
                Instances   = {},                       --instance repo for the class
                MenuName    = GetMenuName(sClassName),  --the name that will be shown in the Export menu
                Returns     = {},                       --the returns values of the class
            };

            local tRegistar     = _tExporters[sClassName];
            local tMyReturns    = tRegistar.Returns;

            --iterate over the strictly-ordered return table
            for nIndex, tReturn in ipairs(tReturns) do
                type.assert.table(tReturn, "number", "string", 1);
                local tMyReturn     = {};
                tMyReturns[nIndex]  = tMyReturn;

                --determine what types are allowed for this return index and store them
                for nTypeIndex, sType in ipairs(tReturn) do
                    type.assert.string(sType, "%S+", "Return type names must be non-blank strings");
                    tMyReturn[sType] = true;
                end

            end

        end,
        --[[SetActiveType = function(eExporterType)
            type.assert.custom(eExporterType, "Exporter.TYPE");
            _eActiveExporter = eExporterType;
        end,]]
    },
    {--PRIVATE
        MenuName__AUTOA_    = "",   --the name that will be shown in the Export menu
        Name__AUTOA_        = "",   --the user-given name of this exporter object
        Type                = "",   --the index of the table entry in _tExporters
        TypeData            = {},   --the table entry in _tExporters

        ValidateRowHandlerReturns = function(this, cdat, ...)
            local pro       = cdat.pro;
            local tReturns  = pro.TypeData.Returns;
            local tArgs     = {...};
            local nArgs     = select("#", ...);

            for nArg, tArgTypes in ipairs(tReturns) do
                local vArg      = tArgs[nArg];          -- may be nil (intentional)
                local sArgType  = type(vArg);
                local bFound    = false;

                for sType, bAllowed in pairs(tArgTypes) do

                    if (bAllowed and sArgType == sType) then
                        bFound = true;
                        break;
                    end

                end

                if not (bFound) then
                    local tAllowedTypes = {};

                    for sType, bAllowed in pairs(tArgTypes) do

                        if bAllowed then
                            tAllowedTypes[#tAllowedTypes + 1] = sType;
                        end

                    end

                    error("Exporter: "..pro.MenuName.."->"..pro.Name.." row handler return #"..nArg..
                          " must be one of {"..table.concat(tAllowedTypes, ", ").."}, got "..sArgType..".", 2);
                end

            end

            return true;
        end,
    },
    {--PROTECTED

        --OutputPath      = "",
        --PerRow          = true,
        --Returns         = {},
        --Rows            = null,
        --ScriptPath      = "",
        RowHandler        = null, --the actual exporter function that handles each row

        Exporter = function(this, cdat, tExporter)
            local vError = schema.CheckSchema(tExporter, _tExporterSchema);

            if (vError) then
                error("Error creating User Exporter:\r\n"..schema.FormatOutput(vError), 2);
            end

            local sName         = tExporter.Name;
            local sClass        = tExporter.Class;
            local tTestRow      = tExporter.TestRow;
            local fRowHandler   = tExporter.RowHandler;

            type.string.assert(sName, "%S+", "Error creating User Exporter:\r\nExporter name cannot be blank.", 2);

            if not (_tExporters[sClass]) then
                error("Error creating User Exporter:\r\n"..sClass.." is not a valid Exporter child class.", 2);
            end

            local pro = cdat.pro;

            pro.MenuName        = GetMenuName(sClass);
            pro.Name            = sName;
            pro.Type            = sClass;
            pro.RowHandler      = fRowHandler;
            pro.TypeData        = _tExporters[sClass];

            --validate the test row itself TODO FINISH COMPLETE THIS
            type.assert.table(tTestRow, nil, nil, 1, "Error creating User Exporter:\r\nTestRow must be a non-empty table.");

            --validate the exporter function against the test row
            local bSuccess = cdat.pri.ValidateRowHandlerReturns(fRowHandler(tTestRow));
            if bSuccess then

            local tInstances = _tExporters[sClass].Instances;

                if (tInstances[sName]) then
                    Log.Warning('Exporter "'..sName..'" of type '..sClass..' has been overwritten.');
                end

                tInstances[sName] = {
                    Instance = this,
                    Name     = sName,
                };

                --(re)build the TYPE enum
                BuildTypeEnum();
            end

        end,
        RefreshUserExporters = function() --assumes game is ready and running
            _tExporters = {};
        end,

    },
    {--PUBLIC
        Export = function(this, cdat)
            error(cdat.pro.Type.." has not implemented the public Export method.");
        end,
        SetRowHandler = function(this, cdat, fRowHandler)

        end,
    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
