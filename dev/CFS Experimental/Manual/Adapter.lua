-- Browser implementation behind the shared Manual entry points.
local wx=require('wx');local Common=require('Windows.Editors.Common');local HTML=require('Manual.HTML');local Styles=require('Manual.Styles');local WindowState=require('Windows.WindowState');local Adapter={kind='browser'};
-- Snapshot codec used only by this adapter; original editor modules stay unchanged.
local Codec=(function()
-- Native document model; the existing HTML snapshot remains readable and writable.
local Document = {};
Document.null = {};
function Document.copy(v)
    if (rawtype(v) ~= "table") then return v; end
    local r = {}; for k,x in pairs(v) do if rawtype(k)~='string' or k:sub(1,1)~='_' then r[k]=Document.copy(x);end;end; return r;
end
function Document.hex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()); end)); end
function Document.unhex(s)
    assert(#s % 2 == 0 and not s:find("[^%x]"), "Invalid manual snapshot.");
    return (s:gsub("..", function(c) return string.char(tonumber(c, 16)); end));
end
function Document.decode(s)
    local i, n = 1, #s;
    local function skip() local _, b = s:find("^[ \r\n\t]*", i); i = (b or i - 1) + 1; end
    local value;
    local function stringValue()
        assert(s:sub(i,i) == '"', "Expected JSON string."); i = i + 1; local a = {};
        while i <= n do
            local c = s:sub(i,i); i = i + 1;
            if c == '"' then return table.concat(a); end
            if c == '\\' then
                local e = s:sub(i,i); i = i + 1;
                local escapes = {['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'};
                if e == 'u' then
                    local h = s:sub(i,i+3); assert(#h == 4 and not h:find('[^%x]'), 'Invalid Unicode escape.'); i=i+4;
                    local u=tonumber(h,16);
                    if u>=0xd800 and u<=0xdbff then
                        assert(s:sub(i,i+1)=='\\u','Missing Unicode surrogate.'); i=i+2;
                        local low=tonumber(s:sub(i,i+3),16); i=i+4;
                        assert(low and low>=0xdc00 and low<=0xdfff,'Invalid Unicode surrogate.'); u=0x10000+(u-0xd800)*1024+low-0xdc00;
                    else assert(u<0xdc00 or u>0xdfff,'Invalid Unicode surrogate.'); end
                    a[#a+1]=utf8.char(u);
                else assert(escapes[e], 'Invalid JSON escape.'); a[#a+1]=escapes[e]; end
            else assert(c:byte()>=32,'Invalid JSON control character.'); a[#a+1]=c; end
        end
        error('Unclosed JSON string.');
    end
    value=function(depth)
        assert(depth < 100,'Manual nesting is too deep.'); skip(); local c=s:sub(i,i);
        if c=='"' then return stringValue(); end
        if c=='{' or c=='[' then
            local object=c=='{'; local close=object and '}' or ']'; local t={}; i=i+1; skip();
            if s:sub(i,i)==close then i=i+1; return t; end
            while true do
                skip(); local k=object and stringValue() or #t+1;
                if object then skip(); assert(s:sub(i,i)==':','Expected JSON colon.'); i=i+1; end
                assert(t[k]==nil,'Duplicate JSON key.'); t[k]=value(depth+1); skip();
                local sep=s:sub(i,i); i=i+1; if sep==close then return t; end; assert(sep==',','Expected JSON comma.');
            end
        end
        for literal, result in pairs({['true']=true,['false']=false,['null']=Document.null}) do
            if s:sub(i,i+#literal-1)==literal then i=i+#literal; return result; end
        end
        local first,last=s:find('^-?%d+%.?%d*[eE]?[+-]?%d*',i); local token=first and s:sub(first,last);
        assert(token and token~='', 'Invalid JSON value at '..i); local x=tonumber(token);
        assert(x and x==x and math.abs(x)<math.huge,'Invalid JSON number.'); i=i+#token; return x;
    end
    local t=value(0); skip(); assert(i>n,'Trailing JSON data.'); return t;
end
function Document.encode(t)
    local function quote(s) return '"'..s:gsub('[%z\1-\31\\"]',function(c)
        local e={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}; return e[c] or string.format('\\u%04x',c:byte()); end)..'"'; end
    local seen={}; local function encode(v)
        local kind=rawtype(v);
        if v==Document.null then return 'null'; end
        if kind=='string' then return quote(v); end
        if kind=='number' then assert(v==v and math.abs(v)<math.huge,'Nonfinite manual number.'); return string.format('%.17g',v); end
        if kind=='boolean' then return tostring(v); end
        assert(kind=='table' and not seen[v],'Invalid or circular manual data.'); seen[v]=true;
        local count, array=0,true; for k in pairs(v) do count=count+1; if rawtype(k)~='number' or k<1 or k%1~=0 then array=false; end end
        array=array and count==#v and count>0; local a={};
        if array then for _,x in ipairs(v) do a[#a+1]=encode(x); end
        else local keys={}; for k in pairs(v) do assert(rawtype(k)=='string','Invalid manual key.'); if k:sub(1,1)~='_' then keys[#keys+1]=k; end end; table.sort(keys);
            for _,k in ipairs(keys) do a[#a+1]=quote(k)..':'..encode(v[k]); end end
        seen[v]=nil; return (array and '[' or '{')..table.concat(a,',')..(array and ']' or '}');
    end
    return encode(t);
end
function Document.defaults()
    return {preset='letter',units='mm',width=215.9,height=279.4,orientation='portrait',marginInner=17,marginOuter=17,marginTop=17,marginBottom=18,bleed=3,
        textStyle='BASE',textSize=12,pageNumbers=false,numberStyle='BASE',numberStart=1,numberFormat='decimal',numberPosition='center',gridVisible=false,gridX=5,gridY=5,
        autoSnap=false,snapGrid=true,snapPage=true,snapMargin=true,snapObjects=true,facingPages=false,firstPageAlone=true,zoomStep=4};
end
function Document.new()
    return {version=2,nextId=1,settings=Document.defaults(),pages={{id='page-1',name='Page 1',background='#ffffff',objects={}}},masters={},manualStyles={},contents={entries={},tiers={},depth=6,pageNumbers=true}};
end
function Document.id(t,prefix)
    local id; repeat id=(prefix or 'object')..'-'..t.nextId; t.nextId=t.nextId+1; until not Document.find(t,id); return id;
end
function Document.find(t,id)
    if not t._byId then local index={};for _,pages in ipairs({t.pages,t.masters}) do for _,p in ipairs(pages) do index[p.id]={p,p};for i,o in ipairs(p.objects or {}) do index[o.id]={o,p,i};end;end;end;t._byId=index;end
    local entry=t._byId[id];if entry then return table.unpack(entry);end
end
function Document.normalize(t)
    assert(rawtype(t)=='table' and rawtype(t.pages)=='table' and #t.pages>0,'Manual has no pages.');
    t.settings=t.settings or {}; for k,v in pairs(Document.defaults()) do if t.settings[k]==nil then t.settings[k]=v; end end
    t.masters=t.masters or {}; t.manualStyles=t.manualStyles or {}; t.contents=t.contents or {entries={},tiers={}}; t.nextId=t.nextId or 1;t.contents.depth=t.contents.depth or 6;for level=1,6 do t.contents.tiers[level]=t.contents.tiers[level] or {source='',style=t.settings.textStyle,indent=(level-1)*4,leader='dots',align='left'};t.contents.tiers[level].align=t.contents.tiers[level].align or 'left';end;
    local ids={};
    for _,pages in ipairs({t.pages,t.masters}) do for _,p in ipairs(pages) do
        assert(rawtype(p.id)=='string' and not ids[p.id],'Duplicate page identifier.'); ids[p.id]=true; p.objects=p.objects or {};
        for _,o in ipairs(p.objects) do
            assert(rawtype(o.id)=='string' and not ids[o.id],'Duplicate object identifier.'); ids[o.id]=true;
            for _,k in ipairs({'x','y','w','h'}) do assert(rawtype(o[k])=='number' and o[k]==o[k] and math.abs(o[k])<math.huge,'Invalid object geometry.'); end
            assert(o.w>0 and o.h>0,'Object dimensions must be positive.');
        end
        for _,o in ipairs(p.objects) do
            local seen={}; local current=o;
            while current.parentId do
                assert(not seen[current.id],'Circular layer nesting.'); seen[current.id]=true;
                local parent,parentPage=Document.find(t,current.parentId); assert(parent and parentPage==p,'Missing parent layer.'); current=parent;
            end
        end
    end end
    assert(t.settings.width>0 and t.settings.height>0,'Invalid page size.'); return t;
end
function Document.load(s)
    local h=s:match('id="cfs%-manual%-state"[^>]*data%-state="([%x]+)"');
    if h then return Document.normalize(Document.decode(Document.unhex(h))); end
    local t=Document.new(); t.pages[1].objects={{id='object-1',name='Imported content',type='text',x=17,y=17,w=182,h=244,html=s,fontSize=12,style='BASE'}}; t.nextId=2; return t;
end
return Document;

end)();
WindowState.register('Manual',{savePosition=true,saveSize=true,saveVisible=false});
local function runsHTML(runs)
    local a={}; local currentList;
    for _,r in ipairs(runs) do
        if r.list~=currentList then if currentList then a[#a+1]='</li></'..currentList..'>'; end; currentList=r.list; if currentList then a[#a+1]='<'..currentList..'><li>'; end end
        local attributes={}; if r.style and r.style~='' then attributes[#attributes+1]='data-style="'..HTML.escape(r.style)..'"'; end
        local css={}; if r.size then css[#css+1]='font-size:'..r.size..'pt'; end
        if r.fontFamily then css[#css+1]='font-family:'..r.fontFamily; end; if r.colorCSS then css[#css+1]='color:'..r.colorCSS; end
        for _,flag in ipairs({{'Bold','font-weight','bold','normal'},{'Italic','font-style','italic','normal'},{'Underline','text-decoration','underline','none'}}) do
            if r[flag[1]]~=nil then css[#css+1]=flag[2]..':'..(r[flag[1]] and flag[3] or flag[4]); end end
        if #css>0 then attributes[#attributes+1]='style="'..HTML.escape(table.concat(css,';'))..'"'; end
        local s=HTML.escape(r.text):gsub('\n',currentList and '</li><li>' or '<br>'); a[#a+1]='<span '..table.concat(attributes,' ')..'>'..s..'</span>';
    end
    if currentList then a[#a+1]='</li></'..currentList..'>'; end; return table.concat(a);
end

local function browserSource(source)
    local hex=source:match('id="cfs%-manual%-state"[^>]*data%-state="([%x]+)"');if not hex then return source;end;local document=Codec.decode(Codec.unhex(hex));if document.version~=2 and not (document.contents and document.contents.tiers) then return source;end;
    document.version=1;document.settings.margin=document.settings.margin or document.settings.marginInner or 17;local contents=document.contents or {};local converted={contentsDepth=contents.depth or 6,contentsPageNumbers=contents.pageNumbers~=false,contentsSources={},contentsStyles={},contentsIndents={},contentsLeaders={},contentsAlignments={},contentsEntries={}};
    for level=1,6 do local tier=(contents.tiers or {})[level] or {};converted.contentsSources[level]=tier.source or '';converted.contentsStyles[level]=tier.style or document.settings.textStyle;converted.contentsIndents[level]=tier.indent or (level-1)*4;converted.contentsLeaders[level]=tier.leader or 'dots';converted.contentsAlignments[level]=tier.align or 'left';end;
    for _,entry in ipairs(contents.entries or {})do local index=1;for i,page in ipairs(document.pages)do if page.id==entry.page then index=i;break;end;end;converted.contentsEntries[#converted.contentsEntries+1]={label=entry.text or '',level=entry.level,pageId=entry.page,objectId=entry.source,page=index,pageIndex=index-1};end;document.contents=converted;
    for _,group in ipairs({document.pages,document.masters or {}})do for _,page in ipairs(group)do for _,object in ipairs(page.objects or {})do object.spread=object.acrossSpread==true;if object.runs then object.html=runsHTML(object.runs);end;object.runs=nil;if object.type=='table' and object.cells then local rows={};for _,row in ipairs(object.cells)do local cells={};for _,cell in ipairs(row)do cells[#cells+1]='<td>'..(cell.runs and runsHTML(cell.runs) or cell.html or '')..'</td>';end;rows[#rows+1]='<tr>'..table.concat(cells)..'</tr>';end;object.html='<table><tbody>'..table.concat(rows)..'</tbody></table>';object.cells=nil;end;end;end;end;
    local encoded=Codec.encode(document);for _,name in ipairs({'masters','manualStyles','objects','contentsEntries','nodes'})do encoded=encoded:gsub('"'..name..'":{}','"'..name..'":[]');end;
    return '<template id="cfs-manual-state" data-state="'..Codec.hex(encoded)..'"></template>';
end
function Adapter.open(root)
    assert(wx.wxDirExists(root) or wx.wxFileName.Mkdir(root,511,wx.wxPATH_MKDIR_FULL),'Cannot create manual folder.');local path=root..'/index.html';
    if not wx.wxFileExists(path) then local file=assert(io.open(path,'wb'));assert(file:write(''));assert(file:close());end;
    local model=Common.model({{path=path,name='Manual',kind='html'}});model.root=root;model.editorText=browserSource(model.files[1].text);local directory=wx.wxFileName(root..'/');model.baseURL=wx.wxFileSystem.FileNameToURL(directory);directory:delete();return model;
end
function Adapter.create(parent,root,options)
    options=options or {};local model=Adapter.open(root);local styles=assert(options.styles,'No game style path.');local frame=wx.wxFrame(parent,wx.wxID_ANY,'Game Manual',wx.wxDefaultPosition,wx.wxSize(1600,900));frame:SetMinSize(wx.wxSize(850,600));local state=WindowState.bind(frame,'Manual',options.stateFile);
    local panel=wx.wxPanel(frame,wx.wxID_ANY);local layout=wx.wxBoxSizer(wx.wxVERTICAL);panel:SetSizer(layout);local splitter=wx.wxSplitterWindow(panel,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxSP_LIVE_UPDATE+wx.wxSP_3D);splitter:SetMinimumPaneSize(160);
    local editor=require('Manual.Editor').create(splitter,{files={{text=model.editorText}},baseURL=model.baseURL},styles,options.stateFile or FS.AppCFG);local preview=wxwebview.wxWebView.New(splitter,wx.wxID_ANY);splitter:SplitVertically(editor.view,preview,1050);frame:CreateStatusBar();local toolbar=require('Manual.Toolbar').create(panel);layout:Add(toolbar.panel,0,wx.wxEXPAND);layout:Add(splitter,1,wx.wxEXPAND);local outer=wx.wxBoxSizer(wx.wxVERTICAL);outer:Add(panel,1,wx.wxEXPAND);frame:SetSizer(outer);
    local timer=wx.wxTimer(frame,wx.wxNewId());local closed,closing,pumping,pendingClose=false,false,false,false;local editing=true;local lastPreview;local css=Styles.load(styles);
    local function report(err)require('Errors').report(tostring(err));frame:SetStatusText('Operation failed; see the log.');end;
    local function capture()
        local text=editor.capture();if not text then return false;end;model.files[1].text=text;return true;
    end
    local function save()
        local ok,result=xpcall(function()if not capture() then frame:SetStatusText('Manual is still loading; try Save again.');return false;end;model.save();editor.saved();frame:SetStatusText('Manual saved.');return true;end,debug.traceback);if not ok then report(result);return false;end;return result;
    end
    local controls=toolbar.controls;
    local function toggleEditor()
        editing=not editing;if editing then splitter:SplitVertically(editor.view,preview,1050);editor.view:Show();else splitter:Unsplit(editor.view);preview:Show();end;toolbar.editorVisible(editing);panel:Layout();
    end
    controls.edit:Connect(wx.wxEVT_COMMAND_TOGGLEBUTTON_CLICKED,toggleEditor);controls.save:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,save);
    for _,name in ipairs({'undo','redo','styles','fit','grid','snap'})do local key=name;local event=(key=='grid' or key=='snap') and wx.wxEVT_COMMAND_TOGGLEBUTTON_CLICKED or wx.wxEVT_COMMAND_BUTTON_CLICKED;controls[key]:Connect(event,function()editor.action(key);end);end;
    controls.options:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()editor.options();end);
    controls.refresh:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()editor.refreshStyles();css=Styles.load(styles);lastPreview=nil;end);
    local function zoom()editor.zoom(controls.zoom:GetValue()/100);end;controls.zoom:Connect(wx.wxEVT_SCROLL_THUMBTRACK,zoom);controls.zoom:Connect(wx.wxEVT_SCROLL_CHANGED,zoom);controls.zoomReset:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED,function()editor.zoom(1);end);
    frame:Connect(wx.wxEVT_CHAR_HOOK,function(event)if event:ControlDown() and event:GetKeyCode()==string.byte('S') then save();else event:Skip();end;end);
    local function close(event)
        if closed then event:Skip();return;end;if closing or pumping or editor.busy() then pendingClose=true;event:Veto();return;end;closing=true;local status=editor.status();local discard=true;
        if status.dirty or model.dirty() then
            if not capture() then closing=false;event:Veto();frame:SetStatusText('Manual is busy; try closing again.');return;end;
            if model.dirty() then local answer=wx.wxMessageBox('Save changes to the manual?','Game Manual',wx.wxYES_NO+wx.wxCANCEL+wx.wxICON_QUESTION,frame);if answer==wx.wxCANCEL then discard=false;elseif answer==wx.wxYES then discard=save();end;end;
        end;
        if not discard then pendingClose=false;closing=false;event:Veto();return;end;closed=true;timer:Stop();editor.close();preview:Stop();state.close();if options.onClose then options.onClose();end;frame:Destroy();
    end
    frame:Connect(timer:GetId(),wx.wxEVT_TIMER,function()
        if closed or closing or pumping or editor.busy() then return;end;pumping=true;local ok,err=xpcall(function()
            editor.flush();if editor.refreshStyles() then css=Styles.load(styles);lastPreview=nil;end;local status=editor.status();local text=editor.preview();if text and text~=lastPreview then preview:SetPage(HTML.render(text,model.baseURL,css),model.baseURL);lastPreview=text;end;
            if status.background and status.text then toolbar.palette(status.background,status.text);end;if status.scale then toolbar.scale(status.scale);end;if status.zoom then controls.zoom:SetValue(tonumber(status.zoom));controls.zoomLabel:SetLabel(status.zoom..'%');end;if status.zoomStep then controls.zoom:SetLineSize(status.zoomStep);controls.zoom:SetPageSize(status.zoomStep);end;
            controls.undo:Enable(editing and status.undo==true);controls.redo:Enable(editing and status.redo==true);controls.grid:SetValue(status.grid==true);controls.snap:SetValue(status.snap==true);controls.save:Enable(status.dirty==true or model.dirty());if editor.saveRequested() then save();end;
        end,debug.traceback);pumping=false;if not ok then report(err);end;if pendingClose and not closed then pendingClose=false;frame:Close();end;
    end);
    frame:Connect(wx.wxEVT_CLOSE_WINDOW,close);toolbar.palette('#323b49','#e4eaf3');toolbar.editorVisible(true);timer:Start(200);frame:Show(true);
    return {frame=frame,editor=editor,content=editor.view,preview=preview,model=model,toolbar=toolbar,save=save,close=function()if closed then return true;end;return frame:Close();end,show=function()frame:Show(true);frame:Raise();end};
end
return Adapter;
