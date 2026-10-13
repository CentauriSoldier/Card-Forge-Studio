local wx=require('wx');local Themes=require('Manual.Themes');local Toolbar={};
function Toolbar.button(parent,label,icon,theme)
    local path=(APP_PATH or '')..'/Images/Manual/'..icon..theme..'.png';
    local bitmap=wx.wxBitmap(path,wx.wxBITMAP_TYPE_PNG);local button;
    if bitmap:IsOk() then button=wx.wxBitmapButton(parent,wx.wxID_ANY,bitmap,wx.wxDefaultPosition,wx.wxSize(34,34),wx.wxBORDER_NONE);bitmap:delete();
    else button=wx.wxButton(parent,wx.wxID_ANY,label,wx.wxDefaultPosition,wx.wxSize(34,34),wx.wxBORDER_NONE);end
    Themes.role(button,'toolbar');button:SetToolTip(label);return button;
end
function Toolbar.create(parent,editor,actions)
    local panel=Themes.role(wx.wxPanel(parent,wx.wxID_ANY),'toolbar');local row=wx.wxBoxSizer(wx.wxHORIZONTAL);local controls={};
    local groups={{{'edit','Hide editor','ToolbarHideEditor'},{'save','Save (Ctrl+S)','ToolbarSave'},{'undo','Undo (Ctrl+Z)','ToolbarUndo'},{'redo','Redo (Ctrl+Shift+Z)','ToolbarRedo'}},
        {{'refresh','Refresh styles','ToolbarRefresh'},{'styles','Styles','ToolbarStyles'},{'options','Manual Options','ToolbarOptions'}},{{'fit','Fit page','ToolbarFit'},{'grid','Show grid','ToolbarGrid'},{'snap','Snap (Alt temporarily)','ToolbarSnap'}}};
    for gi,group in ipairs(groups) do
        if gi>1 then row:Add(wx.wxStaticLine(panel,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxSize(1,26),wx.wxLI_VERTICAL),0,wx.wxALIGN_CENTER_VERTICAL+wx.wxLEFT+wx.wxRIGHT,6);end
        for _,spec in ipairs(group) do local button=Toolbar.button(panel,spec[2],spec[3],editor.theme);controls[spec[1]]=button;row:Add(button,0,wx.wxALIGN_CENTER_VERTICAL);button:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()actions[spec[1]]();end);end
    end
    controls.zoom=wx.wxSlider(panel,wx.wxID_ANY,100,10,400,wx.wxDefaultPosition,wx.wxSize(150,30),wx.wxSL_HORIZONTAL);controls.zoom:SetToolTip('Page zoom; Control-wheel. Alt-wheel scales the interface.');row:Add(controls.zoom,0,wx.wxALIGN_CENTER_VERTICAL+wx.wxLEFT,8);
    controls.percent=wx.wxStaticText(panel,wx.wxID_ANY,'100%');row:Add(controls.percent,0,wx.wxALIGN_CENTER_VERTICAL+wx.wxLEFT+wx.wxRIGHT,6);
    local reset=wx.wxButton(panel,wx.wxID_ANY,'100%',wx.wxDefaultPosition,wx.wxSize(48,28),wx.wxBORDER_NONE);row:Add(reset,0,wx.wxALIGN_CENTER_VERTICAL);reset:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()editor.canvas.zoom(100,true);end);
    controls.zoom:Connect(wx.wxEVT_SCROLL_THUMBTRACK,function()local step=editor.document.settings.zoomStep;local value=controls.zoom:GetValue();editor.canvas.zoom(math.max(10,math.min(400,math.floor(value/step+.5)*step)),true);end);
    controls.zoom:Connect(wx.wxEVT_SCROLL_CHANGED,function()editor.canvas.zoom(controls.zoom:GetValue(),true);end);
    local export=wx.wxButton(panel,wx.wxID_ANY,'Export',wx.wxDefaultPosition,wx.wxSize(65,28),wx.wxBORDER_NONE);export:SetToolTip('Export HTML or PDF');row:Add(export,0,wx.wxALIGN_CENTER_VERTICAL+wx.wxLEFT,8);export:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,actions.export);
    panel:SetSizer(row);return {panel=panel,controls=controls};
end
function Toolbar.context(parent,editor)
    local panel=Themes.role(wx.wxPanel(parent,wx.wxID_ANY),'toolbar');local row=wx.wxBoxSizer(wx.wxHORIZONTAL);
    local size=wx.wxSpinCtrlDouble(panel,wx.wxID_ANY,'',wx.wxDefaultPosition,wx.wxSize(75,28),wx.wxSP_ARROW_KEYS,.1,1000,12,.1);size:SetDigits(1);size:SetToolTip('Text size (points)');row:Add(size,0,wx.wxALL,3);
    size:Connect(wx.wxEVT_SPINCTRLDOUBLE,function()local n=tonumber(size:GetValue());if n and n>0 then editor.format({size=n});end;end);
    for _,spec in ipairs({{'B','Bold'},{'I','Italic'},{'U','Underline'},{'Left','align','left'},{'Center','align','center'},{'Right','align','right'},{'Justify','align','justify'},{'Bullets','list','ul'},{'Numbers','list','ol'},{'No list','list',false}}) do
        local b=wx.wxButton(panel,wx.wxID_ANY,spec[1],wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxBORDER_NONE);b:SetToolTip(spec[1]);row:Add(b,0,wx.wxALL,3);
        b:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function() if spec[2]=='align' then editor.format({align=spec[3]});else local value=spec[3];if value==nil then value=not editor.typing[spec[2]];end;editor.format({[spec[2]]=value});end;end);
    end
    panel:SetSizer(row);return {panel=panel,size=size};
end
function Toolbar.theme(toolbar,name)
    local icons={edit='ToolbarHideEditor',save='ToolbarSave',undo='ToolbarUndo',redo='ToolbarRedo',refresh='ToolbarRefresh',styles='ToolbarStyles',options='ToolbarOptions',fit='ToolbarFit',grid='ToolbarGrid',snap='ToolbarSnap'};
    for key,icon in pairs(icons) do local bitmap=wx.wxBitmap((APP_PATH or '')..'/Images/Manual/'..icon..name..'.png',wx.wxBITMAP_TYPE_PNG);if bitmap:IsOk() then toolbar.controls[key]:SetBitmap(bitmap);end;bitmap:delete();end
end
return Toolbar;
