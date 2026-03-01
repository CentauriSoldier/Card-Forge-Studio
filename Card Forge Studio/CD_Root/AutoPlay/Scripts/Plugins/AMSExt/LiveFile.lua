constant("LIVECODE_TIMER_ID_MIN", 10000);
constant("LIVECODE_TIMER_ID_MAX", 20000);
local LIVECODE_TIMER_ID_MIN = LIVECODE_TIMER_ID_MIN;
local LIVECODE_TIMER_ID_MAX = LIVECODE_TIMER_ID_MAX;

local _nNextTimerID = LIVECODE_TIMER_ID_MIN - 1;
local ReadToString  = TextFile.ReadToString;
local GetCRC        = File.GetCRC;
--TODO error on no GlobalTimer plugin
if not (type(GlobalTimer) == "table") then
    error("Cannot load LiveFile. LiveFile requires the GlobalTimer plugin.", 2);
end

local _tRepos               = {}; --indexed by Repo Decoy, value is tRepo (actual)
--local _tLiveFilesByRepo     = {}; --indexed by Repo Decoy, value is tLiveFile (actual)
local _tLiveFiles           = {}; --indexed by LiveFile Decoy, value is tLiveFile (actual)
local _tLiveFilesByID       = {};
local _tLiveFilesByTimerID  = {};
local _tErrorCallbacks      = {}; --indexed by Repo Decoy, value is function or nil

local function _StringKeyPairs(tTable)

    local function iter(t, k)
        local nk, v = next(t, k);

        while (nk ~= nil and rawtype(nk) ~= "string") do
            nk, v = next(t, nk);
        end

        return nk, v;
    end

    return iter, tTable, nil;
end


--[[!
    @fqxn AMSExt.LiveFile
    @desc Stuff here
!]]
return class("LiveFile",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --LiveFile = function(this, sAuthCode) end, --static constructor (runs after class object creation)\
        --[[!
        @fqxn AMSExt.LiveFile
        !]]
        CreateRepo = function()
            --create the repo system
            local tRepo     = {}; --store the various registered LiveFile decoy tables, indexed by ID
            local tDecoy    = {};
            local tMeta     = {
                __type  = "LiveFileRepo",
                __index = function(t, k)

                    if (rawtype(k) == "string") then
                        return tRepo[k:upper()];
                    end

                end,
                __newindex = function() end, --deadcall
                __pairs = function(t)
                    local tRepo = _tRepos[t];
                    return _StringKeyPairs(tRepo);
                end,
            };

            setmetatable(tDecoy, tMeta);

            --store the repo
            _tRepos[tDecoy] = tRepo;

            return tDecoy;
        end,
        OnTimer = function(nID)
            local tLiveFile = _tLiveFilesByTimerID[nID];

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
                        local bOK, sError = pcall(tLiveFile.Callback, tLiveFile, sOldText, sNewText, nOldCRC, nCRC);

                        if not (bOK) then
                            --TODO FINISH first check for tLiveFile Error Callback, then, if not present, use the repo or default
                            if (_tErrorCallbacks[tLiveFile.Repo]) then
                                _tErrorCallbacks[tLiveFile.Repo](tLiveFile, sError);
                            end

                            tLiveFile.LastError = sError;
                        end

                    end

                end

            end

        end,
        Register = function(oRepo, vID, pFile, nTimerInterval, fCallback)--bStart TODO Add this option, also allow error callback
            type.assert.custom(oRepo, "LiveFileRepo", "Argument 1 must be of type LiveFileRepo. Got "..type(oRepo)..'.');
            type.assert.string(vID, "%S", "LiveFile.Register: ID must be a non-blank string.");
            type.assert.string(pFile, "%S", "LiveFile.Register: File must be a non-blank string.");
            type.assert.number(nTimerInterval, true, true, false, true);

            if not File.DoesExist(pFile) then
                error("LiveFile.Register: File '${path}' doesn't exist." % {path = pFile}, 2);
            end

            --get a timer id
            _nNextTimerID = _nNextTimerID + 1;

            --throw error on timer ID range exceeded
            if (_nNextTimerID < LIVECODE_TIMER_ID_MIN or _nNextTimerID > LIVECODE_TIMER_ID_MAX) then
                error(  "LiveFile.Register: Timer ID is out of range. Permissable range is from ${min} to ${max} (inclusive)." %
                        { min = LIVECODE_TIMER_ID_MIN, max = LIVECODE_TIMER_ID_MAX }, 2);
            end

            local sID = vID:upper();
            local tRepo = _tRepos[oRepo];

            local tLiveFile = {
                CRC             = -2,
                Callback        = rawtype(fCallback) == "function" and fCallback or false,
                HasChanged      = false, --indicated whether a change has occured since last Text lookup
                IsActive        = false,
                ID              = sID,
                LastError       = nil,
                Path            = pFile,
                Repo            = oRepo,
                Text            = ReadToString(pFile),
                TimerID         = _nNextTimerID,
                TimerInterval   = nTimerInterval,
            };
            local tLiveFileDecoy = {};
            local tLiveFileMeta  = {
                __type  = "LiveFileInfo",
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
            _tLiveFilesByID[sID]                        = tLiveFile;
            _tLiveFilesByTimerID[tLiveFile.TimerID]     = tLiveFile;
            _tLiveFiles[tLiveFileDecoy]                 = tLiveFile;
            --_tLiveFilesByTimerID[_tLiveFilesByID[sID].TimerID]  = tLiveFile;

            --[[if not (_tLiveFilesByRepo[oRepo]) then
                _tLiveFilesByRepo[oRepo] = {};
            end

            _tLiveFilesByRepo[oRepo]                    = tLiveFile;]]

            --send the LiveFile to the repo for user access
            tRepo[sID]                                  = tLiveFileDecoy;
        end,
        --[[SetActive = function(vID, vFlag)
            type.assert.string(vID, "%S", "LiveFile.Start: ID must be a non-blank string.");
            local sID           = vID:upper();
            local tLiveFile     = _tLiveFilesByID[sID];
            tLiveFile.IsActive  = rawtype(vFlag) == "boolean" and vFlag or false;
        end,]]
        SetCallback = function(vID, fCallback)
            type.assert.string(vID, "%S", "LiveFile.Start: ID must be a non-blank string.");
            local sID           = vID:upper();
            local tLiveFile     = _tLiveFilesByID[sID];
            tLiveFile.Callback  = rawtype(fCallback) == "function" and fCallback or false;
        end,
        SetErrorCallback = function(oRepo, fCallback)
            type.assert.custom(oRepo, "LiveFileRepo", "Argument 1 must be of type LiveFileRepo. Got "..type(oRepo)..'.');
            local tRepo = _tRepos[oRepo];
            _tErrorCallbacks[oRepo] = rawtype(fCallback) == "function" and fCallback or nil;
        end,
        Start = function(vID)
            type.assert.string(vID, "%S", "LiveFile.Start: ID must be a non-blank string.");
            local sID = vID:upper();
            local tLiveFile = _tLiveFilesByID[sID];

            if not (tLiveFile) then
                error("LiveFile.Start: ID '${id}' doesn't exist." % {id = vID});
            end

            tLiveFile.IsActive = true;
            GlobalTimer.Start(tLiveFile.TimerInterval, tLiveFile.TimerID, LiveFile.OnTimer);
        end,
        StartAll = function(oRepo)
            type.assert.custom(oRepo, "LiveFileRepo", "Argument 1 must be of type LiveFileRepo. Got "..type(oRepo)..'.');
            local tRepo = _tRepos[oRepo];

            for sID, oLiveFile in pairs(tRepo) do
                local tLiveFile = _tLiveFiles[oLiveFile];

                if not (tLiveFile.IsActive) then
                    tLiveFile.IsActive = true;
                    GlobalTimer.Start(tLiveFile.TimerInterval, tLiveFile.TimerID, LiveFile.OnTimer);
                end

            end

        end,
        Stop = function(vID)
            type.assert.string(vID, "%S", "LiveFile.Stop: ID must be a non-blank string.");
            local sID = vID:upper();
            local tLiveFile = _tLiveFilesByID[sID];

            if not (tLiveFile) then
                error("LiveFile.Stop: ID '${id}' doesn't exist." % {id = vID});
            end

            tLiveFile.IsActive = false;
            GlobalTimer.Stop(tLiveFile.TimerID);
        end,
        StopAll = function()
            type.assert.custom(oRepo, "LiveFileRepo", "Argument 1 must be of type LiveFileRepo. Got "..type(oRepo)..'.');
            local tRepo = _tRepos[oRepo];

            for sID, oLiveFile in pairs(tRepo) do
                local tLiveFile = _tLiveFiles[oLiveFile];

                if not (tLiveFile.IsActive) then
                    tLiveFile.IsActive = false;
                    GlobalTimer.Stop(tLiveFile.TimerID);
                end

            end

        end,

    },
    {--PRIVATE
        LiveFile = function(this, cdat) end,
    },
    {--PROTECTED

    },
    {--PUBLIC

    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
