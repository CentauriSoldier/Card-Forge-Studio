local Window = Window;
local S = Windows.WINDOW_STYLE
local _tObjects = {
    [OBJECT_INPUT] = {
        Style = S.WS_OVERLAPPED | S.WS_SYSMENU | S.WS_MINIMIZEBOX | S.WS_MAXIMIZEBOX | S.WS_THICKFRAME | S.WS_VSCROLL | S.WS_HSCROLL,
        Table = Input,
    },
    [OBJECT_LISTBOX] = {
        Style = S.WS_OVERLAPPED | S.WS_SYSMENU | S.WS_MINIMIZEBOX | S.WS_MAXIMIZEBOX | S.WS_THICKFRAME | S.WS_VSCROLL | S.WS_HSCROLL,
        Table = ListBox,
    },
    [OBJECT_GRID] = {
        Style = S.WS_OVERLAPPED | S.WS_SYSMENU | S.WS_MINIMIZEBOX | S.WS_MAXIMIZEBOX | S.WS_THICKFRAME,
        Table = Grid,
    },
};

-- hard-remove maximize
--nStyle = nStyle & ~S.WS_MAXIMIZEBOX

local _nStyleEx =
      Windows.WINDOW_EX_STYLE.WS_EX_APPWINDOW
    | Windows.WINDOW_EX_STYLE.WS_EX_WINDOWEDGE
    | Windows.WINDOW_EX_STYLE.WS_EX_CLIENTEDGE

return class("WinAMS",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --WinAMS = function(this, sAuthCode) end, --static constructor (runs after class object creation)
    },
    {--PRIVATE
        AMSObjectType   = -1,
        Object          = "",
        ObjectHandle    = 0,
    },
    {--PROTECTED

    },
    {--PUBLIC
        WinAMS = function(this, cdat, super, nObjectType, sTitle, nX, nY, nWidth, nHeight, sObject, fOnCreate, fOnReady)
            --TODO assertions
            local pri           = cdat.pri;
            pri.Object          = sObject;
            pri.AMSObjectType   = nObjectType;
            local tObject       = _tObjects[nObjectType].Table;
            local sStyle        = _tObjects[nObjectType].Style;

            local hObject = tObject.GetProperties(sObject).WindowHandle;
            pri.ObjectHandle = hObject;

            --TODO wrap and fire oncreate, onready

            local OnReady = function(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight)
            	WindowWizard.EmbedWindow(hObject, hWnd);
                tObject.SetProperties(sObject, {X = 0, Y = 0, Width = nCWidth, Height = nCHeight});

                if (type(fOnReady) == "function") then
                    fOnReady(hWnd, sObject);
                end

            end

            super(sTitle, nX, nY, nWidth, nHeight, sStyle, _nStyleEx, nil, OnReady)

            local function OnResizeStop(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight)
            	tObject.SetProperties(sObject, {Width = nCWidth, Height = nCHeight});
            	--tObject.SetSize("Grid1", tSize.Width, tSize.Height);
            end

            this.SetCallback(WinSys.EVENT.OnResizeStop, OnResizeStop);

            local function OnMaximize(hWnd, nX, nY, nWidth, nHeight, nCWidth, nCHeight)
            	tObject.SetProperties(sObject, {Width = nCWidth, Height = nCHeight});
            	--tObject.SetSize("Grid1", tSize.Width, tSize.Height);
            end

            this.SetCallback(WinSys.EVENT.OnMaximize, OnMaximize);


            local function OnClose(hWnd)
                Window.Hide(hWnd);
                return false;
            end

            this.SetCallback(WinSys.EVENT.OnClose, OnClose);
        end,
        FillWindow = function(this, cdat)
            local pri = cdat.pri;
            local tObject = _tObjects[pri.AMSObjectType].Table;
            --local tSize = Window.GetSize(this.GetWindowHandle());
            local tSize = WindowWizard.GetClientSize(this.GetWindowHandle());
            tObject.SetSize(pri.Object, tSize.Width, tSize.Height);
            tObject.SetPos(pri.Object, 0, 0);
        end,
    },
    WinSys,   --extending class
    false, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
