--[[!
@fqxn CFS.Modules.test
@desc Development test harness; not a public application API.
@vis private
!]]

local _tWx = require("wx");
local _tWindows = {};
local _nMessageCount = 0;

local function sendMessage(nSource, nTarget)
    _nMessageCount = _nMessageCount + 1;

    local sMessage = "Message " .. _nMessageCount .. " from Window " .. nSource
        .. " to Window " .. nTarget .. ".\n";

    _tWindows[nTarget].log:AppendText(sMessage);
    _tWindows[nSource].frame:SetStatusText("Sent message to Window " .. nTarget .. ".");
    _tWindows[nTarget].frame:SetStatusText("Received message from Window " .. nSource .. ".");
end

for nWindow = 1, 3 do
    local oFrame = _tWx.wxFrame(_tWx.NULL, _tWx.wxID_ANY,
        "Window " .. nWindow .. " - wxLua Message Test",
        _tWx.wxPoint(80 + (nWindow - 1) * 360, 120), _tWx.wxSize(350, 320));
    local oPanel = _tWx.wxPanel(oFrame, _tWx.wxID_ANY);
    local oSizer = _tWx.wxBoxSizer(_tWx.wxVERTICAL);
    local oLog = _tWx.wxTextCtrl(oPanel, _tWx.wxID_ANY, "",
        _tWx.wxDefaultPosition, _tWx.wxDefaultSize,
        _tWx.wxTE_MULTILINE + _tWx.wxTE_READONLY);

    oSizer:Add(oLog, 1, _tWx.wxEXPAND + _tWx.wxALL, 10);

    _tWindows[nWindow] = {frame = oFrame, log = oLog, buttons = {}};

    for nTarget = 1, 3 do
        if nTarget ~= nWindow then
            local nSourceWindow = nWindow;
            local nTargetWindow = nTarget;
            local oButton = _tWx.wxButton(oPanel, _tWx.wxID_ANY,
                "Send to Window " .. nTargetWindow);

            oButton:Connect(_tWx.wxEVT_COMMAND_BUTTON_CLICKED, function(jEvent)
                local tTarget = _tWindows[nTargetWindow];

                if tTarget then
                    sendMessage(nSourceWindow, nTargetWindow);
                else
                    _tWindows[nSourceWindow].frame:SetStatusText("Window " .. nTargetWindow .. " is closed.");
                end
            end);

            _tWindows[nWindow].buttons[nTarget] = oButton;
            oSizer:Add(oButton, 0, _tWx.wxEXPAND + _tWx.wxLEFT + _tWx.wxRIGHT + _tWx.wxBOTTOM, 10);
        end
    end

    local nClosingWindow = nWindow;

    oFrame:Connect(_tWx.wxEVT_CLOSE_WINDOW, function(jEvent)
        _tWindows[nClosingWindow] = nil;

        jEvent:Skip();
    end);

    oPanel:SetSizer(oSizer);
    oFrame:CreateStatusBar(1);
    oFrame:SetStatusText("Send a message using either button.");
end

for nWindow = 1, 3 do
    _tWindows[nWindow].frame:Show(true);
end

_tWx.wxGetApp():MainLoop();
