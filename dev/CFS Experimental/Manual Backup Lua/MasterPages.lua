local Document=require('Manual.Document'); local MasterPages={};
function MasterPages.get(t,page) if page.masterId then return Document.find(t,page.masterId); end end
function MasterPages.apply(t,master,all,page)
    if all then for _,p in ipairs(t.pages) do p.masterId=master.id; end else page.masterId=master.id; end
end
return MasterPages;
