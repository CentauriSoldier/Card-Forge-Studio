--[[!
@fqxn CoG.Config.Scaler
@desc Default scaler callback scheduling. No host timer is required by default.
    A user config can supply both Schedule(delayMS, callback) and Cancel(handle),
    plus a positive DelayMS. Schedule must defer execution and return a non-nil
    handle. Scheduler callbacks must execute on the application's Lua thread.
!]]
return {
    Debounce = {
        DelayMS  = 0,
        Schedule = null,
        Cancel   = null,
    },
};
