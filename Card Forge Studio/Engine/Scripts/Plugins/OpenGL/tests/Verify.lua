local function main()
    -- Reusable bridge verification. wxLua supplies disposable host windows only.
    local _pPlugins = assert(arg[1], "Supply the Plugins folder.");
    package.path = _pPlugins.."/?.lua;".._pPlugins.."/?/init.lua;"..package.path;
    local _wx = require("wx");
    local _OpenGL = require("OpenGL");
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "OpenGL resource verification",
        _wx.wxDefaultPosition, _wx.wxSize(128,128));
    local tContexts = {};
    local bOK, sFailure = xpcall(function()
        for nIndex = 1, 2 do
            local oPanel = _wx.wxPanel(oFrame, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxSize(64,64));
            tContexts[nIndex] = _OpenGL.create(oPanel:GetHandle());
        end
        local oLeft, oRight = tContexts[1], tContexts[2];
        local uProgram = oLeft:createProgram(_OpenGL.VertexShader, _OpenGL.FragmentShader);
        assert(not pcall(function() oLeft:createProgram("invalid GLSL", "invalid GLSL"); end));
        local uTexture = oLeft:createTexture(1, 1, string.char(255,0,0,128));
        assert(not pcall(function() oLeft:createTexture(1,1,"short"); end));
        assert(not pcall(function() oLeft:createTexture(0,1,""); end));
        local tTransform = _OpenGL.transform(16,16,32,32,0,0,32,32);
        oLeft:beginFrame(32,32,0,0,1);
        oLeft:draw(uProgram,uTexture,tTransform,{1,1,1,1});
        local sPixels = oLeft:readPixels(32,32);
        local nOffset = (16 * 32 + 16) * 4 + 1;
        local nRed,nGreen,nBlue = sPixels:byte(nOffset,nOffset+2);
        assert(nRed >= 126 and nRed <= 130 and nGreen == 0 and nBlue >= 125 and nBlue <= 129,
            "RGBA blending did not produce half red / half blue.");
        assert(not pcall(function() oRight:draw(uProgram,uTexture,tTransform,{1,1,1,1}); end));
        oLeft:release(uTexture); oLeft:release(uTexture);
        assert(not pcall(function() oLeft:draw(uProgram,uTexture,tTransform,{1,1,1,1}); end));
        local uRGB = oLeft:createTexture(1,1,string.char(0,255,0),string.char(255));
        oLeft:beginFrame(32,32,0,0,0); oLeft:draw(uProgram,uRGB,tTransform,{1,1,1,1});
        sPixels = oLeft:readPixels(32,32);
        assert(sPixels:byte(nOffset)==0 and sPixels:byte(nOffset+1)==255 and sPixels:byte(nOffset+2)==0);
        oLeft:present();
        assert(not pcall(function() oLeft:readPixels(33,32); end));
        oLeft:close(); oLeft:close();
        assert(not pcall(function() oLeft:beginFrame(32,32,0,0,0); end));
    end, debug.traceback);
    for _, oContext in ipairs(tContexts) do oContext:close(); end
    oFrame:Destroy(); _wx.wxGetApp():ProcessPendingEvents(); collectgarbage("collect");
    assert(bOK,sFailure);
    print("PASS: shader errors, texture validation, RGBA blending, RGB/alpha upload, context isolation, release and close guards.");
end

main();
