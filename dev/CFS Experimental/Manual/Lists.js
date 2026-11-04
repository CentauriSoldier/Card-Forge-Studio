/* Lists are ordinary editable HTML inside a movable text object. */
window.CFSLists = (() => {
    const has=type=>['ordered-list','unordered-list'].includes(type);
    const create=type=>type==='ordered-list'?'<ol><li>List item</li></ol>':'<ul><li>List item</li></ul>';
    function render(o) {
        const template=document.createElement('template');template.innerHTML=o.html||create(o.type);
        for(const list of template.content.querySelectorAll('ol,ul')){
            list.style.margin='0';list.style.paddingLeft=(o.listIndent??6)+'mm';list.style.listStyleType=o.listMarker||(o.type==='ordered-list'?'decimal':'disc');
            if(list.tagName==='OL')list.start=Math.max(1,Math.round(o.listStart||1));
        }
        for(const item of template.content.querySelectorAll('li'))item.style.marginBottom=(o.itemSpacing??2)+'pt';
        return template.innerHTML;
    }
    return {has,create,render};
})();
