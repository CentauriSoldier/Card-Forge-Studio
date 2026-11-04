local Tables={};
function Tables.cells(o)
    o.cells=o.cells or {}; for r=1,o.rows or 3 do o.cells[r]=o.cells[r] or {}; for c=1,o.columns or 3 do if o.cells[r][c]==nil then o.cells[r][c]={runs={{text='',style=o.style}}}; end end end; return o.cells;
end
return Tables;
