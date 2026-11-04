-- Native implementation behind the shared Manual entry points.
local NativeManual=(function()
-- Optional per-game manual storage with protected, draft-only native editing.
local wx=require('wx');local Common=require('Windows.Editors.Common');local Document=require('Manual.Document');local HTML=require('Manual.HTML');local Manual={};
function Manual.read(path)local file=assert(io.open(path,'rb'));local text=file:read('a');file:close();return text;end
    local function loadDocument(source)
        local hex=source:match('id="cfs%-manual%-state"[^>]*data%-state="([%x]+)"');if not hex then return Document.load(source);end;local document=Document.decode(Document.unhex(hex));
        if document.version==1 then
            document.version=2;local contents=document.contents or {};local pages=document.pages or {};
            if contents.contentsDepth then
                local converted={depth=contents.contentsDepth,pageNumbers=contents.contentsPageNumbers,entries={},tiers={}};
                for level=1,6 do converted.tiers[level]={source=(contents.contentsSources or {})[level] or '',style=(contents.contentsStyles or {})[level] or document.settings.textStyle,indent=(contents.contentsIndents or {})[level] or (level-1)*4,leader=(contents.contentsLeaders or {})[level] or 'dots',align=(contents.contentsAlignments or {})[level] or 'left'};end;
                for _,entry in ipairs(contents.contentsEntries or {})do local index=(entry.pageIndex or (tonumber(entry.page) or 1)-1)+1;converted.entries[#converted.entries+1]={text=entry.label or '',level=entry.level,page=entry.pageId or pages[index] and pages[index].id,source=entry.objectId,number=require('Manual.Pages').number(document,index)};end;document.contents=converted;
            else document.contents=contents;document.contents.tiers=document.contents.tiers or {};document.contents.entries=document.contents.entries or {};end;
            for _,group in ipairs({pages,document.masters or {}})do for _,page in ipairs(group)do for _,object in ipairs(page.objects or {})do
                object.acrossSpread=object.spread==true;object.runs=nil;if object.type=='ordered-list' or object.type=='unordered-list' then object.type='text';end;
                if object.type=='table' then object.cells={};for row in (object.html or ''):gmatch('<tr[^>]*>(.-)</tr>')do local cells={};for html in row:gmatch('<t[dh][^>]*>(.-)</t[dh]>')do cells[#cells+1]={html=html};end;object.cells[#object.cells+1]=cells;end;end;
            end;end;end;
        end;document.contents=document.contents or {};document.contents.tiers=document.contents.tiers or {};document.contents.entries=document.contents.entries or {};return Document.normalize(document);
    end
function Manual.open(root,stylePath)
    assert(wx.wxDirExists(root) or wx.wxFileName.Mkdir(root,511,wx.wxPATH_MKDIR_FULL),'Cannot create manual folder.');local path=root..'/index.html';local styles=require('Manual.Styles').open(stylePath);
    if not wx.wxFileExists(path) then local file=assert(io.open(path,'wb'));assert(file:write(HTML.render(Document.new(),styles)));file:close();end
    local model=Common.model({{path=path,name='Manual',kind='html'}});model.root=root;model.document=loadDocument(model.files[1].text);model.draftChanged=false;model.savedJSON=Document.encode(model.document);local protectedSave=model.save;
    function model.dirty(full)if not model.draftChanged then return false;end;if full or not model.history then return Document.encode(model.document)~=model.savedJSON;end;return model.history.state~=model.savedHistoryState;end
    function model.save()
        model.files[1].text=HTML.render(model.document,styles);protectedSave();model.savedJSON=Document.encode(model.document);model.draftChanged=false;model.savedHistoryState=model.history and model.history.state or 0;return true;
    end
    return model;
end
return Manual;

end)();
local NativeWindow=(function()
-- Native wxLua editor and clean preview share one page renderer.
local wx=require('wx');local Manual=NativeManual;local WindowState=require('Windows.WindowState');local ManualWindow={};
WindowState.register('Manual',{savePosition=true,saveSize=true,saveVisible=false});
function ManualWindow.create(parent,root,options)
    options=options or {};local model=Manual.open(root,assert(options.styles,'No game style path.'));local frame=wx.wxFrame(parent,wx.wxID_ANY,'Game Manual',wx.wxDefaultPosition,wx.wxSize(1600,900));frame:SetMinSize(wx.wxSize(850,600));local state=WindowState.bind(frame,'Manual',options.stateFile);
    local panel=wx.wxPanel(frame,wx.wxID_ANY);local layout=wx.wxBoxSizer(wx.wxVERTICAL);panel:SetSizer(layout);local splitter=wx.wxSplitterWindow(panel,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxSP_LIVE_UPDATE+wx.wxSP_3D);splitter:SetMinimumPaneSize(160);
    local preferencePath=(options.stateFile or FS.AppCFG)..'.manual.ini';local sashRatio=tonumber(INIFile.GetValue(preferencePath,'Manual','DividerPercent'));sashRatio=sashRatio and sashRatio>0 and sashRatio<100 and sashRatio/100 or 1050/1600;local sashReady,adjustingSash=false,false;
    local function positionDivider()
        if not splitter:IsSplit() then return;end;local width=splitter:GetClientSize():GetWidth();if width<=0 then return;end;adjustingSash=true;splitter:SetSashGravity(sashRatio);splitter:SetSashPosition(math.floor(width*sashRatio+.5));adjustingSash=false;
    end
    splitter:Connect(wx.wxEVT_COMMAND_SPLITTER_SASH_POS_CHANGED,function(event)
        if sashReady and not adjustingSash and splitter:IsSplit() then local width=splitter:GetClientSize():GetWidth();if width>0 then sashRatio=math.max(.01,math.min(.99,event:GetSashPosition()/width));splitter:SetSashGravity(sashRatio);INIFile.SetValue(preferencePath,'Manual','DividerPercent',tostring(sashRatio*100));end;end;event:Skip();
    end);
    local editor=require('Manual.Editor').create(splitter,model,options.styles,options.stateFile or FS.AppCFG);local preview=require('Manual.Preview').create(splitter,editor);editor.preview=preview;splitter:SplitVertically(editor.view,preview.view,1050);frame:CreateStatusBar();
    local styleTimer=wx.wxTimer(frame,wx.wxNewId());local closed,closing=false,false;local editing=true;local toolbar;
    local function report(err)require('Errors').report(tostring(err));frame:SetStatusText('Operation failed; see the log.');end
    editor.onError=report;editor.onStatus=function(s)frame:SetStatusText(s);end
    local function save()local ok,err=xpcall(function()model.document=editor.document;model.save();end,debug.traceback);if not ok then report(err);return false;end;frame:SetStatusText('Manual saved.');if toolbar then toolbar.controls.save:Enable(false);end;return true;end
    frame:Connect(wx.wxEVT_CHAR_HOOK,function(event)if event:ControlDown() and event:GetKeyCode()==string.byte('S') then save();else event:Skip();end;end);
    editor.onSave=save;editor.onChange=function()if toolbar then toolbar.controls.save:Enable(model.dirty());end;end
    local actions={save=save,undo=editor.history.undo,redo=editor.history.redo,styles=function()require('Manual.StyleManager').show(frame,editor);end,options=function()require('Manual.Options').show(frame,editor);end,
        refresh=function()editor.styles.refresh();editor.fonts={};editor.invalidate();editor.refresh();end,fit=function()editor.canvas.fit();end,
        grid=function()editor.change(function()editor.document.settings.gridVisible=not editor.document.settings.gridVisible;end);end,snap=function()editor.change(function()editor.document.settings.autoSnap=not editor.document.settings.autoSnap;end);end,
        export=function()require('Manual.Export').show(frame,editor);end};
    actions.edit=function()
        editing=not editing;if editing then splitter:SplitVertically(editor.view,preview.view,math.floor(splitter:GetClientSize():GetWidth()*sashRatio+.5));editor.view:Show();else splitter:Unsplit(editor.view);preview.view:Show();end
        toolbar.controls.edit:SetToolTip(editing and 'Hide editor' or 'Show editor');panel:Layout();positionDivider();editor.canvas.refresh();preview.refresh();
    end
    toolbar=require('Manual.Toolbar').create(panel,editor,actions);editor.nativeToolbar=toolbar;layout:Add(toolbar.panel,0,wx.wxEXPAND);layout:Add(splitter,1,wx.wxEXPAND);local fs=wx.wxBoxSizer(wx.wxVERTICAL);fs:Add(panel,1,wx.wxEXPAND);frame:SetSizer(fs);require('Manual.Themes').apply(toolbar.panel,editor.theme);toolbar.controls.save:Enable(false);
    editor.zoomChanged=function(n)toolbar.controls.zoom:SetValue(n);toolbar.controls.percent:SetLabel(n..'%');preview.zoomValue=n;preview.refresh();end
    local function close(event)
        if closed then event:Skip();return;end;if closing then event:Veto();return;end;closing=true;
        local discard=true;if model.dirty(true) then local answer=wx.wxMessageBox('Save changes to the manual?','Game Manual',wx.wxYES_NO+wx.wxCANCEL+wx.wxICON_QUESTION,frame);if answer==wx.wxCANCEL then discard=false;elseif answer==wx.wxYES then discard=save();end;end
        if not discard then closing=false;event:Veto();return;end;closed=true;INIFile.SetValue(preferencePath,'Manual','DividerPercent',tostring(sashRatio*100));styleTimer:Stop();editor.closed=true;editor.close();state.close();if options.onClose then options.onClose();end;frame:Destroy();
    end
    frame:Connect(styleTimer:GetId(),wx.wxEVT_TIMER,function()if not closing and not closed then local ok,err=xpcall(function()if editor.styles.refresh() then editor.fonts={};editor.invalidate();editor.refresh();end;end,debug.traceback);if not ok then styleTimer:Stop();report(err);end;end;end);styleTimer:Start(1000);
    frame:Connect(wx.wxEVT_CLOSE_WINDOW,close);frame:Show(true);frame:Layout();panel:Layout();sashReady=true;positionDivider();editor.canvas.fit();return {frame=frame,editor=editor,content=editor.canvas.view,model=model,save=save,close=function()if closed then return true;end;return frame:Close();end,show=function()frame:Show(true);frame:Raise();end,toolbar=toolbar};
end
return ManualWindow;

end)();
return {kind='native',open=NativeManual.open,read=NativeManual.read,create=NativeWindow.create};
