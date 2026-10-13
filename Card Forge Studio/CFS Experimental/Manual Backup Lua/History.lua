-- Small edits snapshot only the affected object; structural operations snapshot the document.
local Document=require('Manual.Document');local History={};
function History.create(editor)
    local h={undoStack={},redoStack={},bytes=0,limit=64*1024*1024,state=0,nextState=1};
    local function target(record)
        if record.id=='@document' then return editor.document;elseif record.id=='@settings' then return editor.document.settings;end
        return assert(Document.find(editor.document,record.id),'History target no longer exists.');
    end
    function h.begin(value)
        local id=value==editor.document.settings and '@settings' or value and value.id or '@document';return {id=id,before=Document.encode(value or editor.document)};
    end
    function h.commit(record)
        local after=Document.encode(target(record));if after==record.before then return false;end
        record.beforeState=h.state;record.afterState=h.nextState;h.nextState=h.nextState+1;h.state=record.afterState;h.undoStack[#h.undoStack+1]=record;h.bytes=h.bytes+#record.before;h.redoStack={};
        while #h.undoStack>1 and (h.bytes>h.limit or #h.undoStack>100) do h.bytes=h.bytes-#table.remove(h.undoStack,1).before;end
        editor.changed();return true;
    end
    local function restore(record)
        local value=Document.decode(record.before);
        if record.id=='@document' then editor.document=Document.normalize(value);
        elseif record.id=='@settings' then editor.document.settings=value;
        else local old,page,index=Document.find(editor.document,record.id);if index then page.objects[index]=value;else for _,list in ipairs({editor.document.pages,editor.document.masters}) do for i,p in ipairs(list) do if p==old then list[i]=value;break;end end end;end;end
        editor.historyRestored=true;editor.changed();
    end
    function h.undo()
        local record=table.remove(h.undoStack);if not record then return;end
        h.bytes=h.bytes-#record.before;h.redoStack[#h.redoStack+1]={id=record.id,before=Document.encode(target(record)),beforeState=record.beforeState,afterState=record.afterState};h.state=record.beforeState;restore(record);
    end
    function h.redo()
        local record=table.remove(h.redoStack);if not record then return;end
        local before={id=record.id,before=Document.encode(target(record)),beforeState=record.beforeState,afterState=record.afterState};h.state=record.afterState;h.undoStack[#h.undoStack+1]=before;h.bytes=h.bytes+#before.before;restore(record);
    end
    return h;
end
return History;
