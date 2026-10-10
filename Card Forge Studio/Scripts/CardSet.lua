--[[!
@fqxn CFS.Classes.CardSet
@desc Card-set metadata class with UUID ownership, creation, dimension access, and metadata refresh.
!]]

local class     = class;
local math      = math;
local rawtype   = rawtype;
local tonumber  = tonumber;

local GetValue = INIFile.GetValue;

return class("CardSet",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --[[!
        @fqxn CFS.Classes.CardSet.Methods.New
        @pulsarlua function CardSet.New
        @desc Creates a new card set with starter scripts, notes, metadata and PNG export defaults. Existing sets are never overwritten.
        @param string sGameUUID Owning game identifier.
        @param string sName Card-set display name.
        @param number nWidth Card width in pixels.
        @param number nHeight Card height in pixels.
        @return CardSet Created card set.
        !]]
        New = function(sGameUUID, sName, nWidth, nHeight)
            local sUUID = string.uuid(true);
            FS.CardSet.Create(sGameUUID, sUUID, sName, nWidth, nHeight);

            return require("CardSet")(sGameUUID, sUUID);
        end,
    },
    {--PRIVATE
        CardHeight              = null,
        CardWidth               = null,
                --[[!
        @fqxn CFS.Classes.CardSet.Methods.GetGameUUID
        @pulsarlua function CardSet.GetGameUUID
        @desc Returns the stored GameUUID value through the generated public accessor.
        @return any Stored GameUUID value.
        !]]
GameUUID__AUTOR_        = null,
                --[[!
        @fqxn CFS.Classes.CardSet.Methods.GetName
        @pulsarlua function CardSet.GetName
        @desc Returns the stored Name value through the generated public accessor.
        @return any Stored Name value.
        !]]
Name__AUTOA_            = '',
                --[[!
        @fqxn CFS.Classes.CardSet.Methods.GetUUID
        @pulsarlua function CardSet.GetUUID
        @desc Returns the stored UUID value through the generated public accessor.
        @return any Stored UUID value.
        !]]
UUID__AUTOR_            = null,
    },
    {--PROTECTED

    },
    {--PUBLIC
        --[[!
        @fqxn CFS.Classes.CardSet.Methods.CardSet
        @pulsarlua function CardSet
        @desc Loads and validates existing card-set metadata without changing its files.
        @param string sGameUUID Owning game identifier.
        @param string sUUID Card-set identifier.
        !]]
        CardSet = function(this, cdat, sGameUUID, sUUID)
            local pri = cdat.pri;

            if (rawtype(sGameUUID) ~= "string" or not sGameUUID:isuuid() or
                rawtype(sUUID) ~= "string" or not sUUID:isuuid()) then
                error("CardSet requires valid game and card-set UUIDs.", 2);
            end

            local pInfoINI = FS.CardSet.GetInfoINIPath(sGameUUID, sUUID);

            local nCardHeight = tonumber(GetValue(pInfoINI, "SETTINGS", "CardHeight"));
            local nCardWidth  = tonumber(GetValue(pInfoINI, "SETTINGS", "CardWidth"));
            local sName       = GetValue(pInfoINI, "SETTINGS", "Name");

            if (rawtype(sName) ~= "string" or not sName:match("%S") or sName:find("[%c]")) then
                error("Invalid card-set name in "..pInfoINI, 2);
            end

            if (not nCardWidth or nCardWidth <= 0 or nCardWidth >= math.huge or nCardWidth ~= math.floor(nCardWidth)) then
                error("Invalid CardSet: CardWidth must be a positive finite integer in "..pInfoINI, 2);
            end

            if (not nCardHeight or nCardHeight <= 0 or nCardHeight >= math.huge or nCardHeight ~= math.floor(nCardHeight)) then
                error("Invalid CardSet: CardHeight must be a positive finite integer in "..pInfoINI, 2);
            end

            pri.Name            = sName;
            pri.GameUUID        = sGameUUID:upper();
            pri.UUID            = sUUID:upper();
            pri.CardWidth       = nCardWidth;
            pri.CardHeight      = nCardHeight;
        end,


        --[[!
        @fqxn CFS.Classes.CardSet.Methods.GetCardHeight
        @pulsarlua function CardSet.GetCardHeight
        @desc Returns the card height in pixels.
        @return number Card height.
        !]]
        GetCardHeight = function(this, cdat)
            return cdat.pri.CardHeight;
        end,


        --[[!
        @fqxn CFS.Classes.CardSet.Methods.GetCardSize
        @pulsarlua function CardSet.GetCardSize
        @desc Returns the card dimensions in pixels.
        @return table Width and Height.
        !]]
        GetCardSize = function(this, cdat)
            local pri = cdat.pri;
            return {Width = pri.CardWidth, Height = pri.CardHeight};
        end,


        --[[!
        @fqxn CFS.Classes.CardSet.Methods.GetCardWidth
        @pulsarlua function CardSet.GetCardWidth
        @desc Returns the card width in pixels.
        @return number Card width.
        !]]
        GetCardWidth = function(this, cdat)
            return cdat.pri.CardWidth;
        end,


        --[[!
        @fqxn CFS.Classes.CardSet.Methods.RefreshInfo
        @pulsarlua function CardSet.RefreshInfo
        @desc Refreshes validated metadata and reports whether it changed.
        @return boolean Whether name or dimensions changed.
        !]]
        RefreshInfo = function(this, cdat)
            local pri         = cdat.pri;
            local pInfo       = FS.CardSet.GetInfoINIPath(pri.GameUUID, pri.UUID);
            local sName       = GetValue(pInfo, "SETTINGS", "Name");
            local nCardWidth  = tonumber(GetValue(pInfo, "SETTINGS", "CardWidth"));
            local nCardHeight = tonumber(GetValue(pInfo, "SETTINGS", "CardHeight"));

            assert(sName:match("%S"), "Card-set Name must not be blank.");
            assert(nCardWidth and nCardWidth > 0 and nCardWidth < math.huge and nCardWidth == math.floor(nCardWidth), "CardWidth must be a positive finite integer.");
            assert(nCardHeight and nCardHeight > 0 and nCardHeight < math.huge and nCardHeight == math.floor(nCardHeight), "CardHeight must be a positive finite integer.");

            local bChanged = pri.Name ~= sName or pri.CardWidth ~= nCardWidth or pri.CardHeight ~= nCardHeight;
            pri.Name, pri.CardWidth, pri.CardHeight = sName, nCardWidth, nCardHeight;

            return bChanged;
        end,
    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
