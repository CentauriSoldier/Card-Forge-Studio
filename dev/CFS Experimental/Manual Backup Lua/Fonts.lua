-- Fonts used by the manual remain native wxFont instances owned by FontStyle.
local wx=require('wx'); local Fonts={};
function Fonts.names()
    local e=wx.wxFontEnumerator(); e:EnumerateFacenames(); local names=e:GetFacenames(); local a={}; for i=0,names:GetCount()-1 do a[#a+1]=names:Item(i); end; e:delete(); table.sort(a); return a;
end
return Fonts;
