
--keeps track of windows created and destroys them on app close (if they still exist)
local _tCensus = {};


local _tWindowClasses = {};

local function dummy() return true; end

local eEvent = enum("WinSys.EVENT", {   "OnClose", "OnDestroy", "OnMaximize",
                                        "OnMinimize", "OnResize", "OnResizeStart", "OnResizeStop", "OnRestore"}, nil, true);

return class("WinSys",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --WinSys = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        EVENT = eEvent,
        RegisterWindowClass = function(hWnd)

            if (_tWindowClasses[hWnd] == nil) then
                local window_class_buffer, window_class_name_buffer = create_window_class(hWnd);

                _tWindowClasses[hWnd] = {
                    Buffer      = window_class_buffer,
                    NameBuffer  = window_class_name_buffer,
                };
            end
        end,
        OnShutdown = function()

            for nIndex, hWnd in pairs(_tCensus) do

                if (WindowWizard.IsWindow(hWnd)) then
                    WindowWizard.DestroyTopWindow(hWnd);
                end

            end

        end,
    },
    {--PRIVATE

    },
    {--PROTECTED
        callbacks = {
            [tostring(eEvent.OnClose)]         = null,
            [tostring(eEvent.OnDestroy)]       = null,
            [tostring(eEvent.OnMaximize)]      = null,
            [tostring(eEvent.OnMinimize)]      = null,
            [tostring(eEvent.OnResize)]        = null,
            [tostring(eEvent.OnResizeStart)]   = null,
            [tostring(eEvent.OnResizeStop)]    = null,
            [tostring(eEvent.OnRestore)]       = null,
        },
        WindowHandle__AUTOR_               = null,
    },
    {--PUBLIC
        WinSys = function(this, cdat, sTitle, nX, nY, nWidth, nHeight, nStyle, nStyleEx, OnCreate, OnReady)--TODO move to protected after testing
            --TODO assertions

            local hWnd = WindowWizard.CreateTopWindowEx(sTitle, nX, nY, nWidth, nHeight, nStyle or 0, nStyleEx or 0, OnCreate, OnReady);
            cdat.pro.WindowHandle = hWnd;
            --register the window with the census table for later destruction.
            _tCensus[#_tCensus + 1] = hWnd;
        end,
        GetWndHandle = function(this, cdat)
            return cdat.pro.WindowHandle;
        end,
        GetCallback = function(this, cdat, eEvent)

            if not (type(eEvent) == "WinSys.EVENT") then
                --TODO THROW ERROR
            end

            return cdat.pro.callbacks[tostring(eEvent)];
        end,
        SetCallback = function(this, cdat, eEvent, fCallback)

            if not (type(eEvent) == "WinSys.EVENT") then
                --TODO THROW ERROR
            end

            if not (rawtype(fCallback) == "function") then
                --TODO throw error?? Or just reset to nothing...prob best
            end

            local sEvent = tostring(eEvent);

            cdat.pro.callbacks[sEvent] = fCallback;
            WindowWizard.SetTopEventHandlerFor(cdat.pro.WindowHandle, sEvent, fCallback);
        end,
    },
    nil,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
