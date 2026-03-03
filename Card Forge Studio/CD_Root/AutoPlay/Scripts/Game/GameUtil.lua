return class("Util",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Util = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        --[[
            @fqxn   CFS.ValidateObjectName
            @desc   Reads and validates the display name for a folder-backed object (Game/CardSet/etc.).
                    Looks up "Name" under [SETTINGS] in "<Folder>\Info.ini".
                    Throws if the value is missing/empty.
            @param  pFolder (string) Absolute path to the object folder.
            @param  sType   (string) Human-readable type label used in error messages (e.g. "Game", "CardSet").
            @return (string) The validated name string from the INI.
            @error  Raised when the INI value is missing or empty.
        ]]
        ValidateObjectName = function(pFolder, sType)

            local sName = INIFile.GetValue(pFolder.."\\Info.ini", "SETTINGS", "Name");

            if (sName:isempty()) then
                error("Invalid ${type}: Malformed ${type} INI file at ${path}. Missing \"Name\" value." % {path = pFolder, type = sType}, nErrorLevel);
            end

            return sName;
        end,


        ValidateObjectFolder = function(pFolder, sType)
            local nErrorLevel = 4;

            --get and validate the game's uuid
            local sUUID = io.getenddir(pFolder);

            if not (sUUID:isuuid()) then
                error("Invalid ${type}: ${type} directory must be named a valid uuid string. Got \"${folder}\" at path\r\n\"${path}.\"" % {folder = sUUID, path = pFolder, type = sType}, nErrorLevel);
            end

            return sUUID;
        end,
    },
    {--PRIVATE

    },
    {--PROTECTED

    },
    {--PUBLIC
        Util = function(this, cdat)--, super)

        end,
    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
