local class     = class;
local math      = math;
local pairs     = pairs;
local rawtype   = rawtype;
    local abs   = math.abs;
local tostring  = tostring;
local tonumber  = tonumber;
local GetValue  = INIFile.GetValue
local GameUtil  = require("Game.GameUtil");
local File      = File;
local Folder    = Folder;

return class("CardSet",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --CardSet = function(this, sAuthCode) end, --static constructor (runs after class object creation)
    },
    {--PRIVATE
        CardWidth__AUTOR_   = null,
        CardHeight__AUTOR_  = null,
        DataPath__AUTOR_    = null,
        DrawPath__AUTOR_    = null,
        InfoPath__AUTOR_    = null,
        RowProcPath__AUTOR_ = null,
        Name__AUTOA_        = '',
        Path__AUTOR_        = null,
        UUID__AUTOR_        = null,
    },
    {--PROTECTED

    },
    {--PUBLIC
        CardSet = function(this, cdat, pFolder)
            local pri = cdat.pri;

            --validate the input string and ensure it leads to a valid directory
            if not (rawtype(pFolder) == "string" and Folder.DoesExist(pFolder)) then
                error("Invalid CardSet: CardSet path must lead to an existing directory.", 3);
            end

            local pData         = pFolder.."\\"..FILESPEC_CARDSET_DATA.Full;
            local pDrawPath     = pFolder.."\\"..FILESPEC_CARDSET_DRAW.Full;
            local pInfo         = pFolder.."\\"..FILESPEC_CARDSET_INFO.Full;
            local pRowProcPath  = pFolder.."\\"..FILESPEC_CARDSET_ROWPROC.Full;

            local tCheckFiles = {pDrawPath, pData, pInfo, pRowProcPath};

            for _, pFile in pairs(tCheckFiles) do

                if not (File.DoesExist(pFile)) then
                    error("Invalid Card Set: missing expected file at \""..pFile..".\"");
                end

            end

            --TODO SPECIAL COLUMNS!!!
            local sUUID         = GameUtil.ValidateObjectFolder(pFolder, "CardSet");
            local sName         = GameUtil.ValidateObjectName(pFolder, "CardSet");
            local nCardWidth    = tonumber(GetValue(pFolder.."\\Info.ini", "SETTINGS", "CardWidth"));
            local nCardHeight   = tonumber(GetValue(pFolder.."\\Info.ini", "SETTINGS", "CardHeight"));

            if (not nCardWidth) then
                error("Invalid ${type}: Malformed ${type} INI file at ${path}. Missing \"CardWidth\" value or non-numeric value given." % {path = pFolder, type = sType}, 2);
            end

            if (not nCardHeight) then
                error("Invalid ${type}: Malformed ${type} INI file at ${path}. Missing \"CardHeight\" value or non-numeric value given." % {path = pFolder, type = sType}, 2);
            end

            --set the game's info
            pri.DataPath    = pData;
            pri.DrawPath    = pDrawPath;
            pri.InfoPath    = pInfo;
            pri.RowProcPath = pRowProcPath;
            pri.Name        = sName;
            pri.Path        = pFolder;
            pri.UUID        = sUUID;
            pri.CardWidth   = abs(nCardWidth);
            pri.CardHeight  = abs(nCardHeight);
        end,
        GetCardSize = function(this, cdat)
            local pri = cdat.pri;
            return {Width = pri.CardWidth, Height = pri.CardHeight};
        end,
    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
