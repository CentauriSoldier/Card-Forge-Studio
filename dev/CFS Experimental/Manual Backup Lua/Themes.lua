-- Editor chrome palettes are independent of manual artwork.
local wx=require('wx'); local Themes={};
Themes.palettes={
    Dark={base='#20252d',panel='#292f39',toolbar='#323b49',rail='#263344',inspector='#302f35',field='#1c222b',text='#e4eaf3',muted='#a7b5c7',border='#526176',active='#355c87',hover='#3c4c61',workspace='#151b24',heading='#3a4658'},
    Light={base='#e8edf3',panel='#f5f7fa',toolbar='#e4eaf2',rail='#d6e0ec',inspector='#f3efe9',field='#ffffff',text='#233044',muted='#52667d',border='#a5b4c7',active='#c3dcf8',hover='#e0ebf8',workspace='#69788c',heading='#dce5f0'}
};
for _,p in pairs(Themes.palettes)do p.surface=p.panel;p.raised=p.heading;p.canvas=p.workspace;p.accent=p.active;end
Themes.roles={};
function Themes.role(window,role)Themes.roles[window:GetId()]=role;return window;end
function Themes.colour(s,alpha)
    if not s or s=='transparent' or s=='none' then return wx.wxColour(0,0,0,0); end
    local r,g,b=s:match('^#(%x%x)(%x%x)(%x%x)');
    if r then return wx.wxColour(tonumber(r,16),tonumber(g,16),tonumber(b,16),alpha or 255); end
    return wx.wxColour(s);
end
function Themes.apply(window,name,inheritedRole)
    local p=assert(Themes.palettes[name],'Unknown editor theme.');
    local class=window:GetClassInfo():GetClassName();local role=Themes.roles[window:GetId()] or ((class=='wxTextCtrl' or class=='wxSpinCtrlDouble' or class=='wxChoice' or class=='wxListBox' or class=='wxButton') and 'field' or inheritedRole or 'panel');
    if class=='wxButton' then window:SetWindowStyleFlag((window:GetWindowStyleFlag() & ~wx.wxBORDER_MASK) | wx.wxBORDER_NONE);window:SetThemeEnabled(false);end
    window:SetBackgroundColour(Themes.colour(p[role] or p.panel)); window:SetForegroundColour(Themes.colour(p.text));
    local children=window:GetChildren(); for i=0,children:GetCount()-1 do Themes.apply(children:Item(i):GetData():DynamicCast("wxWindow"),name,role); end
    window:Refresh();
end
return Themes;
