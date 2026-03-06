local GameUtil  = require("Game.GameUtil");

return class("CardSet",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --CardSet = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        --CardSetExists = function(sCardSet) end
        --rebuilds all game objects and refreshes the private static info
    },
    {--PRIVATE
        --Calls               = {}, --holds things like Draw, Proc, etc.
        CallRepo            = null,
        CardWidth__AUTOR_   = null,
        CardHeight__AUTOR_  = null,
        DataPath__AUTOR_    = null,
        InfoPath__AUTOR_    = null,
        IsActive__AUTOA_    = false,
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

            local pData     = pFolder.."\\"..FILESPEC_CARDSET_DATA.Full;
            local pInfo     = pFolder.."\\"..FILESPEC_CARDSET_INFO.Full;

            --call files
            local pDrawPath     = pFolder.."\\"..FILESPEC_CARDSET_DRAW.Full;
            local pRowProcPath  = pFolder.."\\"..FILESPEC_CARDSET_ROWPROC.Full;

            local tCheckFiles = {pData, pInfo, pDrawPath, pRowProcPath};

            for _, pFile in pairs(tCheckFiles) do

                if not (File.DoesExist(pFile)) then
                    error("Invalid CardSet: missing expected file at \""..pFile..".\"");
                end

            end

            --TODO SPECIAL COLUMNS!!!
            local sUUID         = GameUtil.ValidateObjectFolder(pFolder, "CardSet");
            local sName         = GameUtil.ValidateObjectName(pFolder, "CardSet");
            local nCardWidth    = tonumber(INIFile.GetValue(pFolder.."\\Info.ini", "SETTINGS", "CardWidth"));
            local nCardHeight   = tonumber(INIFile.GetValue(pFolder.."\\Info.ini", "SETTINGS", "CardHeight"));

            if (not nCardWidth) then
                error("Invalid ${type}: Malformed ${type} INI file at ${path}. Missing \"CardWidth\" value or non-numeric value given." % {path = pFolder, type = sType}, 2);
            end

            if (not nCardHeight) then
                error("Invalid ${type}: Malformed ${type} INI file at ${path}. Missing \"CardHeight\" value or non-numeric value given." % {path = pFolder, type = sType}, 2);
            end

            --set the game's info
            pri.DataPath    = pData;
            pri.InfoPath    = pInfo;
            pri.Name        = sName;
            pri.Path        = pFolder;
            pri.UUID        = sUUID;
            pri.CardWidth   = math.abs(nCardWidth);
            pri.CardHeight  = math.abs(nCardHeight);

            --create the LiveFileRepo and register the LiveFiles for each call.
            local oCallRepo = LiveFile.CreateRepo();
            pri.CallRepo    = oCallRepo;
            LiveFile.Register(oCallRepo, "RowProc", pRowProcPath,   PROCSYS_FILE_SYNC_TIMER_INTERVAL);
            LiveFile.Register(oCallRepo, "Draw",    pDrawPath,      PROCSYS_FILE_SYNC_TIMER_INTERVAL);--TODO SPECIAL COLUMNS!!!
        end,
        GetLiveFile = function(this, cdat, sCall)
            local pri = cdat.pri;
            return pri.CallRepo[sCall];
            --local tCalls = pri.Calls;
            --p(sCall, type(tCalls[sCall].Code))
            --if (tCalls[sCall] == nil) then
            --    error("TODO ERROR CAN'T GET CALL - NO CARDSET CALL BY THAT NAME")
            --end

            --return tCalls[sCall].Code;
        end,
        --[[GetLiveFileRepo = function(this, cdat)
            return cdat.pri.CallRepo;
            --local tCalls = pri.Calls;
            --p(sCall, type(tCalls[sCall].Code))
            --if (tCalls[sCall] == nil) then
            --    error("TODO ERROR CAN'T GET CALL - NO CARDSET CALL BY THAT NAME")
            --end

            --return tCalls[sCall].Code;
        end,]]
        --[[GetCallPath = function(this, cdat, sCall)
            local pri = cdat.pri;
            local tCalls = pri.Calls;
            --p(sCall, type(tCalls[sCall].Code))
            if (tCalls[sCall] == nil) then
                error("TODO ERROR CAN'T GET CALL - NO CARDSET CALL BY THAT NAME")
            end

            return tCalls[sCall].Path;
        end,]]
        GetCardSize = function(this, cdat)
            local pri = cdat.pri;
            return {Width = pri.CardWidth, Height = pri.CardHeight};
        end,
        SetActive = function(this, cdat, vFlag)
            local pri       = cdat.pri;
            local bActive   = rawtype(vFlag) == "boolean" and vFlag or false;

            if (bActive) then
                LiveFile.StartAll(pri.CallRepo);
            else
                LiveFile.StopAll(pri.CallRepo);
            end

        end,
        --updates proc, draw, etc.
        --[[UpdateCallCode = function(this, cdat, sCall)
            local pri       = cdat.pri;
            local tCalls    = pri.Calls;
            local nRet;

            if (tCalls[sCall] == nil) then
                error("TODO ERROR CAN'T UPDATE CALL - NO CARDSET CALL BY THAT NAME");
            end

            local tCall = tCalls[sCall];
            local pCallCode = tCall.Path;

            if not (File.DoesExist(pCallCode)) then
                --TODO FINISH ERROR
                error("NO FILE, OMG! AHHHHH!!!!"..sCall);
            end

            --get the new CRC
            local nCRC = GetCRC(tCall.Path);

            if (nCRC == -1) then --an error occurred if it does == -1
                --TODO ERROR HERE
            end

            --compare it the existing one
            if (nCRC ~= tCall.CRC) then
                --set the newest CRC for this call
                tCall.CRC = nCRC;
                tCall.Code = ReadToString(pCallCode); --TODO THROW ERROR on file read error
                nRet = nCRC;
            end

            return nRet;
        end]]
    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
