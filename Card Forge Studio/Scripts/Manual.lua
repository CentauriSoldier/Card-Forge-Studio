-- Optional per-game manual storage with protected, draft-only native editing.
local wx=require('wx');local Common=require('Windows.Editors.Common');local Document=require('Manual.Document');local HTML=require('Manual.HTML');local Manual={};
function Manual.read(path)local file=assert(io.open(path,'rb'));local text=file:read('a');file:close();return text;end
function Manual.open(root,stylePath)
    assert(wx.wxDirExists(root) or wx.wxFileName.Mkdir(root,511,wx.wxPATH_MKDIR_FULL),'Cannot create manual folder.');local path=root..'/index.html';local styles=require('Manual.Styles').open(stylePath);
    if not wx.wxFileExists(path) then local file=assert(io.open(path,'wb'));assert(file:write(HTML.render(Document.new(),styles)));file:close();end
    local model=Common.model({{path=path,name='Manual',kind='html'}});model.root=root;model.document=Document.load(model.files[1].text);model.draftChanged=false;model.savedJSON=Document.encode(model.document);local protectedSave=model.save;
    function model.dirty(full)if not model.draftChanged then return false;end;if full or not model.history then return Document.encode(model.document)~=model.savedJSON;end;return model.history.state~=model.savedHistoryState;end
    function model.save()
        model.files[1].text=HTML.render(model.document,styles);protectedSave();model.savedJSON=Document.encode(model.document);model.draftChanged=false;model.savedHistoryState=model.history and model.history.state or 0;return true;
    end
    return model;
end
return Manual;
