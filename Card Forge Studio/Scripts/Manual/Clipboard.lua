local wx=require('wx'); local Document=require('Manual.Document'); local Layers=require('Manual.Layers'); local Clipboard={};
function Clipboard.write(text)
    assert(wx.wxTheClipboard:Open(),'Clipboard is busy.'); local ok=wx.wxTheClipboard:SetData(wx.wxTextDataObject(text)); wx.wxTheClipboard:Close(); assert(ok,'Cannot write clipboard.');
end
function Clipboard.read()
    assert(wx.wxTheClipboard:Open(),'Clipboard is busy.'); local data=wx.wxTextDataObject(); local ok=wx.wxTheClipboard:GetData(data); wx.wxTheClipboard:Close(); local s=ok and data:GetText() or ''; data:delete(); return s;
end
function Clipboard.copy(page,o)
    local a=Document.copy(Layers.subtree(page,o)); a[1].parentId=nil; Clipboard.write('CFS-MANUAL-OBJECTS\n'..Document.encode(a));
end
function Clipboard.paste(t,page)
    local s=Clipboard.read(); assert(s:sub(1,19)=='CFS-MANUAL-OBJECTS\n','Clipboard does not contain manual objects.');
    local a=Document.decode(s:sub(20)); local map={}; for _,o in ipairs(a) do map[o.id]=Document.id(t); end
    for _,o in ipairs(a) do o.id=map[o.id]; o.parentId=map[o.parentId]; o.flowNext=map[o.flowNext]; page.objects[#page.objects+1]=o; end
    a[1].x=a[1].x+5; a[1].y=a[1].y+5; return a[1];
end
return Clipboard;
