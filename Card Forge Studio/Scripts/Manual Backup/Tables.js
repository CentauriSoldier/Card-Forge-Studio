/* Table cells remain editable HTML, including inline game style tags. */
window.CFSTables = (() => {
    const limit=n=>Math.max(1,Math.min(30,Math.round(Number(n)||1)));
    function create(rows=3,columns=3,old='') {
        const parsed=new DOMParser().parseFromString(old,'text/html');const cells=Array.from(parsed.querySelectorAll('tr'),r=>Array.from(r.cells,c=>c.innerHTML));
        return '<table style="width:100%;height:100%;table-layout:fixed;border-collapse:collapse"><tbody>'+Array.from({length:limit(rows)},(_,r)=>'<tr>'+Array.from({length:limit(columns)},(_,c)=>'<td style="border:1px solid currentColor;padding:2mm;vertical-align:top;overflow-wrap:anywhere">'+(cells[r]?.[c]||'<br>')+'</td>').join('')+'</tr>').join('')+'</tbody></table>';
    }
    return {create,limit};
})();
