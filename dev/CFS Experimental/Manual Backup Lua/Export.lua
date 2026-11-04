local wx=require('wx');local Export={};
function Export.html(editor,path)
    local Document=require('Manual.Document');local copy=Document.copy(editor.document);local fileName=wx.wxFileName(path);local directory=fileName:GetPath();fileName:delete();local mapped={};
    local function read(file)local f=assert(io.open(file,'rb'));local data=f:read('a');f:close();return data;end
    local function asset(src)
        if not src or src=='' then return src;end;if mapped[src] then return mapped[src];end
        local source=src:match('^[A-Za-z]:') and src or editor.model.root..'/'..src;local relative=src:gsub('\\','/');
        if relative:match('^[A-Za-z]:') or relative:find('..',1,true) or relative:sub(1,1)=='/' then relative='Images/External/'..relative:match('[^/]+$');end
        local target=directory..'/'..relative;local sourceName=wx.wxFileName(source);local targetName=wx.wxFileName(target);local same=sourceName:GetFullPath()==targetName:GetFullPath();sourceName:delete();targetName:delete();
        if not same then
            local counter=1;while wx.wxFileExists(target) and read(target)~=read(source) do relative='Images/External/'..counter..'-'..src:gsub('\\','/'):match('[^/]+$');target=directory..'/'..relative;counter=counter+1;end
            if not wx.wxFileExists(target) then local name=wx.wxFileName(target);local folder=name:GetPath();name:delete();assert(wx.wxDirExists(folder) or wx.wxFileName.Mkdir(folder,511,wx.wxPATH_MKDIR_FULL),'Cannot create exported asset folder.');assert(wx.wxCopyFile(source,target,false),'Cannot copy exported image.');end
        end;mapped[src]=relative;return relative;
    end
    for _,pages in ipairs({copy.pages,copy.masters}) do for _,page in ipairs(pages) do page.backgroundImage=asset(page.backgroundImage);for _,o in ipairs(page.objects) do o.src=asset(o.src);end end end
    return require('Manual.HTML').render(copy,editor.styles);
end
function Export.show(parent,editor)
    local choice=wx.wxSingleChoiceDialog(parent,'HTML retains editable text. RGB raster PDF preserves native appearance, but its text is not selectable. CMYK export is not available.','Export Manual',{'HTML','RGB PDF (300 DPI)','RGB PDF with bleed (300 DPI)'});
    if choice:ShowModal()~=wx.wxID_OK then choice:Destroy();return;end;local selection=choice:GetSelection();choice:Destroy();local pdf=selection>0;
    local dialog=wx.wxFileDialog(parent,'Export manual','','manual.'..(pdf and 'pdf' or 'html'),pdf and 'PDF|*.pdf' or 'HTML|*.html',wx.wxFD_SAVE+wx.wxFD_OVERWRITE_PROMPT);local path;if dialog:ShowModal()==wx.wxID_OK then path=dialog:GetPath();end;dialog:Destroy();if not path then return;end
    local stagingFile=wx.wxFile();local staging=wx.wxFileName.CreateTempFileName(path..'.draft-',stagingFile);stagingFile:Close();stagingFile:delete();
    local ok,err=xpcall(function()
        if pdf then require('Manual.PDF').write(editor,staging,300,selection==2);
        else local file=assert(io.open(staging,'wb'));local data=Export.html(editor,path);assert(file:write(data));file:close();end
        assert(wx.wxRenameFile(staging,path,true),'Cannot replace export.');
    end,debug.traceback);if wx.wxFileExists(staging) then wx.wxRemoveFile(staging);end;if not ok then editor.report(err);else editor.status('Exported '..path);end
end
return Export;
