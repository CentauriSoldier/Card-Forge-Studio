local _nNextTimerID = LIVECODE_TIMER_ID - 1;
local _tRegistry = {};


return class("LiveCode",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --LiveCode = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        OnTimer = function(nID)

            for sID, tInfo in pairs(_tRegistry) do

                if (eID == tInfo.TimerID) then

                end

            end

        end,
        Register = function(sID, pFile, nTimerInterval, fCallback)
            type.assert.string(sID, "%S", "LiveCode.Register: ID must be a non-blank string.");
            type.assert.string(pFile, "%S", "LiveCode.Register: File must be a non-blank string.");
            type.assert.number(nTimerInterval, true, true, false, true);

            if not File.DoesExist(pFile) then
                error("LiveCode.Register: File '${path}' doesn't exist." % {path = pFile}, 2);
            end

            _nNextTimerID = _nNextTimerID + 1;

            _tRegistry[sID:upper()] = {
                CRC             = -2,
                LastCRC         = -2,
                Callback        = rawtype(fCallback) == "function" and fCallback or false,
                Path            = sPath,
                TimerID         = _nNextTimerID,
                TimerInterval   = nTimerInterval,
            };
        end,
        Start = function(vID)
            type.assert.string(sID, "%S", "LiveCode.Start: ID must be a non-blank string.");
            local sID = vID:upper();
            local tInfo = _tRegistry[sID];

            if not (tInfo) then
                error("LiveCode.Start: ID '${id}' doesn't exist." % {id = vID});
            end

            Page.StartTimer(tInfo.Interval, tInfo.TimerID);
        end,
        Stop = function()
            type.assert.string(sID, "%S", "LiveCode.Stop: ID must be a non-blank string.");

            local sID = vID:upper();

            if not (_tRegistry[sID]) then
                error("LiveCode.Stop: ID '${id}' doesn't exist." % {id = vID});
            end

            Page.StartTimer(tInfo.TimerID);
        end,

    },
    {--PRIVATE
        LiveCode = function(this, cdat) end,
    },
    {--PROTECTED

    },
    {--PUBLIC

    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
