function Window.GetRect(hWnd)
    local tRet;

    if (rawtype(hWnd) == "number") then
        local tPos  = Window.GetPos(hWnd);
        local tSize = Window.GetSize(hWnd);

        if (tPos and tSize) then
            tRet = {
                X       = tPos.X,
                Y       = tPos.Y,
                Width   = tSize.Width,
                Height   = tSize.Height,
            };
        end

    end

    return tRet;
end


function Window.SetRect(hWnd, nX, nY, nWidth, nHeight)
    Window.SetSize(hWnd, nWidth, nHeight);
    Window.SetPos(hWnd, nX, nY);
end
