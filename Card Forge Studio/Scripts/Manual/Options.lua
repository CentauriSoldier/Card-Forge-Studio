local wx=require('wx');local Themes=require('Manual.Themes');local Document=require('Manual.Document');local Options={};
function Options.show(parent,editor)
    local dialog=wx.wxDialog(parent,wx.wxID_ANY,'Manual Options',wx.wxDefaultPosition,wx.wxSize(900,620),wx.wxDEFAULT_DIALOG_STYLE);local outer=wx.wxBoxSizer(wx.wxVERTICAL);local columns=wx.wxBoxSizer(wx.wxHORIZONTAL);outer:Add(columns,1,wx.wxEXPAND+wx.wxALL,12);local controls={};local s=editor.document.settings;require('Manual.Chrome').font(dialog,9);
    local function tab(name)local panel=Themes.role(wx.wxPanel(dialog,wx.wxID_ANY),'panel');local box=wx.wxStaticBoxSizer(wx.wxVERTICAL,panel,name);local grid=wx.wxBoxSizer(wx.wxVERTICAL);box:Add(grid,1,wx.wxEXPAND+wx.wxALL,8);panel:SetSizer(box);columns:Add(panel,name=='Editor and Snapping' and 11 or 10,wx.wxEXPAND+wx.wxRIGHT,10);return panel,grid;end
    local pair;
    local function field(panel,grid,key,label,kind,choices,paired)
        local host=Themes.role(wx.wxPanel(panel,wx.wxID_ANY),'panel');local layout=wx.wxBoxSizer(wx.wxVERTICAL);host:SetSizer(layout);local labelControl;
        if kind~='check' then labelControl=Themes.role(wx.wxStaticText(host,wx.wxID_ANY,label),'panel');layout:Add(labelControl,0,wx.wxBOTTOM,3);end
        if paired then if not pair then pair=wx.wxFlexGridSizer(0,2,0,6);pair:AddGrowableCol(0,1);pair:AddGrowableCol(1,1);grid:Add(pair,0,wx.wxEXPAND+wx.wxBOTTOM,6);end;pair:Add(host,1,wx.wxEXPAND);else pair=nil;grid:Add(host,0,wx.wxEXPAND+wx.wxBOTTOM,6);end
        local control;local values,labels={},{};
        if kind=='check' then control=wx.wxCheckBox(host,wx.wxID_ANY,label);control:SetValue(s[key]==true);
        elseif kind=='choice' then for i,v in ipairs(choices)do values[i]=rawtype(v)=='table' and v[1] or v;labels[i]=rawtype(v)=='table' and v[2] or v;end;control=wx.wxChoice(host,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxSize(-1,26),labels);for i,value in ipairs(values)do if value==(s[key] or (key=='units' and 'mm' or '')) then control:SetSelection(i-1);end;end
        else local maximum=key=='zoomStep' and 100 or 100000;control=wx.wxSpinCtrlDouble(host,wx.wxID_ANY,'',wx.wxDefaultPosition,wx.wxSize(-1,26),wx.wxSP_ARROW_KEYS,0,maximum,tonumber(s[key]) or 0,(key=='zoomStep' or key=='numberStart') and 1 or .01);control:SetDigits((key=='zoomStep' or key=='numberStart') and 0 or 2);end
        controls[key]={control=control,kind=kind,label=labelControl,values=values};layout:Add(control,0,wx.wxEXPAND);
    end
    local p,g=tab('Page Layout');field(p,g,'preset','Page size','choice',{{'letter','Letter'},{'legal','Legal'},{'a4','A4'},{'a5','A5'},{'half-letter','Half Letter'},{'custom','Custom'}});field(p,g,'units','Display units','choice',{{'mm','Millimeters'},{'in','Inches'}});field(p,g,'width','Width (mm)',nil,nil,true);field(p,g,'height','Height (mm)',nil,nil,true);pair=nil;field(p,g,'orientation','Orientation','choice',{{'portrait','Portrait'},{'landscape','Landscape'}});
    for _,spec in ipairs({{'marginInner','Inner margin (mm)'},{'marginOuter','Outer margin (mm)'},{'marginTop','Top margin (mm)'},{'marginBottom','Bottom margin (mm)'}})do field(p,g,spec[1],spec[2],nil,nil,true);if spec[1]=='marginOuter' then pair=nil;end;end;pair=nil;
    field(p,g,'bleed','Bleed (all edges)');field(p,g,'facingPages','Facing pages (first page stands alone)','check');field(p,g,'textSize','Default text size (pt)');field(p,g,'textStyle','Basic text style','choice',editor.styleNames());
    controls.preset.control:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED,function()
        local presets={letter={215.9,279.4},legal={215.9,355.6},a4={210,297},a5={148,210},['half-letter']={139.7,215.9}};local v=presets[controls.preset.values[controls.preset.control:GetSelection()+1]];if v then local factor=controls.units.values[controls.units.control:GetSelection()+1]=='in' and 25.4 or 1;controls.width.control:SetValue(v[1]/factor);controls.height.control:SetValue(v[2]/factor);end;
    end);
    p,g=tab('Page Numbers');field(p,g,'pageNumbers','Include page numbers','check');field(p,g,'numberStyle','Page-number style','choice',editor.styleNames());field(p,g,'numberStart','First number',nil,nil,true);field(p,g,'numberFormat','Number format','choice',{{'decimal','1, 2, 3'},{'roman','i, ii, iii'},{'ROMAN','I, II, III'}},true);pair=nil;field(p,g,'numberPosition','Number position','choice',{{'center','Bottom center'},{'left','Bottom left'},{'right','Bottom right'}});
    p,g=tab('Editor and Snapping');g:Add(Themes.role(wx.wxStaticText(p,wx.wxID_ANY,'Editor theme'),'panel'),0,wx.wxBOTTOM,3);local theme=wx.wxChoice(p,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxSize(-1,26),{'Dark','Light'});theme:SetStringSelection(editor.theme);g:Add(theme,0,wx.wxEXPAND+wx.wxBOTTOM,6);field(p,g,'zoomStep','Zoom step (%)');field(p,g,'gridVisible','Show grid (editor only)','check');field(p,g,'gridX','Cell width (mm)',nil,nil,true);field(p,g,'gridY','Cell height (mm)',nil,nil,true);pair=nil;
    for _,spec in ipairs({{'autoSnap','Automatic snapping'},{'snapGrid','Snap to grid'},{'snapPage','Snap to page edges and center'},{'snapMargin','Snap to margins'},{'snapObjects','Snap to objects'}}) do field(p,g,spec[1],spec[2],'check');end
    local hint=wx.wxStaticText(p,wx.wxID_ANY,'Hold Alt while moving an object to snap temporarily. Shift and Control keep their resize behavior.');hint:Wrap(245);g:Add(hint,0,wx.wxEXPAND+wx.wxTOP,4);
    local unitKeys={'width','height','marginInner','marginOuter','marginTop','marginBottom','bleed'};local currentUnit='mm';
    local function units()local unit=controls.units.values[controls.units.control:GetSelection()+1];local factor=(currentUnit=='in' and 25.4 or 1)/(unit=='in' and 25.4 or 1);for _,key in ipairs(unitKeys)do local spec=controls[key];spec.control:SetValue(spec.control:GetValue()*factor);spec.label:SetLabel(spec.label:GetLabel():gsub('%((mm)%)','('..unit..')'):gsub('%((in)%)','('..unit..')'));end;currentUnit=unit;dialog:Layout();end
    units();controls.units.control:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED,units);
    local buttons=wx.wxStdDialogButtonSizer();local apply=wx.wxButton(dialog,wx.wxID_OK,'Apply');local cancel=wx.wxButton(dialog,wx.wxID_CANCEL,'Cancel');buttons:AddButton(apply);buttons:AddButton(cancel);buttons:Realize();outer:Add(buttons,0,wx.wxALIGN_RIGHT+wx.wxALL,10);dialog:SetSizer(outer);local minimum=outer:GetMinSize();local client=dialog:GetClientSize();dialog:SetClientSize(wx.wxSize(math.max(client:GetWidth(),minimum:GetWidth()+8),math.max(client:GetHeight(),minimum:GetHeight()+8)));dialog:Layout();
    apply:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()
        local values={};for key,spec in pairs(controls) do local c=spec.control;if spec.kind=='check' then values[key]=c:GetValue();elseif spec.kind=='choice' then values[key]=spec.values[c:GetSelection()+1];else values[key]=c:GetValue();if not values[key] or values[key]<0 then wx.wxMessageBox('Enter a nonnegative number for '..key,'Manual Options',wx.wxOK+wx.wxICON_ERROR,dialog);return;end;end;end
        if values.units=='in' then for _,key in ipairs(unitKeys)do values[key]=values[key]*25.4;end;end
        for _,key in ipairs({'width','height','textSize','gridX','gridY','zoomStep'}) do if values[key]<=0 then wx.wxMessageBox(key..' must be positive.','Manual Options',wx.wxOK,dialog);return;end;end
        if values.marginInner+values.marginOuter>=values.width or values.marginTop+values.marginBottom>=values.height then wx.wxMessageBox('Margins must fit inside the page.','Manual Options',wx.wxOK,dialog);return;end
        if values.orientation=='landscape' and values.width<values.height or values.orientation=='portrait' and values.width>values.height then values.width,values.height=values.height,values.width;end
        if values.facingPages then values.firstPageAlone=true;end
        editor.change(function()for key,v in pairs(values) do s[key]=v;end;end,s);editor.setTheme(theme:GetStringSelection());dialog:EndModal(wx.wxID_OK);
    end);
    require('Manual.Themes').apply(dialog,editor.theme);dialog:ShowModal();dialog:Destroy();
end
return Options;
