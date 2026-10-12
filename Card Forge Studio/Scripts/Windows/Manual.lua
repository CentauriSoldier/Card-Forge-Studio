-- Native wxLua editor and clean preview share one page renderer.
local wx=require('wx');local Manual=require('Manual');local WindowState=require('Windows.WindowState');local ManualWindow={};
WindowState.register('Manual',{savePosition=true,saveSize=true,saveVisible=false});
function ManualWindow.create(parent,root,options)
    options=options or {};local model=Manual.open(root,assert(options.styles,'No game style path.'));local frame=wx.wxFrame(parent,wx.wxID_ANY,'Game Manual',wx.wxDefaultPosition,wx.wxSize(1600,900));frame:SetMinSize(wx.wxSize(850,600));local state=WindowState.bind(frame,'Manual',options.stateFile);
    local panel=wx.wxPanel(frame,wx.wxID_ANY);local layout=wx.wxBoxSizer(wx.wxVERTICAL);panel:SetSizer(layout);local splitter=wx.wxSplitterWindow(panel,wx.wxID_ANY,wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxSP_LIVE_UPDATE+wx.wxSP_3D);splitter:SetMinimumPaneSize(160);
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
        editing=not editing;if editing then splitter:SplitVertically(editor.view,preview.view,1050);editor.view:Show();else splitter:Unsplit(editor.view);preview.view:Show();end
        toolbar.controls.edit:SetToolTip(editing and 'Hide editor' or 'Show editor');panel:Layout();editor.canvas.refresh();preview.refresh();
    end
    toolbar=require('Manual.Toolbar').create(panel,editor,actions);editor.nativeToolbar=toolbar;layout:Add(toolbar.panel,0,wx.wxEXPAND);layout:Add(splitter,1,wx.wxEXPAND);local fs=wx.wxBoxSizer(wx.wxVERTICAL);fs:Add(panel,1,wx.wxEXPAND);frame:SetSizer(fs);require('Manual.Themes').apply(toolbar.panel,editor.theme);toolbar.controls.save:Enable(false);
    editor.zoomChanged=function(n)toolbar.controls.zoom:SetValue(n);toolbar.controls.percent:SetLabel(n..'%');preview.zoomValue=n;preview.refresh();end
    local function close(event)
        if closed then event:Skip();return;end;if closing then event:Veto();return;end;closing=true;
        local discard=true;if model.dirty(true) then local answer=wx.wxMessageBox('Save changes to the manual?','Game Manual',wx.wxYES_NO+wx.wxCANCEL+wx.wxICON_QUESTION,frame);if answer==wx.wxCANCEL then discard=false;elseif answer==wx.wxYES then discard=save();end;end
        if not discard then closing=false;event:Veto();return;end;closed=true;styleTimer:Stop();editor.closed=true;editor.close();state.close();if options.onClose then options.onClose();end;frame:Destroy();
    end
    frame:Connect(styleTimer:GetId(),wx.wxEVT_TIMER,function()if not closing and not closed then local ok,err=xpcall(function()if editor.styles.refresh() then editor.fonts={};editor.invalidate();editor.refresh();end;end,debug.traceback);if not ok then styleTimer:Stop();report(err);end;end;end);styleTimer:Start(1000);
    frame:Connect(wx.wxEVT_CLOSE_WINDOW,close);frame:Show(true);editor.canvas.fit();return {frame=frame,editor=editor,content=editor.canvas.view,model=model,save=save,close=function()if closed then return true;end;return frame:Close();end,show=function()frame:Show(true);frame:Raise();end,toolbar=toolbar};
end
return ManualWindow;
