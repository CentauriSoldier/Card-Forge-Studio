-- Native manual editor. HTML is only storage/export, never the editing surface.
local wx=require('wx');local Document=require('Manual.Document');local Text=require('Manual.Text');local Layers=require('Manual.Layers');local Pages=require('Manual.Pages');local TextFlow=require('Manual.TextFlow');local Themes=require('Manual.Themes');local Clipboard=require('Manual.Clipboard');local Editor={};
function Editor.create(parent,model,stylePath,statePath)
    local e={document=model.document,model=model,pageIndex=1,selection=nil,tool='move',typing={},caret=0,anchor=0,theme='Dark',fonts={},flowCache={},contentsCache={},clipCache={},textLayouts={},revision=0};
    e.styles=require('Manual.Styles').open(stylePath);e.images=require('Manual.Images').create(model.root);e.view=wx.wxPanel(parent,wx.wxID_ANY);local outer=wx.wxBoxSizer(wx.wxVERTICAL);e.view:SetSizer(outer);require('Manual.Chrome').font(e.view,9);
    local propertiesFor;local propertyFields={};local choiceLabels={align={left='Left',center='Center',right='Right',justify='Justify'},fit={cover='Fill / crop',contain='Fit',fill='Stretch'},backgroundMode={cover='Fill / crop',contain='Fit',fill='Stretch',tile='Tile'},useMasterBackground={[true]='Use master background',[false]='Use page background'}};
    local preferencePath=statePath and statePath..'.manual.ini';
    local savedTheme=preferencePath and INIFile.GetValue(preferencePath,'Manual','EditorTheme');if not savedTheme or savedTheme=='' then savedTheme=statePath and INIFile.GetValue(statePath,'Manual','EditorTheme');end;if Themes.palettes[savedTheme] then e.theme=savedTheme;end
    e.history=require('Manual.History').create(e);model.history=e.history;model.savedHistoryState=0;
    function e.page() return e.master or e.document.pages[e.pageIndex];end
    function e.selected() return e.selection and Document.find(e.document,e.selection);end
    function e.ownerIndex(o) local _,p=Document.find(e.document,o.id);for i,page in ipairs(e.document.pages) do if page==p then return i;end end;return e.pageIndex;end
    function e.styleNames() local a=Document.copy(e.styles.names);for _,s in ipairs(e.document.manualStyles) do a[#a+1]='manual:'..s.name;end;table.sort(a);return a;end
    function e.invalidate() e.document._byId=nil;e.document._flowPrevious=nil;e.flowCache={};e.contentsCache={};e.textLayouts={};end
    function e.report(err) if e.onError then e.onError(err);else wx.wxMessageBox(tostring(err),'Game Manual',wx.wxOK+wx.wxICON_ERROR,e.view);end;end
    function e.status(s) if e.onStatus then e.onStatus(s);end;end
    function e.changed()
        e.invalidate();
        if e.model.document~=e.document or e.historyRestored then e.historyRestored=false;propertiesFor=nil;if e.textObject then e.textObject=Document.find(e.document,e.textObject.id);e.story=e.textObject and TextFlow.root(e.document,e.textObject);end;end;
        e.revision=e.revision+1;e.invalidate();e.model.document=e.document;e.model.draftChanged=true;
        e.refresh();if e.onChange then e.onChange();end;
    end
    function e.change(fn,target) e.document._byId=nil;e.document._flowPrevious=nil;local before=e.history.begin(target);local ok,err=xpcall(fn,debug.traceback);if not ok then if before.id=="@document" then e.document=Document.decode(before.before);elseif target then local value=Document.decode(before.before);for k in pairs(target) do target[k]=nil;end;for k,v in pairs(value) do target[k]=v;end;end;e.model.document=e.document;e.historyRestored=true;e.invalidate();e.refresh();e.report(err);return false;end;return e.history.commit(before);end
    function e.select(o)
        e.selection=o and o.id or nil;if o then local _,owner=Document.find(e.document,o.id);for i,p in ipairs(e.document.pages) do if p==owner then e.master=nil;e.pageIndex=i;break;end;end;end;e.textObject=nil;e.story=nil;e.linking=nil;e.typing={};e.refresh();
    end
    function e.newObject(kind,x,y)
        local s=e.document.settings;local id=Document.id(e.document);e.document._byId=nil;return {id=id,name=kind,type=kind,x=x or s.marginInner,y=y or s.marginTop,w=50,h=25,opacity=1,rotation=0,visible=true,locked=false,
            fill=(kind=='text' or kind=='artistic' or kind=='image' or kind=='picture' or kind=='picture-ellipse' or kind=='line' or kind=='curve') and 'transparent' or '#c4d7e9',stroke='#152333',strokeWidth=kind=='text' and 0 or .2,radius=4,sides=5,innerRadius=45,
            fontSize=s.textSize,style=s.textStyle,align='left',lineHeight=1.2,html='',src='',fit='cover',rows=3,columns=3,nodes={{0,100},{50,0},{100,100}}};
    end
    function e.format(values)
        local o=e.textObject or e.selected();if not o then return;end
        if e.textObject then
            local story=e.story or o;local a,b=math.min(e.caret,e.anchor),math.max(e.caret,e.anchor);
            if values.list~=nil or values.align then
                local full=Text.plain(Text.read(story));local first=Text.substring(full,0,a):match('.*\n()');a=first and Text.len(Text.substring(full,0,a):sub(1,first-1)) or 0;
                local tail=Text.substring(full,b);local endAt=tail:find('\n',1,true);b=endAt and b+Text.len(tail:sub(1,endAt-1)) or Text.len(full);
            end
            if a~=b then e.change(function()Text.format(story,a,b,values);end,story);else if values.style then e.typing={style=values.style};else for k,v in pairs(values) do e.typing[k]=v;end;end;end
        else e.change(function()if values.style then o.style=values.style;if o.type=='text' or o.type=='artistic' then Text.format(o,0,Text.len(Text.plain(Text.read(o))),{style=values.style});end;end;if values.size then Text.setBlockSize(o,values.size);end;end);end
        if e.canvas then e.canvas.view:SetFocus();end
    end
    function e.insert(s)
        local o=e.story or e.textObject;if not o then return;end;local a,b=math.min(e.caret,e.anchor),math.max(e.caret,e.anchor);
        e.change(function()Text.replace(o,a,b,s,e.typing);end,o);e.caret=a+Text.len(s);e.anchor=e.caret;e.refresh();
    end
    function e.linkTarget(target)
        local from=e.linking;e.linking=nil;if not from then return;end
        e.change(function()assert(not Layers.locked(e.document,target),'Target is locked.');TextFlow.link(e.document,from,target);end);
    end
    function e.editObject(o,x,y)
        e.selection=o.id;e.editingObject=o.id;
        if o.type=='text' or o.type=='artistic' then
            e.tool=o.type;e.textObject=o;e.story=TextFlow.root(e.document,o);e.caret=x and e.canvas.textPoint(o,x,y) or Text.len(Text.plain(Text.read(e.story)));e.anchor=e.caret;
            local runs=Text.slice(Text.read(e.story),math.max(0,e.caret-1),e.caret);e.typing=Document.copy(runs[1] or {style=o.style});e.typing.text=nil;
        elseif o.type=='curve' or o.type=='line' then e.tool='node';
        elseif o.type=='table' then
            local columns=o.columns or 3;local rows=o.rows or 3;local lx,ly=x and Layers.localPoint(e.document,o,x-(require('Manual.Spreads').offset(e.document,e.pageIndex,e.ownerIndex(o)) or 0),y) or 0,0;
            if x then lx,ly=Layers.localPoint(e.document,o,x-(require('Manual.Spreads').offset(e.document,e.pageIndex,e.ownerIndex(o)) or 0),y);end
            local r=math.max(1,math.min(rows,math.floor(ly/o.h*rows)+1));local c=math.max(1,math.min(columns,math.floor(lx/o.w*columns)+1));local cell=require('Manual.Tables').cells(o)[r][c];
            local dialog=wx.wxTextEntryDialog(e.view,'Cell text','Edit table cell',Text.plain(Text.read(cell)));if dialog:ShowModal()==wx.wxID_OK then local s=dialog:GetValue();e.change(function()Text.write(cell,{{text=s,style=o.style}});end);end;dialog:Destroy();e.tool='table';
        else e.tool=o.type;end;e.refresh();e.canvas.view:SetFocus();
    end
    function e.key(event)
        local key=event:GetKeyCode();local ctrl=event:ControlDown();local shift=event:ShiftDown();local o=e.selected();
        if ctrl and key==string.byte('S') then if e.onSave then e.onSave();end;return true;end
        if ctrl and key==string.byte('Z') then if shift then e.history.redo();else e.history.undo();end;return true;end
        if ctrl and key==string.byte('Y') then e.history.redo();return true;end
        if key==wx.WXK_ESCAPE then e.textObject=nil;e.story=nil;e.linking=nil;e.tool='move';e.refresh();return true;end
        if e.textObject then
            local story=e.story;local n=Text.len(Text.plain(Text.read(story)));
            if ctrl and key==string.byte('A') then e.anchor=0;e.caret=n;e.refresh();return true;end
            if ctrl and (key==string.byte('C') or key==string.byte('X')) then Clipboard.write(Text.substring(Text.plain(Text.read(story)),math.min(e.caret,e.anchor),math.max(e.caret,e.anchor)));if key==string.byte('X') then e.insert('');end;return true;end
            if ctrl and key==string.byte('V') then e.insert(Clipboard.read());return true;end
            if ctrl and key==string.byte('B') then e.format({Bold=not e.typing.Bold});return true;end
            if ctrl and key==string.byte('I') then e.format({Italic=not e.typing.Italic});return true;end
            if ctrl and key==string.byte('U') then e.format({Underline=not e.typing.Underline});return true;end
            if key==wx.WXK_LEFT or key==wx.WXK_RIGHT or key==wx.WXK_HOME or key==wx.WXK_END then
                e.caret=key==wx.WXK_HOME and 0 or key==wx.WXK_END and n or math.max(0,math.min(n,e.caret+(key==wx.WXK_LEFT and -1 or 1)));if not shift then e.anchor=e.caret;end;e.refresh();return true;
            end
            if key==wx.WXK_BACK or key==wx.WXK_DELETE then if e.caret==e.anchor then if key==wx.WXK_BACK then e.anchor=math.max(0,e.caret-1);else e.anchor=math.min(n,e.caret+1);end;end;e.insert('');return true;end
            if key==wx.WXK_RETURN or key==wx.WXK_NUMPAD_ENTER then e.insert('\n');return true;end
            
            return false;
        end
        if ctrl and key==string.byte('C') and o then Clipboard.copy(e.page(),o);return true;end
        if ctrl and key==string.byte('X') and o then Clipboard.copy(e.page(),o);e.change(function()assert(not Layers.locked(e.document,o),'Layer is locked.');Layers.remove(e.page(),o);e.selection=nil;end);return true;end
        if ctrl and key==string.byte('V') then e.change(function()e.selection=Clipboard.paste(e.document,e.page()).id;end);return true;end
        if ctrl and key==string.byte('L') and o then e.change(function()o.locked=not shift;end,o);return true;end
        if ctrl and key==string.byte('J') and o then e.change(function()e.selection=Layers.duplicate(e.document,e.page(),o).id;end);return true;end
        if key==wx.WXK_DELETE and o then e.change(function()assert(not Layers.locked(e.document,o),'Layer is locked.');Layers.remove(e.page(),o);e.selection=nil;end);return true;end
        if o and (key==wx.WXK_LEFT or key==wx.WXK_RIGHT or key==wx.WXK_UP or key==wx.WXK_DOWN) then
            e.change(function()assert(not Layers.locked(e.document,o),'Layer is locked.');local step=shift and 10 or 1;if key==wx.WXK_LEFT then o.x=o.x-step;elseif key==wx.WXK_RIGHT then o.x=o.x+step;elseif key==wx.WXK_UP then o.y=o.y-step;else o.y=o.y+step;end;end);return true;
        end
        local tools={[string.byte('V')]='move',[string.byte('A')]='node',[string.byte('T')]='text',[string.byte('M')]='rectangle'};if tools[key] then e.tool=tools[key];e.refresh();return true;end;return false;
    end
    function e.contextMenu(window,o)
        local locked=Layers.locked(e.document,o);local specs={{locked and 'Unlock' or 'Lock',function()e.change(function()o.locked=not o.locked;end,o);end}};
        if not locked then
            specs[#specs+1]={'Duplicate (Ctrl+J)',function()e.change(function()e.selection=Layers.duplicate(e.document,e.page(),o).id;end);end};
            specs[#specs+1]={'Bring to front',function()e.change(function()Layers.order(e.page(),o,#e.page().objects);end);end};specs[#specs+1]={'Send to back',function()e.change(function()Layers.order(e.page(),o,-#e.page().objects);end);end};
            if o.parentId then specs[#specs+1]={'Move out of parent',function()e.change(function()Layers.nest(e.document,e.page(),o,nil);end);end};end
            if o.type=='text' or o.type=='artistic' then specs[#specs+1]={'Edit text',function()e.editObject(o);end};end
            if o.type=='image' or o.type=='picture' or o.type=='picture-ellipse' then specs[#specs+1]={'Choose image',function()local image=e.images.choose(e.view);if image then e.change(function()o.src=image;end,o);end;end};end
            specs[#specs+1]={'Delete',function()e.change(function()Layers.remove(e.page(),o);e.selection=nil;end);end};
        end
        require('Manual.Chrome').menu(window,e,o.name,specs);
    end
    local context=require('Manual.Toolbar').context(e.view,e);e.context=context;outer:Add(context.panel,0,wx.wxEXPAND);context.panel:Hide();
    local body=wx.wxPanel(e.view,wx.wxID_ANY);local row=wx.wxBoxSizer(wx.wxHORIZONTAL);body:SetSizer(row);outer:Add(body,1,wx.wxEXPAND);
    local rail=Themes.role(wx.wxPanel(body,wx.wxID_ANY),'rail');local tools=wx.wxBoxSizer(wx.wxVERTICAL);rail:SetSizer(tools);rail:SetMinSize(wx.wxSize(48,-1));row:Add(rail,0,wx.wxEXPAND+wx.wxRIGHT,4);e.toolButtons={};
    local function tool(kind,label,glyph)
        local button=require('Manual.Chrome').action(rail,kind,label,e,function()e.tool=kind;e.editingObject=nil;e.textObject=nil;e.story=nil;e.refresh();end,'rail');tools:Add(button,0,wx.wxALL,5);e.toolButtons[kind]=button;return button;
    end
    tool('move','Move (V)','↖');tool('node','Node (A)','◇');tools:Add(wx.wxStaticLine(rail,wx.wxID_ANY),0,wx.wxEXPAND+wx.wxALL,5);tool('text','Frame Text (T)','T');tool('artistic','Artistic Text','A');tool('table','Table','▦');tool('toc','Table of Contents','☷');tools:Add(wx.wxStaticLine(rail,wx.wxID_ANY),0,wx.wxEXPAND+wx.wxALL,5);tool('image','Place Image','▧');tool('picture','Picture Frame','⊠');tool('picture-ellipse','Ellipse Frame','⊗');tools:Add(wx.wxStaticLine(rail,wx.wxID_ANY),0,wx.wxEXPAND+wx.wxALL,5);tool('line','Line','╲');tool('curve','Curve','⌒');
    local shape=tool('rectangle','Shapes (M)','□');shape:Connect(wx.wxEVT_LEFT_UP,function()require('Manual.Chrome').shapes(shape,e);end);
    local leftContainer=Themes.role(wx.wxPanel(body,wx.wxID_ANY),'panel');local leftOuter=wx.wxBoxSizer(wx.wxVERTICAL);leftContainer:SetSizer(leftOuter);leftContainer:SetMinSize(wx.wxSize(150,-1));row:Add(leftContainer,0,wx.wxEXPAND);
    local collapseLeft=wx.wxButton(leftContainer,wx.wxID_ANY,'‹',wx.wxDefaultPosition,wx.wxSize(20,22),wx.wxBORDER_NONE);collapseLeft:SetToolTip('Collapse / restore Pages and Styles');leftOuter:Add(collapseLeft,0,wx.wxALIGN_RIGHT);
    local left=Themes.role(wx.wxScrolledWindow(leftContainer,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxSize(150,-1),wx.wxVSCROLL+wx.wxBORDER_NONE),'panel');left:SetScrollRate(0,10);local ls=wx.wxBoxSizer(wx.wxVERTICAL);left:SetSizer(ls);leftOuter:Add(left,1,wx.wxEXPAND);e.left=left;e.leftContainer=leftContainer;
    collapseLeft:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()left:Show(not left:IsShown());leftContainer:SetMinSize(wx.wxSize(left:IsShown() and 150 or 24,-1));collapseLeft:SetLabel(left:IsShown() and '‹' or '›');e.view:Layout();e.canvas.refresh();end);
    local function pageBar(title,master)
        ls:Add(require('Manual.Chrome').heading(left,title,e),0,wx.wxEXPAND+wx.wxALL,8);local buttons=wx.wxBoxSizer(wx.wxHORIZONTAL);
        for _,spec in ipairs({{'+','New page',function()e.change(function()local p=Pages.add(e.document,master);if master then e.master=p;else e.master=nil;e.pageIndex=#e.document.pages;end;end);end},{'⧉','Duplicate page',function()e.change(function()local p=Pages.duplicate(e.document,e.page());if master then e.master=p;else e.pageIndex=#e.document.pages;end;end);end},
            {'−','Delete page',function()e.change(function()Pages.remove(e.document,e.page());e.master=nil;e.pageIndex=math.min(e.pageIndex,#e.document.pages);end);end}}) do if master or spec[2]~='Duplicate page' then local b=wx.wxButton(left,wx.wxID_ANY,master and spec[2]=='Duplicate page' and 'Duplicate' or spec[1],wx.wxDefaultPosition,wx.wxSize(master and spec[2]=='Duplicate page' and 68 or 22,26),wx.wxBORDER_SIMPLE);b:SetToolTip(spec[2]);buttons:Add(b,0,wx.wxRIGHT,3);b:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,spec[3]);end;end
        if not master then for _,spec in ipairs({{'↑','Move page earlier',-1},{'↓','Move page later',1}})do local button=wx.wxButton(left,wx.wxID_ANY,spec[1],wx.wxDefaultPosition,wx.wxSize(30,25),wx.wxBORDER_NONE);button:SetToolTip(spec[2]);buttons:Add(button,0,wx.wxRIGHT,3);button:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()e.change(function()local page=e.document.pages[e.pageIndex];Pages.move(e.document,page,spec[3]);for i,p in ipairs(e.document.pages)do if p==page then e.pageIndex=i;break;end;end;end);end);end;end
        ls:Add(buttons,0,wx.wxALL,4);local list=require('Manual.Panes').create(left,wx.wxSize(134,master and 140 or 230),e,master and 'masters' or 'pages',function(index)if master then e.master=e.document.masters[index];else e.master=nil;e.pageIndex=index;end;e.select(nil);e.canvas.fit();end);
        ls:Add(list.view,0,wx.wxEXPAND+wx.wxALL,3);return list;
    end
    e.masterList=pageBar('Masters',true);
    for _,spec in ipairs({{'Apply to current page',false},{'Apply to all pages',true}})do local button=wx.wxButton(left,wx.wxID_ANY,spec[1]);require('Manual.Chrome').font(button,8);ls:Add(button,0,wx.wxEXPAND+wx.wxALL,3);button:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()if e.master then e.change(function()if spec[2] then require('Manual.MasterPages').apply(e.document,e.master,true);else e.document.pages[e.pageIndex].masterId=e.master.id;end;end);end;end);end
    e.pageList=pageBar('Pages',false);ls:Add(require('Manual.Chrome').heading(left,'Styles',e),0,wx.wxEXPAND+wx.wxALL,8);e.styleSearch=wx.wxTextCtrl(left,wx.wxID_ANY,'');e.styleSearch:SetHint('Find a style');ls:Add(e.styleSearch,0,wx.wxEXPAND+wx.wxALL,3);e.styleSearch:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED,function()e.styleSignature=nil;e.refresh();end);e.styleList=require('Manual.Panes').create(left,wx.wxSize(134,230),e,'styles',function(i)local name=e.styleList.items[i].label;e.format({style=name});end);ls:Add(e.styleList.view,0,wx.wxEXPAND+wx.wxALL,8);
    e.canvas=require('Manual.Canvas').create(body,e,false);row:Add(e.canvas.view,1,wx.wxEXPAND);
    local rightContainer=Themes.role(wx.wxPanel(body,wx.wxID_ANY),'inspector');rightContainer:SetMinSize(wx.wxSize(235,-1));local rightOuter=wx.wxBoxSizer(wx.wxVERTICAL);rightContainer:SetSizer(rightOuter);row:Add(rightContainer,0,wx.wxEXPAND);
    local collapseRight=wx.wxButton(rightContainer,wx.wxID_ANY,'›',wx.wxDefaultPosition,wx.wxSize(20,22),wx.wxBORDER_NONE);collapseRight:SetToolTip('Collapse / restore Layers and Properties');rightOuter:Add(collapseRight,0,wx.wxALIGN_RIGHT);
    local right=Themes.role(wx.wxScrolledWindow(rightContainer,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxSize(235,-1),wx.wxVSCROLL+wx.wxBORDER_NONE),'inspector');right:SetScrollRate(0,10);local rs=wx.wxBoxSizer(wx.wxVERTICAL);right:SetSizer(rs);rightOuter:Add(right,1,wx.wxEXPAND);e.right=right;e.rightContainer=rightContainer;
    collapseRight:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()right:Show(not right:IsShown());if e.layerActionPanel then e.layerActionPanel:Show(right:IsShown());end;rightContainer:SetMinSize(wx.wxSize(right:IsShown() and 235 or 24,-1));collapseRight:SetLabel(right:IsShown() and '›' or '‹');e.view:Layout();e.canvas.refresh();end);
    rs:Add(require('Manual.Chrome').heading(right,'Layers',e),0,wx.wxEXPAND+wx.wxALL,8);e.layerRows={};
    e.layerList=require('Manual.Panes').create(right,wx.wxSize(219,230),e,'layers',function(i)e.select(e.layerRows[i]);end,function(i,card)
        local o=e.layerRows[i];if o then local input=wx.wxTextCtrl(card,wx.wxID_ANY,o.name,wx.wxPoint(5,3),wx.wxSize(card:GetClientSize():GetWidth()-52,25),wx.wxTE_PROCESS_ENTER);local done=false;local function finish(commit)if done then return;end;done=true;local value=input:GetValue();input:Destroy();if commit and value~='' then e.change(function()o.name=value;end,o);else card:Refresh();end;end;input:Connect(wx.wxEVT_COMMAND_TEXT_ENTER,function()finish(true);end);input:Connect(wx.wxEVT_KILL_FOCUS,function(event)finish(true);event:Skip();end);input:Connect(wx.wxEVT_KEY_DOWN,function(event)if event:GetKeyCode()==wx.WXK_ESCAPE then finish(false);else event:Skip();end;end);input:SetFocus();input:SelectAll();end;
    end,function(from,to)local source,target=e.layerRows[from],e.layerRows[to];if source and target then e.change(function()assert(not Layers.locked(e.document,source),'Layer is locked.');Layers.nest(e.document,e.page(),source,target);e.selection=source.id;end);end;end);
    local moveToPage=wx.wxButton(right,wx.wxID_ANY,'Drop here to move to page',wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxBORDER_SIMPLE);moveToPage:SetToolTip('Move the selected nested layer out of its parent');rs:Add(moveToPage,0,wx.wxEXPAND+wx.wxALL,3);
    local function detach(o)if o and o.parentId then e.change(function()assert(not Layers.locked(e.document,o),'Layer is locked.');Layers.nest(e.document,e.page(),o,nil);end);end;end
    moveToPage:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()detach(e.selected());end);moveToPage:Connect(wx.wxEVT_LEFT_UP,function(event)local index=e.layerList.dragging;if index then detach(e.layerRows[index]);e.layerList.dragging=nil;end;event:Skip();end);
    rs:Add(e.layerList.view,0,wx.wxEXPAND+wx.wxALL,8);
    rs:Add(require('Manual.Chrome').heading(right,'Properties',e),0,wx.wxEXPAND+wx.wxALL,8);local props=Themes.role(wx.wxScrolledWindow(right,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxSize(219,300),wx.wxBORDER_SIMPLE),'field');e.properties=props;rs:Add(props,0,wx.wxEXPAND+wx.wxALL,8);
    local actionPanel=Themes.role(wx.wxPanel(rightContainer,wx.wxID_ANY),'toolbar');e.layerActionPanel=actionPanel;local layerActions=wx.wxBoxSizer(wx.wxHORIZONTAL);for _,spec in ipairs({{'↑','Bring forward',function(o)Layers.order(e.page(),o,1);end},{'↓','Send backward',function(o)Layers.order(e.page(),o,-1);end},{'⧉','Duplicate',function(o)e.selection=Layers.duplicate(e.document,e.page(),o).id;end},{'⌫','Delete',function(o)assert(not Layers.locked(e.document,o),'Layer is locked.');Layers.remove(e.page(),o);e.selection=nil;end},{'🔒','Lock',function(o)o.locked=true;end},{'🔓','Unlock',function(o)o.locked=false;end}}) do
        local names={['↑']='up',['↓']='down',['⧉']='duplicate',['⌫']='delete',['🔒']='lock',['🔓']='unlock'};local button=require('Manual.Chrome').action(actionPanel,names[spec[1]],spec[2],e,function()local o=e.selected();if o then e.change(function()spec[3](o);end);end;end);layerActions:Add(button,1,wx.wxEXPAND+wx.wxALL,3);
    end;actionPanel:SetSizer(layerActions);rightOuter:Add(actionPanel,0,wx.wxEXPAND);
    function e.buildProperties()
        local o=e.selected();local p=e.page();local previous=o and TextFlow.previous(e.document,o);local key=table.concat({o and o.id or p.id,o and o.parentId or '',o and o.flowNext or '',previous and previous.id or '',p.masterId or '',tostring(o and o.locked)},'|');if key==propertiesFor then return;end;propertiesFor=key;propertyFields={};props:DestroyChildren();local grid=wx.wxBoxSizer(wx.wxVERTICAL);props:SetSizer(grid);local pair;
        local function field(target,name,label,kind,choices,paired)
            local host=Themes.role(wx.wxPanel(props,wx.wxID_ANY),'field');local layout=wx.wxBoxSizer(wx.wxVERTICAL);host:SetSizer(layout);layout:Add(Themes.role(wx.wxStaticText(host,wx.wxID_ANY,label),'field'),0,wx.wxBOTTOM,3);if paired then if not pair then pair=wx.wxFlexGridSizer(0,2,6,6);pair:AddGrowableCol(0,1);pair:AddGrowableCol(1,1);grid:Add(pair,0,wx.wxEXPAND+wx.wxALL,6);end;pair:Add(host,1,wx.wxEXPAND);else pair=nil;grid:Add(host,0,wx.wxEXPAND+wx.wxALL,6);end;local c;
            if kind=='choice' then local labels={};for i,value in ipairs(choices)do labels[i]=choiceLabels[name] and choiceLabels[name][value] or value;end;c=wx.wxChoice(host,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxSize(-1,26),labels);for i,value in ipairs(choices)do if value==(name=='useMasterBackground' and target[name]==nil and true or target[name]) then c:SetSelection(i-1);end;end;
            elseif kind=='check' then c=wx.wxCheckBox(host,wx.wxID_ANY,'');c:SetValue(target[name]==true);
            elseif kind=='color' then c=require('Manual.Chrome').colour(host,target[name]=='transparent' and '#ffffff' or target[name],e);
            elseif rawtype(target[name])=='number' then kind='number';local low,high,step=-100000,100000,.1;if name=='opacity' then low,high,step=0,1,.01;elseif name=='depth' then low,high,step=1,6,1;elseif name=='rows' or name=='columns' or name=='sides' then low,high,step=1,1000,1;elseif name=='w' or name=='h' or name=='fontSize' then low=.1;end;c=wx.wxSpinCtrlDouble(host,wx.wxID_ANY,'',wx.wxDefaultPosition,wx.wxSize(-1,26),wx.wxSP_ARROW_KEYS,low,high,target[name],step);c:SetDigits(step==1 and 0 or 2);
            else c=wx.wxTextCtrl(host,wx.wxID_ANY,tostring(target[name] or ''),wx.wxDefaultPosition,wx.wxSize(-1,26),wx.wxTE_PROCESS_ENTER);end;layout:Add(c.view or c,0,wx.wxEXPAND);propertyFields[#propertyFields+1]={target=target,key=name,control=c,kind=kind,choices=choices};
            local function commit()
                local value;if kind=='color' then local color=c:GetColour();value=string.format('#%02x%02x%02x',color:Red(),color:Green(),color:Blue());elseif kind=='choice' then value=choices[c:GetSelection()+1];else value=c:GetValue();end;
                if rawtype(target[name])=='number' then value=tonumber(value);if not value then return;end;if (name=='w' or name=='h' or name=='fontSize' or name=='rows' or name=='columns') and value<=0 then return;end;if name=='opacity' then value=math.max(0,math.min(1,value));end;end
                e.change(function()if name=='fontSize' and (target.type=='text' or target.type=='artistic') then Text.setBlockSize(target,value);elseif name=='style' and (target.type=='text' or target.type=='artistic') then target.style=value;Text.format(target,0,Text.len(Text.plain(Text.read(target))),{style=value});else target[name]=value;end;end,target.id and target or nil);
            end
            c:Connect(kind=='choice' and wx.wxEVT_COMMAND_CHOICE_SELECTED or kind=='check' and wx.wxEVT_COMMAND_CHECKBOX_CLICKED or kind=='color' and wx.wxEVT_COMMAND_COLOURPICKER_CHANGED or kind=='number' and wx.wxEVT_SPINCTRLDOUBLE or wx.wxEVT_COMMAND_TEXT_ENTER,commit);if not kind or kind=='number' then c:Connect(wx.wxEVT_KILL_FOCUS,function(event)commit();event:Skip();end);end
        end
        local function button(label,callback)pair=nil;local b=wx.wxButton(props,wx.wxID_ANY,label);grid:Add(b,0,wx.wxEXPAND+wx.wxALL,6);b:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,callback);end
        if o then
            field(o,'name','Name');for _,spec in ipairs({{'x','X (mm)'},{'y','Y (mm)'},{'w','Width (mm)'},{'h','Height (mm)'},{'rotation','Rotation (degrees)'},{'opacity','Opacity (0–1)'},{'hue','Hue shift (degrees)'},{'fill','Fill color'},{'stroke','Border color'},{'strokeWidth','Border width (mm)'}}) do field(o,spec[1],o.parentId and (spec[1]=='x' or spec[1]=='y') and (spec[1]=='x' and 'X in parent (mm)' or 'Y in parent (mm)') or spec[2],(spec[1]=='fill' or spec[1]=='stroke') and 'color' or nil,nil,spec[1]=='x' or spec[1]=='y' or spec[1]=='w' or spec[1]=='h');if spec[1]=='fill' then button('Transparent fill',function()e.change(function()o.fill='transparent';end,o);end);end;end;
            if o.type=='text' or o.type=='artistic' or o.type=='table' then field(o,'style','Block style','choice',e.styleNames());field(o,'fontSize','Block text size (pt)');field(o,'lineHeight','Line spacing');field(o,'align','Text alignment','choice',{'left','center','right','justify'});end
            if o.type=='table' then field(o,'rows','Rows');field(o,'columns','Columns');end
            if o.type=='rounded' then field(o,'radius','Radius (mm)');end;if o.type=='star' or o.type=='polygon' then field(o,'sides','Points / sides');field(o,'innerRadius','Inner radius (%)');end
            if o.type=='image' or o.type=='picture' or o.type=='picture-ellipse' then field(o,'fit','Image fitting','choice',{'cover','contain','fill'});field(o,'focusX','Crop focus X (%)');field(o,'focusY','Crop focus Y (%)');field(o,'acrossSpread','Across page pair','check');button('Replace image',function()local src=e.images.choose(e.view);if src then e.change(function()o.src=src;end);end;end);end
            if o.parentId then button('Detach layer',function()e.change(function()Layers.nest(e.document,e.page(),o,nil);end);end);end
            if o.type=='toc' then
                local config=e.document.contents;field(config,'depth','Contents tiers');field(config,'pageNumbers','Page numbers','check');field(o,'fontSize','Frame text size (pt)');button('Update table of contents',function()e.change(function()require('Manual.Contents').update(e.document);end);end);
                for level=1,6 do local tier=config.tiers[level];grid:Add(require('Manual.Chrome').heading(props,'Tier '..level,e),0,wx.wxEXPAND+wx.wxALL,6);field(tier,'source','Heading source style','choice',e.styleNames());field(tier,'style','Entry display style','choice',e.styleNames());field(tier,'indent','Indent (mm)');field(tier,'leader','Leader','choice',{'dots','line','none'});field(tier,'align','Text alignment','choice',{'left','center','right'});end
            end
            if o.type=='text' or o.type=='artistic' or o.type=='toc' then button('Link to next frame',function()e.linking=o;e.status('Click the next frame.');end);if o.flowNext then button('Unlink next frame',function()e.change(function()if o.type=='toc' then o.flowNext=nil;else local root=TextFlow.root(e.document,o);TextFlow.unlink(e.document,o,assert(e.flowCache[root.id]));end;end);end);end;local previous=TextFlow.previous(e.document,o);if previous then button('Unlink previous frame',function()e.change(function()if o.type=='toc' then previous.flowNext=nil;else local root=TextFlow.root(e.document,o);TextFlow.unlink(e.document,previous,assert(e.flowCache[root.id]));end;end);end);end;local nextFrame=o.flowNext and Document.find(e.document,o.flowNext);grid:Add(wx.wxStaticText(props,wx.wxID_ANY,nextFrame and 'Next: '..nextFrame.name or 'No next frame'),0,wx.wxALL,6);end
        else
            if not e.master then
                grid:Add(wx.wxStaticText(props,wx.wxID_ANY,'Master page'),0,wx.wxALL,6);local names={'None'};local selected=0;for i,m in ipairs(e.document.masters)do names[#names+1]=m.name;if p.masterId==m.id then selected=i;end;end;local master=wx.wxChoice(props,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxDefaultSize,names);master:SetSelection(selected);grid:Add(master,0,wx.wxEXPAND+wx.wxALL,6);master:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED,function()e.change(function()p.masterId=master:GetSelection()>0 and e.document.masters[master:GetSelection()].id or nil;end);end);
                if p.masterId then field(p,'useMasterBackground','Background source','choice',{true,false});end
            end
            field(p,'name',e.master and 'Master name' or 'Page name');field(p,'background','Background','color');field(p,'backgroundMode','Background image mode','choice',{'cover','contain','tile'});button('Choose background image',function()local src=e.images.choose(e.view);if src then e.change(function()p.backgroundImage=src;end);end;end);button('Remove background image',function()e.change(function()p.backgroundImage='';end);end);
        end;props:Enable(not o or not Layers.locked(e.document,o));props:SetMinSize(wx.wxSize(219,grid:GetMinSize():GetHeight()+12));props:FitInside();props:Layout();right:FitInside();Themes.apply(props,e.theme);
    end
    function e.refresh()
        if not e.canvas then return;end
        e.context.panel:Show(e.textObject~=nil);e.pageList:Clear();for i,p in ipairs(e.document.pages) do e.pageList:Append(i..'. '..p.name);end;e.pageList:SetSelection(not e.master and e.pageIndex-1 or -1);e.pageList:Flush();
        e.masterList:Clear();for _,p in ipairs(e.document.masters) do e.masterList:Append(p.name);end;e.masterList:SetSelection(-1);for i,p in ipairs(e.document.masters)do if p==e.master then e.masterList:SetSelection(i-1);end;end;e.masterList:Flush();
        e.layerRows={};e.layerList:Clear();local function append(id,depth)local children=Layers.children(e.page(),id);for i=#children,1,-1 do local o=children[i];e.layerRows[#e.layerRows+1]=o;e.layerList:Append((o.name or o.type),({text='Frame Text',artistic='Artistic Text',image='Image',picture='Picture Frame',['picture-ellipse']='Ellipse Picture Frame',rounded='Rounded Rectangle',toc='Table of Contents',table='Table'})[o.type] or o.type,depth,o.id);if o.id==e.selection then e.layerList:SetSelection(#e.layerRows-1);end;append(o.id,depth+1);end;end;append(nil,0);if not e.selection then e.layerList:SetSelection(-1);end;e.layerList:Flush();
        e.buildProperties();for _,f in ipairs(propertyFields) do local c=f.control;local value=f.target[f.key];if f.kind=='choice' then for i,v in ipairs(f.choices)do if v==value then c:SetSelection(i-1);break;end;end;elseif f.kind=='check' then c:SetValue(value==true);elseif f.kind=='color' then c:SetColour(Themes.colour(value=='transparent' and '#ffffff' or value));elseif f.kind=='number' then if c~=wx.wxWindow.FindFocus() and c:GetValue()~=value then c:SetValue(value);end;elseif c~=wx.wxWindow.FindFocus() and c:GetValue()~=tostring(value or '') then c:SetValue(tostring(value or ''));end;end;
        local names={};local query=e.styleSearch:GetValue():lower();for _,name in ipairs(e.styleNames())do if name:lower():find(query,1,true) then names[#names+1]=name;end;end;local signature=table.concat(names,'\n');if e.styleSignature~=signature then e.styleSignature=signature;e.styleList:Clear();for _,name in ipairs(names) do e.styleList:Append(name);end;end;e.styleList:Flush();left:FitInside();right:FitInside();for kind,b in pairs(e.toolButtons) do b:SetBackgroundColour(Themes.colour(e.tool==kind and Themes.palettes[e.theme].accent or Themes.palettes[e.theme].surface));end
        e.view:Layout();e.canvas.refresh();if e.preview then e.preview.refresh();end
    end
    function e.setTheme(name)
        e.theme=name;Themes.apply(e.view,name);if e.nativeToolbar then Themes.apply(e.nativeToolbar.panel,name);require('Manual.Toolbar').theme(e.nativeToolbar,name);end;if preferencePath then INIFile.SetValue(preferencePath,'Manual','EditorTheme',name);end;e.refresh();
    end
    function e.interfaceScale(delta)
        e.uiSize=math.max(8,math.min(18,(e.uiSize or 9)+delta));local font=wx.wxFont(e.uiSize,wx.wxFONTFAMILY_DEFAULT,wx.wxFONTSTYLE_NORMAL,wx.wxFONTWEIGHT_NORMAL,false,'Segoe UI');local function apply(w)w:SetFont(font);local children=w:GetChildren();for i=0,children:GetCount()-1 do apply(children:Item(i):GetData():DynamicCast("wxWindow"));end;end;apply(e.view);font:delete();e.view:Layout();
    end
    function e.close()if e.contextPopup then e.contextPopup:Dismiss();e.contextPopup:Destroy();e.contextPopup=nil;end;if e.shapePopup then e.shapePopup:Dismiss();e.shapePopup:Destroy();e.shapePopup=nil;end;e.images.close();for _,item in pairs(e.fonts._importMasks or {})do item.bitmap:delete();end;e.fonts._importMasks=nil;for _,r in pairs(e.clipCache) do r:delete();end;e.clipCache={};end
    e.setTheme(e.theme);e.refresh();return e;
end
return Editor;
