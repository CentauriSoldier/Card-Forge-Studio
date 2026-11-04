constant("LIVECODE_TIMER_ID_MIN", 1000000);
constant("LIVECODE_TIMER_ID_MAX", 1999999);
local LIVECODE_TIMER_ID_MIN = LIVECODE_TIMER_ID_MIN;
local LIVECODE_TIMER_ID_MAX = LIVECODE_TIMER_ID_MAX;
----------------------------------------------------
local _nNextTimerID = LIVECODE_TIMER_ID_MIN - 1;
----------------------------------------------------
local ReadToString  = TextFile.ReadToString;
local GetCRC        = File.GetCRC;
----------------------------------------------------
local function sink() end
----------------------------------------------------
if not (type(GlobalTimer) == "table") then
    error("Cannot load LiveFileRepo. LiveFileRepo requires the GlobalTimer plugin.", 2);
end
----------------------------------------------------
--[[!
    @fqxn AMSExt.LiveFileRepo
    @desc Stuff here
!]]
return class("LiveFileRepo",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --LiveFileRepo = function(this, sAuthCode) end, --static constructor (runs after class object creation)\
        --[[!
        @fqxn AMSExt.LiveFileRepo
        !]]
        --[[SetActive = function(vID, vFlag)
            type.assert.string(vID, "%S", "LiveFileRepo.Start: ID must be a non-blank string.");
            local sID           = vID:upper();
            local tLiveFile     = _tLiveFilesByID[sID];
            tLiveFile.IsActive  = rawtype(vFlag) == "boolean" and vFlag or false;
        end,]]

    },
    {--PRIVATE
        DecoysByID          = {},
        LiveFiles           = {}, --indexed by decoy
        LiveFilesByID       = {}, --indexed by user-set id
        LiveFilesByTimerID  = {}, --indexed by timer id

        OnTimer = function(this, cdat, nID)
            local pri       = cdat.pri;
            local tLiveFile = pri.LiveFilesByTimerID[nID];

            if (tLiveFile and tLiveFile.TimerID == nID) then

                local pFile = tLiveFile.Path;
                local nCRC = GetCRC(pFile);

                if (nCRC ~= tLiveFile.CRC) then
                    --update the CRC
                    local nOldCRC = tLiveFile.CRC
                    tLiveFile.CRC = nCRC;

                    --update the repo
                    local sOldText = tLiveFile.Text;
                    local sNewText = ReadToString(pFile);
                    tLiveFile.Text = sNewText;

                    --indicate a change has occured (since last Text lookup)
                    tLiveFile.HasChanged = true;

                    tLiveFile.LastError = nil;

                    if (tLiveFile.Callback) then
                        local tLiveFileDecoy    = pri.DecoysByID[tLiveFile.ID];
                        local bOK, sError       = pcall(tLiveFile.Callback, tLiveFileDecoy, sOldText, sNewText, nOldCRC, nCRC);

                        if not (bOK) then
                            --TODO FINISH first check for tLiveFile Error Callback, then, if not present, use the repo or default
                            --if (_tErrorCallbacks[tLiveFile]) then
                        --        _tErrorCallbacks[tLiveFile](tLiveFile, sOldText, sNewText, nOldCRC, nCRC, sError);
                            --end

                            tLiveFile.LastError = sError; --TODO Set error per ID
                        end

                    end

                end

            end

        end,
    },
    {--PROTECTED

    },
    {--PUBLIC
        LiveFileRepo = function(this, cdat)

        end,
        Add = function(this, cdat, vID, pFile, nTimerInterval, fCallback)--bStart TODO Add this option, also allow error callback
            type.assert.string(vID, "%S", "LiveFileRepo.Add: ID must be a non-blank string.");
            type.assert.string(pFile, "%S", "LiveFileRepo.Add: File must be a non-blank string.");
            type.assert.number(nTimerInterval, true, true, false, true);
            local pri = cdat.pri;

            local sID = vID:upper();

            if (pri.LiveFilesByID[sID]) then
                error("LiveFileRepo.Add: LiveFile, '${id}', already exists." % {id = sID}, 2);
            end


            if not File.DoesExist(pFile) then
                error("LiveFileRepo.Add: File '${path}' doesn't exist." % {path = pFile}, 2);
            end

            --get a timer id
            _nNextTimerID = _nNextTimerID + 1;

            --throw error on timer ID range exceeded
            if (_nNextTimerID < LIVECODE_TIMER_ID_MIN or _nNextTimerID > LIVECODE_TIMER_ID_MAX) then
                error(  "LiveFileRepo.Add: Timer ID is out of range. Permissable range is from ${min} to ${max} (inclusive)." %
                        { min = LIVECODE_TIMER_ID_MIN, max = LIVECODE_TIMER_ID_MAX }, 2);
            end

            local tLiveFile = {
                CRC             = GetCRC(pFile),
                Callback        = rawtype(fCallback) == "function" and fCallback or sink,
                HasChanged      = false, --indicated whether a change has occured since last Text lookup
                IsActive        = false,
                ID              = sID,
                LastError       = nil,
                Path            = pFile,
                Text            = ReadToString(pFile),
                TimerID         = _nNextTimerID,
                TimerInterval   = nTimerInterval,
            };
            local tLiveFileDecoy = {};
            local tLiveFileMeta  = {
                __type  = "LiveFile",
                __index = function(t, k)
                    local vRet;

                    if (k == "Text") then
                        tLiveFile.HasChanged = false;
                        vRet = tLiveFile.Text;
                    else--TODO ERROR ON no such item??
                        vRet = tLiveFile[k] or nil;
                    end

                    return vRet;
                end,
                __newindex = function() end, --deadcall
            };

            setmetatable(tLiveFileDecoy, tLiveFileMeta);

            --store the LiveFile info
            pri.DecoysByID[sID]                           = tLiveFileDecoy;
            pri.LiveFiles[tLiveFileDecoy]                 = tLiveFile;
            pri.LiveFilesByID[sID]                        = tLiveFile;
            pri.LiveFilesByTimerID[tLiveFile.TimerID]     = tLiveFile;

            return tLiveFileDecoy;
        end,
        Get = function(this, cdat, vID)
            type.assert.string(vID, "%S", "LiveFileRepo.Get: ID must be a non-blank string.");
            local sID       = vID:upper();
            local tDecoy    = cdat.pri.DecoysByID[sID];

            if not (tDecoy) then
                error("LiveFileRepo.Get: ID '${id}' doesn't exist." % {id = vID});
            end

            return tDecoy;
        end,
        GetIDs = function(this, cdat)
            --TODO FINISH
        end,
        Reset = function(this, cdat)
            local pri = cdat.pri;

            for tDecoy, tLiveFile in pairs(pri.LiveFiles) do
                GlobalTimer.Stop(tLiveFile.TimerID);
                tLiveFile.CRC             = -2;
                tLiveFile.Callback        = sink;
                tLiveFile.HasChanged      = false;
                tLiveFile.IsActive        = false;
                tLiveFile.ID              = "";
                tLiveFile.LastError       = nil;
                tLiveFile.Path            = "";
                tLiveFile.Text            = "";
                tLiveFile.TimerID         = -1;
                tLiveFile.TimerInterval   = -1;
                setmetatable(tDecoy, {
                    __type = "LiveFile",
                    __index = function()
                        error("LiveFile is no longer valid.", 2);
                    end,
                    __newindex = function()
                        error("LiveFile is no longer valid.", 2);
                    end,
                });
            end

            pri.DecoysByID          = {};
            pri.LiveFiles           = {};
            pri.LiveFilesByTimerID  = {};
            pri.LiveFilesByID       = {};

            return true;
        end,
        SetCallback = function(this, cdat, vID, fCallback)--IS FINISH ED
            type.assert.string(vID, "%S", "LiveFileRepo.SetCallback: ID must be a non-blank string.");
            local sID           = vID:upper();
            local tLiveFile     = cdat.pri.LiveFilesByID[sID];

            if not (tLiveFile) then
                error("LiveFileRepo.SetCallback: ID '${id}' doesn't exist." % {id = vID});
            end

            tLiveFile.Callback  = rawtype(fCallback) == "function" and fCallback or sink;
        end,
        --[[SetErrorCallback = function(this, cdat, fCallback)
            type.assert.custom(oRepo, "LiveFileRepo:SetErrorCallback", "Argument 1 must be of type LiveFileRepo. Got "..type(oRepo)..'.');
            local tRepo = _tRepos[oRepo];
            _tErrorCallbacks[oRepo] = rawtype(fCallback) == "function" and fCallback or nil;
        end,]]
        Start = function(this, cdat, vID)--IS FINISH ED
            type.assert.string(vID, "%S", "LiveFileRepo.Start: ID must be a non-blank string.");
            local sID = vID:upper();
            local pri = cdat.pri;
            local tLiveFile = pri.LiveFilesByID[sID];

            if not (tLiveFile) then
                error("LiveFileRepo.Start: ID '${id}' doesn't exist." % {id = vID});
            end

            if not (tLiveFile.IsActive) then
                tLiveFile.IsActive = true;
                GlobalTimer.Start(tLiveFile.TimerInterval, tLiveFile.TimerID, pri.OnTimer);
            end

        end,
        StartAll = function(this, cdat)
            local pri = cdat.pri;

            for tDecoy, tLiveFile in pairs(pri.LiveFiles) do

                if not (tLiveFile.IsActive) then
                    tLiveFile.IsActive = true;
                    GlobalTimer.Start(tLiveFile.TimerInterval, tLiveFile.TimerID, pri.OnTimer);
                end

            end

        end,
        Stop = function(this, cdat, vID)
            type.assert.string(vID, "%S", "LiveFileRepo.Stop: ID must be a non-blank string.");
            local sID = vID:upper();
            local tLiveFile = cdat.pri.LiveFilesByID[sID];

            if not (tLiveFile) then
                error("LiveFileRepo.Stop: ID '${id}' doesn't exist." % {id = vID});
            end

            if (tLiveFile.IsActive) then
                tLiveFile.IsActive = false;
                GlobalTimer.Stop(tLiveFile.TimerID);
            end

        end,
        StopAll = function(this, cdat)
            local pri = cdat.pri;

            for tDecoy, tLiveFile in pairs(pri.LiveFiles) do

                if (tLiveFile.IsActive) then
                    tLiveFile.IsActive = false;
                    GlobalTimer.Stop(tLiveFile.TimerID);
                end

            end

        end,
    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
