local hWndDebug;

function Debug.GetWndHandle()

    if not (hWndDebug) then
        local tWindows = Window.EnumerateTitles(false);

        for hFoundWnd, sTitle in pairs(tWindows) do

            if sTitle == "Debug" then
                hWndDebug = hFoundWnd;
                break;
            end

        end

    end

    return hWndDebug;
end
