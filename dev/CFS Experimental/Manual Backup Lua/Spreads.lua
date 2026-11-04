local Spreads={};
function Spreads.indices(t,index)
    if not t.settings.facingPages or #t.pages==1 then return {index}; end
    if t.settings.firstPageAlone and index==1 then return {1}; end
    local first=t.settings.firstPageAlone and 2 or 1; local left=first+math.floor((index-first)/2)*2;
    return left+1<=#t.pages and {left,left+1} or {left};
end
function Spreads.offset(t,active,owner)
    local indices=Spreads.indices(t,active); for i,n in ipairs(indices) do if n==owner then return (i-1)*t.settings.width; end end
end
return Spreads;
